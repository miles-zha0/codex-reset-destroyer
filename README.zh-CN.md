# Codex Reset Destroyer（摧毁重置）

[English](README.md) · 简体中文

**我的使命是摧毁重置。** 不是摧毁服务器，也不是打破额度上限。只是想消灭一种尴尬：下午四点准备开工，才发现五小时倒计时还没开始。

[下载 Mac 安装包（DMG）](https://github.com/miles-god/codex-reset-destroyer/releases/latest/download/Codex-Reset-Destroyer.dmg) · [发行说明与 SHA-256 校验文件](https://github.com/miles-god/codex-reset-destroyer/releases/latest)

## 安装：从磁盘映像到菜单栏的小钟

1. 需要 macOS 13 或以上，支持 Intel 和 Apple Silicon。先把 Codex 桌面版安装到 `/Applications` 或 `~/Applications`，用 ChatGPT Plus 登录。其自带 CLI 必须支持 `account/rateLimits/read` 和 `exec --ignore-user-config`。不需要 API Key、Python 或 Homebrew。
2. 打开 DMG，把 **Codex Reset Destroyer** 拖到「应用程序」，推出磁盘映像，再打开已安装的 App。**v1.0.0 只有临时签名，未经 Apple 公证。** 如被系统拦截，先执行 `shasum -a 256 Codex-Reset-Destroyer.dmg`，和 Release 的 `SHA256SUMS` 核对。确认信任后，可在「系统设置 → 隐私与安全性」选择「仍要打开」。受管理的 Mac 可能不允许此操作。
3. 点小钟 → **Settings… → Language → 简体中文 → 保存**。默认英文，也支持日文。默认每天 **08:00–18:00**，可改开始、结束时间，或限定周一到周五、周一到周六。窗口在所点屏幕的正中央打开。登录自启默认开启，可在设置中关闭。

## 它到底做了什么？

Mac 醒着时，App 会读取 **Codex 五小时窗口**，不是网页版 ChatGPT 的消息计数。仅当处于设定时段且五小时额度剩余 100% 时，才会通过 Codex 发一条「只回复 OK」的临时只读请求。周额度已满或消费控制生效时不发；「立即检查」也不绕过这些条件。时段外允许查额度，但不发模型请求。

发送前先写下时间，暂按五小时防重。即使发完仍显示 100%、重启或请求超时，也不会立刻重发。读到活跃窗口的服务端重置时间后，就改用该时间。**测试请求本身消耗额度**；它不增加总额度，也不保证服务端一定开始新窗口。点「退出」即可停止。

## 隐私、故障与卸载

- 请求在全新的临时目录里运行，不附带你的项目文件。App 不收集遥测，没有自己的后端，不保存账户令牌。由 Codex CLI 登录并连接 OpenAI；会传入 macOS 已启用的 HTTP/HTTPS 代理，不专门解析 PAC 脚本。
- 菜单栏图标不会跳动。点开才显示额度和倒计时。失败弹窗，同一持续故障不反复提醒。读不到额度时，先检查 Codex 登录、CLI 版本和 VPN。
- 卸载时先关闭登录自启，再退出并将 App 移到废纸篓。可选清理：`~/Library/Application Support/QuotaClock/state.json` 和偏好域 `local.quotaclock.app`。沿用旧名称是为了保留原设置，不要为了重试删除防重记录。

## 从源码构建

Mac 安装 Xcode Command Line Tools 后执行：

```sh
swiftc Engine.swift Tests.swift -o /tmp/reset-tests && /tmp/reset-tests
bash build.sh
```

`dist/` 中是通用 App、DMG 和校验文件。欢迎提 Issue：请附 macOS 版本、芯片、Codex 版本、预期与实际行为，**不要上传令牌或 Codex 登录文件**。

MIT 许可证。独立社区项目，与 OpenAI 无隶属关系。
