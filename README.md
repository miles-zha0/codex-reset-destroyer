# Codex Reset Destroyer

English · [简体中文](README.zh-CN.md)

**Two Codex quota windows in five hours? Start the first one early.**

Codex Reset Destroyer is an open-source Mac menu bar app. During the hours you pick, it sends one tiny ping when your five-hour quota is full. By the time you sit down to work, the clock may already be ticking, so you can hit a reset and tap into the next window within five hours of starting work.

**My mission: destroy the reset.** Not double your quota. Just get to the next window sooner. 💥

[Download for Mac (.dmg)](https://github.com/miles-zha0/codex-reset-destroyer/releases/latest/download/Codex-Reset-Destroyer.dmg) · [Download for Windows x64 (.zip)](https://github.com/miles-zha0/codex-reset-destroyer/releases/latest/download/Codex-Reset-Destroyer-Windows-x64.zip) · [Release notes & checksums](https://github.com/miles-zha0/codex-reset-destroyer/releases/latest)

## Windows tray

On Windows 11 x64, install the Codex CLI and sign in with ChatGPT Plus. Make `codex.exe` available on PATH or set the user environment variable `CODEX_CLI_PATH` to its full path, then restart the tray app. Extract the ZIP to a permanent folder and run `ResetDestroyer.exe`. No separate .NET install is needed. This binary is unsigned; verify the checksum before opening it. Right-click the tray icon (it may be under the overflow arrow) to change the schedule, check usage, or quit. Launch at sign-in defaults to on; turn it off before removing or moving the EXE.

Both apps can continue checking during screen lock if the computer stays awake and online. They do not prevent sleep or run while the computer is asleep. macOS retries after wake and unlock and shows persistent network errors only after a retry.

## From disk image to tiny clock

1. Use macOS 13 or newer, on Apple Silicon (M-series) only. Install the **Codex desktop app** in `/Applications` or `~/Applications` and sign in with your ChatGPT Plus account. The bundled CLI must support `account/rateLimits/read` and `exec --ignore-user-config`. No API key, Python, or package manager required.
2. Open the DMG, drag **Codex Reset Destroyer** to Applications, eject the disk image, then open the installed copy. **v1.0.1 is ad-hoc signed, not Apple-notarized.** If macOS blocks it, verify the download against `SHA256SUMS` (`shasum -a 256 Codex-Reset-Destroyer.dmg`). Only if you trust this release, use **System Settings → Privacy & Security → Open Anyway**. A managed Mac may not allow this.
3. Click the little clock → **Settings…**. Pick English, 简体中文, or 日本語, choose your days and hours, and save. English and daily **08:00–18:00** are the defaults. The window opens in the middle of the display you clicked. Login launch is on by default; disable it in Settings.

## What actually gets destroyed?

Nothing on the server. While your Mac is awake, the app reads the **Codex** five-hour window, not the ChatGPT website’s message counter. During your schedule, when the short window reports 100% remaining, it can send one ephemeral, read-only “Reply only OK” request through Codex. A weekly limit or spend-control block suppresses the ping. **Check now** uses the same rules. Usage checks can still run outside the schedule; model requests cannot.

Before sending, the app writes a local timestamp and a five-hour hold. Even if the display rounds back to 100%, the app restarts, or the request times out, it won’t immediately send another ping. When an active window reports a reset time, that server timestamp replaces the estimate. A reset does not create extra quota: **the ping itself uses quota**, and server-side accounting can change. Quit from the menu to stop the app.

## Privacy & troubleshooting

- No project files in the ping: it runs in a fresh temporary folder. No app telemetry, custom backend, or account-token storage. The Codex CLI handles authentication and contacts OpenAI. Enabled macOS HTTP/HTTPS proxies are passed to the CLI; PAC-only configurations are not explicitly resolved.
- The icon stays still. Click it for the remaining quota and countdown. Failures raise an alert; an unchanged failure is not announced on every poll. If usage cannot be read, check Codex sign-in, CLI compatibility and VPN before retrying.
- To uninstall, disable launch at login, quit, and move the app to Trash. Optional local state: `~/Library/Application Support/QuotaClock/state.json`; preferences: `local.quotaclock.app`. These legacy names preserve old settings. Don’t delete state to retry a ping: it also remembers duplicate prevention.

## Build & contribute

On macOS with Xcode Command Line Tools:

```sh
swiftc Engine.swift Tests.swift -o /tmp/reset-tests && /tmp/reset-tests
bash build.sh
```

The Apple Silicon app, DMG, and checksum land in `dist/`. `Engine.swift` owns eligibility and the CLI protocol; `main.swift` owns the menu, settings, and translations. Bug reports are welcome: include macOS version, CPU, Codex version and expected vs. observed behavior. **Never attach account tokens or your Codex auth file.**

MIT licensed. Independent community project; not affiliated with OpenAI.
