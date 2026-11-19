import Cocoa
import SwiftUI

let name = "Codex Reset Destroyer"
enum Language: String, CaseIterable {
    case en, zh = "zh-Hans", ja
    var title: String { self("English", "简体中文", "日本語") }
    func callAsFunction(_ english: String, _ chinese: String, _ japanese: String) -> String {
        switch self { case .en: return english; case .zh: return chinese; case .ja: return japanese }
    }
    func message(_ error: Issue) -> String {
        switch error {
        case .cli: return self("Install the Codex desktop app first.","请先安装 Codex 桌面应用。","先に Codex デスクトップアプリをインストールしてください。")
        case .plan: return self("A Plus account with a five-hour window is required.","需要具有五小时窗口的 Plus 账户。","5 時間枠の Plus アカウントが必要です。")
        case .ping: return self("Ping not confirmed. No automatic retry this window.","请求未确认成功。本窗口不会自动重发。","送信を確認できません。この枠では再送しません。")
        case .state: return self("Check local storage or another running copy.","请检查本机存储或是否重复运行。","ストレージとアプリの重複起動を確認してください。")
        case .network: return self("Could not read usage. Check your Codex sign-in, connection and proxy.","无法读取用量，请检查 Codex 登录、网络和代理。","使用量を取得できません。Codex のログイン、接続、プロキシを確認してください。")
        }
    }
}

struct SettingsView: View {
    @State var lang: Language
    @State var days: Int
    @State var start: Date
    @State var end: Date
    @State var login: Bool
    let save: (Language, Int, Int, Int, Bool) -> Void
    let cancel: () -> Void
    func minutes(_ date: Date) -> Int { Calendar.current.component(.hour,from:date)*60 + Calendar.current.component(.minute,from:date) }
    var body: some View {
        VStack(alignment:.leading, spacing:16) {
            Picker(lang("Language", "语言", "言語"),selection:$lang) { ForEach(Language.allCases,id:\.self) { Text($0.title).tag($0) } }
            Divider(); Text(lang("Active hours", "自动请求时段", "稼働時間")).font(.headline)
            Picker(lang("Repeat", "重复", "繰り返し"), selection:$days) {
                Text(lang("Every day","每天","毎日")).tag(7); Text(lang("Mon–Fri","周一到周五","月〜金")).tag(5); Text(lang("Mon–Sat","周一到周六","月〜土")).tag(6)
            }.pickerStyle(.segmented)
            HStack { DatePicker(lang("From","开始","開始"),selection:$start,displayedComponents:.hourAndMinute); DatePicker(lang("Until","结束","終了"),selection:$end,displayedComponents:.hourAndMinute) }
            Text(minutes(start)<minutes(end) ? lang("Uses your Mac’s local time.","按 Mac 本地时间运行。","Mac の現地時間で動作します。") : lang("End must be later than start.","结束时间必须晚于开始时间。","終了は開始より後に設定してください。" )).foregroundColor(.secondary)
            Divider(); Toggle(lang("Launch at login","登录 Mac 时启动","ログイン時に起動"),isOn:$login)
            HStack { Spacer(); Button(lang("Cancel","取消","キャンセル"),action:cancel).keyboardShortcut(.cancelAction)
                Button(lang("Save","保存","保存")) { save(lang,days,minutes(start),minutes(end),login) }.keyboardShortcut(.defaultAction).disabled(minutes(start)>=minutes(end)) }
        }.padding(24).frame(width:440).environment(\.locale, Locale(identifier:lang.rawValue))
    }
}

final class Clock: NSObject, NSApplicationDelegate {
    let bar = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength), prefs = UserDefaults.standard
    let info = NSMenuItem(), countdown = NSMenuItem(), last = NSMenuItem(), settings = NSMenuItem(), manual = NSMenuItem(), quit = NSMenuItem()
    let agent = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/local.quotaclock.login.plist")
    var window: NSWindow?, timer: Timer?, snapshot = Snapshot(), remaining: Int?, failure: Issue?, next = 0.0, busy = false
    var lang: Language { Language(rawValue:prefs.string(forKey:"language") ?? "en") ?? .en }
    func applicationDidFinishLaunching(_ note: Notification) {
        prefs.register(defaults:["days":7,"start":480,"end":1080]); let menu = NSMenu()
        bar.button?.image = NSImage(systemSymbolName:"clock",accessibilityDescription:name); bar.menu = menu
        for row in [info,countdown,last,NSMenuItem.separator(),settings,manual,quit] { menu.addItem(row) }
        for (row,action) in [(settings,#selector(show)),(manual,#selector(check)),(quit,#selector(stop))] { row.target = self; row.action = action }
        if !prefs.bool(forKey:"configured") || FileManager.default.fileExists(atPath:agent.path) { do { try configure(true) } catch { alert(error.localizedDescription) } }
        tick(); timer = Timer.scheduledTimer(withTimeInterval:2,repeats:true) { _ in self.tick() }
    }
    func configure(_ enabled: Bool) throws {
        if enabled {
            let plist: [String:Any] = ["Label":"local.quotaclock.login","ProgramArguments":["/usr/bin/open","-g",Bundle.main.bundlePath],"RunAtLoad":true,"LimitLoadToSessionType":"Aqua"]
            try FileManager.default.createDirectory(at:agent.deletingLastPathComponent(),withIntermediateDirectories:true)
            try PropertyListSerialization.data(fromPropertyList:plist,format:.xml,options:0).write(to:agent,options:.atomic)
        } else if FileManager.default.fileExists(atPath:agent.path) { try FileManager.default.removeItem(at:agent) }
        prefs.set(true,forKey:"configured")
    }
    @objc func show() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if window?.isVisible != true {
            func time(_ key: String) -> Date { let value = prefs.integer(forKey:key); return Calendar.current.date(bySettingHour:value/60,minute:value%60,second:0,of:Date()) ?? Date() }
            let login = FileManager.default.fileExists(atPath:agent.path)
            let view = SettingsView(lang:lang,days:prefs.integer(forKey:"days"),start:time("start"),end:time("end"),login:login,save:{ language,days,start,end,enabled in
                do { if enabled != login { try self.configure(enabled) } } catch { self.alert(error.localizedDescription); return }
                self.prefs.set(language.rawValue,forKey:"language"); self.prefs.set(days,forKey:"days"); self.prefs.set(start,forKey:"start"); self.prefs.set(end,forKey:"end"); self.window?.close(); self.next = 0; self.tick()
            },cancel:{ self.window?.close() })
            let panel = NSWindow(contentViewController:NSHostingController(rootView:view)); panel.styleMask = [.titled,.closable]; panel.isReleasedWhenClosed = false; panel.title = name + " · " + lang("Settings","设置","設定"); window = panel
        }
        guard let panel = window else { return }; panel.contentView?.layoutSubtreeIfNeeded()
        if let frame = screen?.frame { panel.setFrameOrigin(NSPoint(x:(frame.midX-panel.frame.width/2).rounded(),y:(frame.midY-panel.frame.height/2).rounded())) }
        NSApp.activate(ignoringOtherApps:true); panel.makeKeyAndOrderFront(nil)
    }
    @objc func stop() { NSApp.terminate(nil) }
    func alert(_ detail: String) { let panel = NSAlert(); panel.messageText = name; panel.informativeText = detail; NSApp.activate(ignoringOtherApps:true); panel.runModal() }
    func tick() {
        let now = Date().timeIntervalSince1970, text = lang
        settings.title = text("Settings…","设置…","設定…"); manual.title = text("Check now","立即检查","今すぐ確認"); quit.title = text("Quit","退出","終了")
        info.title = failure.map(text.message) ?? remaining.map { text("Five-hour quota: \($0)% left","五小时额度剩余 \($0)%","5 時間枠の残り：\($0)%") } ?? text("Checking usage…","正在读取额度…","使用量を確認中…")
        let mins = max(0,Int(ceil((snapshot.hold-now)/60))); countdown.isHidden = mins == 0 || failure != nil
        countdown.title = text("Resets in ","距离重置：","リセットまで：") + String(format:"%d:%02d",mins/60,mins%60)
        if let sent = snapshot.last { let fmt = DateFormatter(); fmt.locale = Locale(identifier:text.rawValue); fmt.dateStyle = .short; fmt.timeStyle = .short; last.title = text("Last attempt: ","上次尝试：","前回の試行：") + fmt.string(from:Date(timeIntervalSince1970:sent)) } else { last.title = text("No ping sent yet","尚未发送请求","まだ送信していません") }
        if now >= next { check() }
    }
    @objc func check() {
        guard !busy else { return }; busy = true
        let schedule = Schedule(days:prefs.integer(forKey:"days"),start:prefs.integer(forKey:"start"),end:prefs.integer(forKey:"end"))
        DispatchQueue.global().async {
            let result = Result { try checkLimits(schedule) }; DispatchQueue.main.async {
                let now = Date().timeIntervalSince1970; self.next = now+60
                switch result {
                case .success(let (remaining,state)): self.remaining = remaining; self.snapshot = state; self.failure = nil; if state.hold > now { self.next = min(now+300,state.hold+2) }
                case .failure(let error): let issue = error as? Issue ?? .network; let changed = self.failure != issue; self.failure = issue; if changed { self.alert(self.lang.message(issue)) }
                }; self.busy = false; self.tick()
            }
        }
    }
}
if CommandLine.arguments.contains("--read-only-check") {
    do { let (remaining,_) = try checkLimits(Schedule(days:7,start:480,end:1080),readOnly:true); print("Remaining: \(remaining)%"); exit(0) } catch { print("Check failed: \(error)"); exit(1) }
}
let app = NSApplication.shared, clock = Clock(); app.setActivationPolicy(.accessory); app.delegate = clock; app.run()
