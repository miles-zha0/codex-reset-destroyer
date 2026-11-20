import Foundation
import SystemConfiguration

enum Issue: String, Error { case cli, network, plan, ping, state }
struct Window: Decodable { let usedPercent: Int; let windowDurationMins: Int?; let resetsAt: Double? }
struct Limits: Decodable { let primary: Window?; let secondary: Window?; let planType: String?; let spendControlReached: Bool? }
struct Snapshot: Codable { var hold: Double = 0; var last: Double? }
struct Schedule {
    let days: Int, start: Int, end: Int
    func includes(_ date: Date, calendar: Calendar = .current) -> Bool {
        let minute = calendar.component(.hour, from: date)*60 + calendar.component(.minute, from: date)
        return (calendar.component(.weekday, from: date)+5)%7 < days && (start..<end).contains(minute)
    }
}

func eligible(_ limits: Limits, state: Snapshot, date: Date, schedule: Schedule) -> Bool {
    limits.primary?.usedPercent == 0 && (limits.secondary?.usedPercent ?? 0) < 100 && limits.spendControlReached != true && state.hold <= date.timeIntervalSince1970 && schedule.includes(date)
}

private func child(_ path: URL, _ args: [String], cwd: URL) -> Process {
    let proc = Process(); proc.executableURL = path; proc.arguments = args; proc.currentDirectoryURL = cwd
    var env = ProcessInfo.processInfo.environment
    for key in ["OPENAI_API_KEY", "CODEX_API_KEY", "OPENAI_BASE_URL"] { env.removeValue(forKey:key) }
    let proxy = SCDynamicStoreCopyProxies(nil) as? [String:Any] ?? [:]
    for scheme in ["HTTP", "HTTPS"] {
        if proxy[scheme+"Enable"] as? Int == 1, let host = proxy[scheme+"Proxy"] as? String, let port = proxy[scheme+"Port"] as? Int { env[scheme+"_PROXY"] = "http://\(host):\(port)" }
    }
    proc.environment = env; proc.standardError = FileHandle.nullDevice; return proc
}
private func deadline(_ proc: Process, seconds: Int) -> DispatchWorkItem {
    let task = DispatchWorkItem { if proc.isRunning { kill(proc.processIdentifier, SIGKILL) } }
    DispatchQueue.global().asyncAfter(deadline:.now() + .seconds(seconds), execute:task); return task
}
private func fetch(_ cli: URL, cwd: URL) throws -> Limits {
    let proc = child(cli, ["app-server"], cwd:cwd), input = Pipe(), output = Pipe()
    proc.standardInput = input; proc.standardOutput = output; try proc.run()
    let timeout = deadline(proc, seconds:35)
    defer { try? input.fileHandleForWriting.close(); if proc.isRunning { kill(proc.processIdentifier, SIGKILL) }; proc.waitUntilExit(); timeout.cancel() }
    var buffer = Data()
    func send(_ obj: [String:Any]) throws { var data = try JSONSerialization.data(withJSONObject:obj); data.append(10); try input.fileHandleForWriting.write(contentsOf:data) }
    func reply(_ id: Int) throws -> [String:Any] {
        while true {
            if let newline = buffer.firstIndex(of:10) {
                let line = buffer.prefix(upTo:newline); buffer.removeSubrange(...newline)
                guard let obj = try JSONSerialization.jsonObject(with:line) as? [String:Any], obj["id"] as? Int == id else { continue }
                guard let result = obj["result"] as? [String:Any] else { throw Issue.network }; return result
            }
            let bytes = output.fileHandleForReading.availableData; if bytes.isEmpty { throw Issue.network }; buffer.append(bytes)
        }
    }
    try send(["id":1,"method":"initialize","params":["clientInfo":["name":"reset_destroyer","version":"1.0.1"]]]); _ = try reply(1)
    try send(["method":"initialized"]); try send(["id":2,"method":"account/rateLimits/read","params":[:]])
    let result = try reply(2)
    guard let data = (result["rateLimitsByLimitId"] as? [String:Any])?["codex"] ?? result["rateLimits"] else { throw Issue.network }
    return try JSONDecoder().decode(Limits.self, from: JSONSerialization.data(withJSONObject:data))
}

func checkLimits(_ schedule: Schedule, readOnly: Bool = false) throws -> (Int, Snapshot) {
    let fm = FileManager.default
    let cli = [URL(fileURLWithPath:"/Applications/Codex.app"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Codex.app")].map { $0.appendingPathComponent("Contents/Resources/codex-cli/bin/codex") }.first { fm.isExecutableFile(atPath:$0.path) }
    guard let cli else { throw Issue.cli }
    let root = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/QuotaClock")
    try fm.createDirectory(at:root, withIntermediateDirectories:true)
    let lock = open(root.appendingPathComponent("worker.lock").path, O_CREAT|O_RDWR, 0o600)
    guard lock >= 0 else { throw Issue.state }; defer { close(lock) }
    guard flock(lock, LOCK_EX|LOCK_NB) == 0 else { throw Issue.state }
    let file = root.appendingPathComponent("state.json")
    var state = fm.fileExists(atPath:file.path) ? try JSONDecoder().decode(Snapshot.self, from:Data(contentsOf:file)) : Snapshot()
    let data = try fetch(cli, cwd:root)
    guard let primary = data.primary, data.planType == "plus", primary.windowDurationMins == 300, (0...100).contains(primary.usedPercent) else { throw Issue.plan }
    let now = Date(); let stamp = now.timeIntervalSince1970
    if primary.usedPercent > 0, let reset = primary.resetsAt, reset > stamp, reset != state.hold { state.hold = reset; try JSONEncoder().encode(state).write(to:file,options:.atomic) }
    if !readOnly && eligible(data, state:state, date:now, schedule:schedule) {
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString); try fm.createDirectory(at:dir,withIntermediateDirectories:false); defer { try? fm.removeItem(at:dir) }
        let proc = child(cli,["exec","--ignore-user-config","--ephemeral","--skip-git-repo-check","-s","read-only","Reply only OK. Do not use tools."],cwd:dir)
        proc.standardInput = FileHandle.nullDevice; proc.standardOutput = FileHandle.nullDevice
        state.last = stamp; state.hold = stamp + 18000; try JSONEncoder().encode(state).write(to:file,options:.atomic)
        try proc.run(); let timeout = deadline(proc,seconds:90); proc.waitUntilExit(); timeout.cancel(); guard proc.terminationStatus == 0 else { throw Issue.ping }
    }
    return (100-primary.usedPercent,state)
}
