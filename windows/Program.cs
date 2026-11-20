using System.Diagnostics;
using System.Text.Json;
using Microsoft.Win32;

static class Program
{
    [STAThread]
    static void Main()
    {
        using var instance = new Mutex(true, @"Local\CodexResetDestroyer", out var first);
        if (!first) return;
        ApplicationConfiguration.Initialize();
        using var tray = new Tray();
        Application.Run(tray);
    }
}

record Settings(int Days = 7, int Start = 480, int End = 1080, bool Login = true)
{
    public bool Includes(DateTimeOffset now)
    {
        int weekday = ((int)now.DayOfWeek + 6) % 7;
        int minute = now.Hour * 60 + now.Minute;
        return weekday < Days && minute >= Start && minute < End;
    }
}
record State(long Hold = 0);

sealed class Tray : ApplicationContext
{
    const string AppName = "Codex Reset Destroyer";
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    readonly string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CodexResetDestroyer");
    readonly NotifyIcon icon;
    readonly ToolStripMenuItem status = new("Checking usage…") { Enabled = false };
    readonly System.Windows.Forms.Timer timer = new() { Interval = 2000 };
    readonly CancellationTokenSource shutdown = new();
    Settings settings = new();
    DateTimeOffset next;
    bool busy;
    string? lastError;
    Form? form;

    public Tray()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add(status);
        menu.Items.Add("Settings…", null, (_, _) => ShowSettings());
        menu.Items.Add("Check now", null, (_, _) => _ = Check());
        menu.Items.Add("Quit", null, (_, _) => ExitThread());
        icon = new NotifyIcon { Icon = SystemIcons.Application, Text = AppName, Visible = true, ContextMenuStrip = menu };
        icon.DoubleClick += (_, _) => ShowSettings();
        try
        {
            Directory.CreateDirectory(folder);
            var path = Path.Combine(folder, "settings.json");
            if (File.Exists(path)) settings = Load<Settings>("settings.json");
            else
            {
                SaveStartup(settings.Login);
                Store("settings.json", settings);
            }
        }
        catch (Exception error) { Report(error.Message); }
        timer.Tick += (_, _) => { if (DateTimeOffset.Now >= next) _ = Check(); };
        timer.Start();
    }

    protected override void ExitThreadCore()
    {
        timer.Stop();
        shutdown.Cancel();
        icon.Visible = false;
        icon.Dispose();
        timer.Dispose();
        form?.Close();
        base.ExitThreadCore();
    }

    T Load<T>(string file) where T : class => JsonSerializer.Deserialize<T>(File.ReadAllText(Path.Combine(folder, file))) ?? throw new IOException("Invalid local settings or state.");
    void Store<T>(string file, T value)
    {
        var path = Path.Combine(folder, file);
        File.WriteAllText(path + ".tmp", JsonSerializer.Serialize(value));
        File.Move(path + ".tmp", path, true);
    }

    static void SaveStartup(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (enabled) key.SetValue(AppName, $"\"{Application.ExecutablePath}\"");
        else key.DeleteValue(AppName, false);
    }

    void Report(string message)
    {
        status.Text = message;
        if (message == lastError) return;
        lastError = message;
        icon.ShowBalloonTip(5000, AppName, message, ToolTipIcon.Warning);
    }

    void ShowSettings()
    {
        if (form is { IsDisposed: false }) { form.Activate(); return; }
        form = new Form { Text = AppName, StartPosition = FormStartPosition.Manual, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false };
        var layout = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(16) };
        var days = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 220 };
        days.Items.AddRange(["Every day", "Monday–Friday", "Monday–Saturday"]);
        days.SelectedIndex = settings.Days == 5 ? 1 : settings.Days == 6 ? 2 : 0;
        static DateTimePicker Time(int minute) => new() { Format = DateTimePickerFormat.Custom, CustomFormat = "HH:mm", ShowUpDown = true, Value = DateTime.Today.AddMinutes(minute) };
        var start = Time(settings.Start);
        var end = Time(settings.End);
        var login = new CheckBox { Text = "Launch at sign-in", Checked = settings.Login, AutoSize = true };
        var save = new Button { Text = "Save", AutoSize = true };
        foreach (var control in new Control[] { new Label { Text = "Repeat", AutoSize = true }, days, new Label { Text = "Start (local time)", AutoSize = true }, start, new Label { Text = "End (local time)", AutoSize = true }, end, login, save })
            layout.Controls.Add(control);
        save.Click += (_, _) =>
        {
            int from = (int)start.Value.TimeOfDay.TotalMinutes, until = (int)end.Value.TimeOfDay.TotalMinutes;
            if (from >= until) { MessageBox.Show(form, "End must be later than start.", AppName); return; }
            var updated = new Settings(new[] { 7, 5, 6 }[days.SelectedIndex], from, until, login.Checked);
            try { SaveStartup(updated.Login); Store("settings.json", updated); settings = updated; form.Close(); next = default; }
            catch (Exception error) { Report(error.Message); }
        };
        form.Controls.Add(layout);
        form.AcceptButton = save;
        form.PerformLayout();
        var screen = Screen.FromPoint(Cursor.Position).Bounds;
        form.Location = new Point(screen.Left + (screen.Width - form.Width) / 2, screen.Top + (screen.Height - form.Height) / 2);
        form.Show();
        form.Activate();
    }

    async Task Check()
    {
        if (busy) return;
        busy = true;
        var schedule = settings;
        next = DateTimeOffset.Now.AddMinutes(1);
        try
        {
            var (remaining, hold) = await Task.Run(() => RunCheck(schedule, shutdown.Token));
            lastError = null;
            var reset = DateTimeOffset.FromUnixTimeSeconds(hold).ToLocalTime();
            status.Text = reset > DateTimeOffset.Now ? $"Five-hour quota: {remaining}% left · resets {reset:g}" : $"Five-hour quota: {remaining}% left";
            if (reset > DateTimeOffset.Now)
            {
                var regular = DateTimeOffset.Now.AddMinutes(5);
                next = reset.AddSeconds(2) < regular ? reset.AddSeconds(2) : regular;
            }
        }
        catch (OperationCanceledException) when (shutdown.IsCancellationRequested) { }
        catch (Exception error) { if (!shutdown.IsCancellationRequested) Report(error.Message); }
        finally { busy = false; }
    }

    async Task<(int, long)> RunCheck(Settings schedule, CancellationToken stop)
    {
        var cli = FindCli();
        using var stateLock = new FileStream(Path.Combine(folder, "worker.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        var state = File.Exists(Path.Combine(folder, "state.json")) ? Load<State>("state.json") : new State();
        var limits = await Fetch(cli, stop);
        if (!limits.TryGetProperty("primary", out var primary) || primary.ValueKind != JsonValueKind.Object ||
            !limits.TryGetProperty("planType", out var plan) || plan.GetString() != "plus" || primary.GetProperty("windowDurationMins").GetInt32() != 300)
            throw new InvalidOperationException("A Plus account with a five-hour window is required.");
        int used = primary.GetProperty("usedPercent").GetInt32();
        if (used is < 0 or > 100) throw new InvalidDataException("Invalid quota returned by Codex.");
        var now = DateTimeOffset.Now;
        long stamp = now.ToUnixTimeSeconds();
        if (used > 0 && primary.TryGetProperty("resetsAt", out var reset) && reset.ValueKind == JsonValueKind.Number && reset.GetInt64() > stamp && reset.GetInt64() != state.Hold)
        {
            state = new State(reset.GetInt64());
            Store("state.json", state);
        }
        bool weeklyBlocked = limits.TryGetProperty("secondary", out var weekly) && weekly.ValueKind == JsonValueKind.Object && weekly.GetProperty("usedPercent").GetInt32() >= 100;
        bool spendBlocked = limits.TryGetProperty("spendControlReached", out var spend) && spend.ValueKind == JsonValueKind.True;
        if (used == 0 && state.Hold <= stamp && schedule.Includes(now) && !weeklyBlocked && !spendBlocked)
        {
            var temporary = Directory.CreateTempSubdirectory("codex-reset-");
            try
            {
                stop.ThrowIfCancellationRequested();
                state = new State(stamp + 18000);
                Store("state.json", state);
                using var ping = Start(cli, temporary.FullName, "exec", "--ignore-user-config", "--ephemeral", "--skip-git-repo-check", "-s", "read-only", "Reply only OK. Do not use tools.");
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(stop);
                timeout.CancelAfter(TimeSpan.FromSeconds(90));
                try
                {
                    ping.StandardInput.Close();
                    await Task.WhenAll(ping.StandardOutput.BaseStream.CopyToAsync(Stream.Null, timeout.Token), ping.WaitForExitAsync(timeout.Token));
                    if (ping.ExitCode != 0) throw new IOException();
                }
                catch (Exception) when (!stop.IsCancellationRequested) { throw new IOException("Ping not confirmed. No automatic retry this window."); }
                finally { Stop(ping); }
            }
            finally { try { temporary.Delete(true); } catch (IOException) { } }
        }
        return (100 - used, state.Hold);
    }

    async Task<JsonElement> Fetch(string cli, CancellationToken stop)
    {
        using var process = Start(cli, folder, "app-server");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(stop);
        timeout.CancelAfter(TimeSpan.FromSeconds(35));
        var token = timeout.Token;
        async Task Send(object message) => await process.StandardInput.WriteLineAsync(JsonSerializer.Serialize(message).AsMemory(), token);
        async Task<JsonElement> Receive(int id)
        {
            while (await process.StandardOutput.ReadLineAsync(token) is { } line)
            {
                using var document = JsonDocument.Parse(line);
                var root = document.RootElement;
                if (root.TryGetProperty("id", out var received) && received.ValueKind == JsonValueKind.Number && received.GetInt32() == id)
                    return root.GetProperty("result").Clone();
            }
            throw new IOException();
        }
        try
        {
            process.StandardInput.AutoFlush = true;
            await Send(new { id = 1, method = "initialize", @params = new { clientInfo = new { name = "reset_destroyer", version = "1.1.0" } } });
            await Receive(1);
            await Send(new { method = "initialized" });
            await Send(new { id = 2, method = "account/rateLimits/read", @params = new { } });
            var result = await Receive(2);
            if (result.TryGetProperty("rateLimitsByLimitId", out var byId) && byId.ValueKind == JsonValueKind.Object && byId.TryGetProperty("codex", out var codex)) return codex;
            return result.GetProperty("rateLimits");
        }
        catch (Exception) when (!stop.IsCancellationRequested) { throw new IOException("Could not read usage. Check Codex sign-in, network and VPN."); }
        finally { Stop(process); }
    }

    static string FindCli()
    {
        var configured = Environment.GetEnvironmentVariable("CODEX_CLI_PATH");
        if (configured is not null && Path.IsPathFullyQualified(configured) && File.Exists(configured) && Path.GetExtension(configured).Equals(".exe", StringComparison.OrdinalIgnoreCase)) return configured;
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            var root = directory.Trim('"');
            if (!Path.IsPathFullyQualified(root)) continue;
            foreach (var relative in new[] { "codex.exe", @"node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\codex\codex.exe", @"node_modules\@openai\codex\node_modules\@openai\codex-win32-arm64\vendor\aarch64-pc-windows-msvc\codex\codex.exe" })
            {
                var candidate = Path.Combine(root, relative);
                if (File.Exists(candidate)) return candidate;
            }
        }
        throw new FileNotFoundException("Install the Codex CLI or set CODEX_CLI_PATH to codex.exe.");
    }

    static Process Start(string exe, string folder, params string[] args)
    {
        var info = new ProcessStartInfo(exe) { WorkingDirectory = folder, UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var arg in args) info.ArgumentList.Add(arg);
        foreach (var variable in new[] { "OPENAI_API_KEY", "CODEX_API_KEY", "OPENAI_BASE_URL" }) info.Environment.Remove(variable);
        var process = Process.Start(info) ?? throw new IOException("Could not start Codex CLI.");
        process.BeginErrorReadLine();
        return process;
    }

    static void Stop(Process process) { try { if (!process.HasExited) process.Kill(true); } catch (InvalidOperationException) { } }
}
