# Codex Reset Destroyer

English · [简体中文](README.zh-CN.md)

**My mission is to destroy the reset.** Not the limit. Not the server. Just that small moment at 4 PM when you realize your five-hour clock never started.

[Download for Mac (.dmg)](https://github.com/miles-god/codex-reset-destroyer/releases/latest/download/Codex-Reset-Destroyer.dmg) · [Release notes & SHA-256](https://github.com/miles-god/codex-reset-destroyer/releases/latest)

## From disk image to tiny clock

1. Use macOS 13 or newer, on Intel or Apple Silicon. Install the **Codex desktop app** in `/Applications` or `~/Applications` and sign in with your ChatGPT Plus account. The bundled CLI must support `account/rateLimits/read` and `exec --ignore-user-config`. No API key, Python, or package manager required.
2. Open the DMG, drag **Codex Reset Destroyer** to Applications, eject the disk image, then open the installed copy. **v1.0.0 is ad-hoc signed, not Apple-notarized.** If macOS blocks it, verify the download against `SHA256SUMS` (`shasum -a 256 Codex-Reset-Destroyer.dmg`). Only if you trust this release, use **System Settings → Privacy & Security → Open Anyway**. A managed Mac may not allow this.
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

The universal app, DMG, and checksum land in `dist/`. `Engine.swift` owns eligibility and the CLI protocol; `main.swift` owns the menu, settings, and translations. Bug reports are welcome: include macOS version, CPU, Codex version and expected vs. observed behavior. **Never attach account tokens or your Codex auth file.**

MIT licensed. Independent community project; not affiliated with OpenAI.
