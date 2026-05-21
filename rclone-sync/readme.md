# rclone-sync

`rclone-sync` 是面向 Linux 和 Windows 服务器的 rclone 同步脚本，适合通过手动执行、cron 或 Windows 任务计划程序，把一个本地目录或 rclone 远程路径同步到另一个本地目录或远程路径。脚本会按月写入日志，并在预检或同步失败时发送 NotifyMux 通知。

## 文件说明

- `rclone-sync.sh`：Bash 同步脚本，包含 rclone 参数、日志记录、预检、排除规则和 NotifyMux 通知逻辑。
- `rclone-sync.ps1`：PowerShell 同步脚本，功能与 Bash 版一致，适合 Windows PowerShell 5.1+ 或 PowerShell 7。

## 使用方法

从工具站下载脚本并赋予执行权限：

```bash
curl -fsSL https://<tools-origin>/source/rclone-sync/rclone-sync.sh -o rclone-sync.sh
chmod +x rclone-sync.sh
```

从工具站下载 PowerShell 脚本：

```powershell
Invoke-WebRequest -Uri "https://<tools-origin>/source/rclone-sync/rclone-sync.ps1" -OutFile ".\rclone-sync.ps1"
```

执行前请先编辑脚本顶部的配置变量：

```bash
vi rclone-sync.sh
```

PowerShell 脚本可用记事本或其他编辑器修改：

```powershell
notepad .\rclone-sync.ps1
```

确认配置后执行：

```bash
bash ./rclone-sync.sh
```

Windows PowerShell 执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1
```

## 支持指令

无参数运行等同于 `sync`：

```bash
bash ./rclone-sync.sh
```

显式执行真实同步：

```bash
bash ./rclone-sync.sh sync
```

仅预演同步，不修改目标端，也不会发送失败通知：

```bash
bash ./rclone-sync.sh dry-run
```

只发送一条 NotifyMux 测试通知，不检查 rclone 配置，也不执行同步：

```bash
bash ./rclone-sync.sh push-test
```

查看帮助：

```bash
bash ./rclone-sync.sh help
```

PowerShell 对应指令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 sync
powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 dry-run
powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 push-test
powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1 help
```

如果已经克隆本仓库，也可以直接在本目录执行：

```bash
bash rclone-sync.sh
```

PowerShell 本地执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\rclone-sync.ps1
```

常见 cron 示例：

```cron
0 3 * * * /bin/bash /path/to/rclone-sync.sh
```

Windows 任务计划程序的操作可以填写：

```text
程序或脚本: powershell.exe
添加参数: -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\rclone-sync.ps1
```

## 参数说明

- `JOB_NAME` / `JobName`：任务名称，用于日志文件名和 NotifyMux 通知标题；通知标题格式为 `Rclone Sync: <任务名称>`。
- `RCLONE_PATH` / `RclonePath`：rclone 可执行文件路径，默认是脚本所在目录下的 `rclone`；PowerShell 版也会兼容同目录下的 `rclone.exe`。
- `CONFIG_FILE` / `ConfigFile`：rclone 配置文件路径，默认是脚本所在目录下的 `rclone.conf`。
- `SOURCE_DIR` / `SourceDir`：同步源，可以是本地路径，也可以是 rclone remote，例如 `minio:bucket/path/`。
- `DEST_DIR` / `DestDir`：同步目标，可以是本地路径，也可以是 rclone remote，例如 `backup:path/`。
- `EXCLUDE_LIST` / `ExcludeList`：逗号分隔的排除规则，例如 `Public/**,*.tmp,cache/`。为空时不排除文件。
- `LOG_DIR` / `LogDir`：日志目录，默认是脚本所在目录下的 `logs/`。脚本会按 `JOB_NAME_YYYYMM.log` 写入月度日志。
- `NOTIFYMUX_API_KEY` / `NotifyMuxApiKey`：NotifyMux API Key。只需要填写这个密钥即可发送失败通知。
- `NOTIFYMUX_ENDPOINT` / `NotifyMuxEndpoint`：NotifyMux API 端点，默认是 `https://push.smy.me/send`，通常不需要修改。

## 注意事项

- Bash 版需要 Linux Bash；PowerShell 版需要 Windows PowerShell 5.1+ 或 PowerShell 7。两者都需要可执行的 `rclone` 和可读取的 rclone 配置文件。
- `rclone sync` 会让目标端尽量镜像源端；源端删除的文件可能会在目标端删除。首次使用建议先执行 `dry-run` 指令测试。
- 脚本默认包含 `--delete-excluded`，被排除规则匹配到的目标端文件也会被删除，请确认符合预期。
- 脚本默认包含 `--no-check-certificate`，会跳过 TLS 证书校验。只有在自签名证书或内网环境确有需要时再保留。
- NotifyMux API Key、remote 名称和配置文件路径可能暴露内部信息，请不要把包含真实 API Key 的修改提交到仓库。
- 通过 cron 或 Windows 任务计划程序运行时建议全部使用绝对路径，并确认运行用户有日志目录、源目录和目标目录的读写权限。
