# vhd-bitlocker

`vhd-bitlocker` 是一个 Windows 本地工具，用来管理一个固定的 VHDX 虚拟磁盘和其中的 BitLocker 加密卷。双击 `start.cmd` 会申请管理员权限并进入交互式主菜单：先显示镜像、挂载、卷、密码、卸载策略和开机自启状态，再选择挂载解锁、锁定卸载、密码维护、备份或开机自启维护。

适合把个人资料、工作文档或便携加密空间放在一个 VHDX 文件里，需要时打开，用完安全锁定并卸载。也可以把镜像和 rclone 同步套件一起备份到 U 盘，在任意 Windows 电脑上挂载并同步导出文件。

## 功能概览

- 状态面板：显示镜像路径与文件是否存在、挂载状态与磁盘号、各卷盘符与 BitLocker 锁定状态、本地密码能否被当前账户解密、卸载策略和开机自启状态。
- 一键开关：未挂载时挂载并解锁；已挂载但卷仍锁定时补解锁；已挂载时刷新缓存、锁定 BitLocker 卷并卸载。
- 密码维护：设置或更新本地 DPAPI 密文、清除密文、校验密文能否被当前账户解密。只维护 `config.ini`，不会修改磁盘上的 BitLocker 密码。
- 备份 VHDX 卷：扫描 USB 存储盘，把 VHDX 镜像和 rclone 同步套件一起复制到 U 盘或移动硬盘，并自动改写备份里的同步配置。
- 开机自启动：用 Windows 计划任务在登录后延迟自动解密挂载，以当前用户最高权限运行、免 UAC，支持暂停、恢复、删除、立即测试和查看日志。
- 命令行直跑：通过 `-Action` 执行挂载、卸载、状态、密码、备份和自启动管理等动作，方便创建快捷方式或脚本调用。
- 防重复启动：已有菜单或操作在运行时，重复双击会被拦截并提示。

## 文件说明

下载的 `vhd-bitlocker.zip` 解压后是一个 `vhd-bitlocker` 目录：

- `start.cmd`：唯一双击入口。优先调用 PowerShell 7（`pwsh.exe`），未安装时回退到 Windows PowerShell 5.1，并把命令行参数原样传给核心脚本。管理员权限由脚本自己申请。
- `vhd-bitlocker.ps1`：核心脚本，同时兼容 PowerShell 7 和 Windows PowerShell 5.1，一般不需要修改。
- `config.ini`：统一配置文件，保存 VHDX 路径、镜像类型、密码密文、卸载策略、挂载等待时间、系统通知和开机自启延迟。文件不存在时会按默认值自动创建。
- `readme.txt`：随包携带的离线说明。
- `rclone-sync\`：rclone 同步套件，可在工具目录里直接运行，备份时其中的脚本和程序会平铺复制到备份目录。包含 `rclone.exe`、`sync.cmd`、`sync-vhdx.ps1` 和 `sync-config.ini`。
- `autostart.log`：启用开机自启动后生成的运行日志，记录每次自动挂载的结果，可在主菜单里查看或清理。

## 使用方法

### 下载并解压

在 PowerShell 中执行：

```powershell
Invoke-WebRequest -Uri "https://<tools-origin>/source/vhd-bitlocker/vhd-bitlocker.zip" -OutFile ".\vhd-bitlocker.zip"
Expand-Archive -LiteralPath ".\vhd-bitlocker.zip" -DestinationPath "." -Force
```

### 配置 VHDX 路径

编辑 `vhd-bitlocker\config.ini`，把 `VhdxPath` 指向真实存在的 VHDX 文件。相对路径从工具目录开始计算，后缀可以伪装成 `.dat`、`.bin` 等，但文件内容必须仍然是 VHDX。

```powershell
notepad .\vhd-bitlocker\config.ini
```

```ini
VhdxPath=.\secure-disk.vhdx
```

### 打开主菜单

双击 `vhd-bitlocker\start.cmd`，在 UAC 提示中选择“是”。也可以从 PowerShell 启动：

```powershell
.\vhd-bitlocker\start.cmd
```

主菜单选项：

- `[1]` 挂载并解锁：未挂载时挂载 VHDX 并解锁 BitLocker 卷；已挂载但仍有锁定的卷时直接补解锁；解锁失败会自动回滚卸载。
- `[2]` 锁定并卸载：按 `SafeUnmountOnly` 的配置刷新缓存、锁定卷并卸载。
- `[3]` 密码维护：设置或更新、清除、校验本地保存的 BitLocker 密码。
- `[4]` 备份 VHDX 卷（含 rclone 同步套件）：选择 U 盘或目录，把镜像和同步套件一起备份。
- `[5]` 开机自启动维护（自动解密挂载）：启用、暂停、删除计划任务，立即测试或查看日志。
- `[R]` 刷新状态，`[0]` 退出。

首次使用时如果 `config.ini` 里没有保存密码，执行 `[1]` 会提示手动输入一次密码，不会自动写入配置。需要免密挂载时，先进入 `[3]` 保存密码。

### 命令行直跑

不想每次进菜单，可以用 `-Action` 直接指定动作：

```powershell
.\vhd-bitlocker\start.cmd -Action Toggle
.\vhd-bitlocker\start.cmd -Action Mount
.\vhd-bitlocker\start.cmd -Action Unmount
.\vhd-bitlocker\start.cmd -Action Status -PauseOnExit
.\vhd-bitlocker\start.cmd -Action Backup -BackupPath "E:\vhdx-backup"
.\vhd-bitlocker\start.cmd -Action EnableAutoStart -DelaySeconds 10
```

可用动作：`Toggle`、`Mount`、`Unmount`、`Status`、`SetPassword`、`ClearPassword`、`TestPassword`、`Backup`、`AutoMount`、`EnableAutoStart`、`DisableAutoStart`、`RemoveAutoStart`、`AutoStartStatus`。其中 `AutoMount` 供计划任务调用，一般不需要手动执行。

非菜单动作执行结束后窗口会关闭；需要停留查看输出时加 `-PauseOnExit`。

### 备份到 U 盘

在主菜单选择 `[4]`，或在命令行执行 `-Action Backup`。脚本会：

- 检查 VHDX 是否已挂载；已挂载时询问是否先锁定并卸载，避免复制到不一致的镜像。
- 扫描所有 USB 存储盘，默认使用 `<盘符>:\vhdx-backup`，也可以输入编号选择其他盘或手动输入目录。
- 检查剩余空间和 FAT32 单文件 4 GB 限制；目标已有同名备份时询问是否覆盖。空间足够时先写临时文件再原子替换，降低中途断电或拔盘损坏旧备份的风险。
- 把 VHDX 和 `rclone-sync` 里的文件平铺复制到备份目录，并把备份里 `sync-config.ini` 的 `VhdxPath` 改为 `.\<VHDX 文件名>`，保留同步目标和排除规则。

备份完成后，在任意 Windows 电脑上打开备份目录，直接运行 `sync.cmd` 即可挂载解锁并同步文件。备份目录只包含 VHDX 和 rclone 同步套件，不包含 `start.cmd`；需要完整主菜单时仍使用原来的工具目录。

### rclone 同步套件

`rclone-sync\sync.cmd` 是一个独立入口：挂载 VHDX、解锁 BitLocker、用 rclone sync 导出文件、自动卸载。第一次运行会引导填写同步目标，之后保存在 `sync-config.ini`。

确认提示支持 `[Y]` 开始同步、`[D]` 模拟预演、`[E]` 修改同步目标与排除路径、`[N]` 取消。同机运行且 `config.ini` 中有当前账户可读的 DPAPI 密码时自动解锁，否则提示手动输入；脚本自己挂载的磁盘会在同步结束后自动锁定卸载。

排除规则写在 `sync-config.ini`，一行一条 `ExcludePath=`，使用 rclone filter 语法。目录排除以 `/**` 结尾，例如 `ExcludePath=temp/**`；文件可以用通配符，例如 `ExcludePath=*.tmp`。目标为 `remote:bucket/path` 时，把 `rclone.conf` 放在 `sync.cmd` 同目录即可自动加载。

同步套件也支持命令行：

```powershell
.\vhd-bitlocker\rclone-sync\sync.cmd -Mode DryRun
.\vhd-bitlocker\rclone-sync\sync.cmd -Mode Sync -Yes
.\vhd-bitlocker\rclone-sync\sync.cmd -Mode Config
```

## 配置文件

`config.ini` 使用 `Key=Value` 格式，`#` 或 `;` 开头的行是注释。没有写出的键会使用内置默认值。下载包里的 `config.ini` 可能保留打包时的设置，正式使用前请至少确认 `VhdxPath`、`ImageStorageType` 和 `SafeUnmountOnly`。

```ini
VhdxPath=.\secure-disk.vhdx
ImageStorageType=VHDX
PasswordSecret=
SafeUnmountOnly=true
MountWaitSeconds=25
ShowNotifications=true
AutoStartDelaySeconds=10
```

- `VhdxPath`：VHDX 文件路径，必填。相对路径从工具目录开始，也可以写绝对路径。
- `ImageStorageType`：强制指定镜像类型。只是改了文件后缀时保持 `VHDX`。
- `PasswordSecret`：BitLocker 密码的 DPAPI 密文。不要手动填写明文密码，请通过主菜单的密码维护写入。
- `SafeUnmountOnly`：`true` 时如果虚拟磁盘里有文件被占用就安全失败并提示关闭文件；`false` 允许强制锁定，可能丢失未保存的数据。建议保持 `true`。
- `MountWaitSeconds`：挂载后等待 Windows 识别卷的秒数，取值 1–300，默认 25。
- `ShowNotifications`：非菜单命令行模式下是否弹出 Windows 系统通知，默认 `true`。
- `AutoStartDelaySeconds`：登录后延迟多少秒执行自动解密挂载，取值 0–300，默认 10。

## 开机自启动

主菜单 `[5]` 管理开机自启动。启用后脚本会注册一个形如 `VhdBitLocker_AutoMount_xxxxxxxx` 的 Windows 计划任务，在 `AutoStartDelaySeconds` 秒后以当前用户最高权限运行 `-Action AutoMount`，免 UAC 自动挂载并解锁。

- 启用前需要本地已保存且可解密的 DPAPI 密码；没有时会引导先设置。
- `[2]` 可以临时暂停或恢复任务，配置保留。
- `[3]` 删除任务，`[4]` 立即触发一次并显示返回码，`[5]` 查看或清空 `autostart.log`。
- 移动了工具目录、换了 Windows 账户或改了路径后，重新执行 `[1]` 启用或更新即可刷新任务配置。

## 注意事项

- 仅适用于 Windows，需要系统支持 `Mount-DiskImage`、`Get-BitLockerVolume`、`Unlock-BitLocker`、`Lock-BitLocker` 和 `Dismount-DiskImage` 等 PowerShell cmdlet；建议使用支持 BitLocker 的 Windows 专业版、企业版或教育版，Windows 10/11 正常可用。
- 挂载、解锁、锁定和卸载都需要管理员权限，`-Action` 模式同样会触发 UAC。请确认脚本来源后再授权。
- 默认不强制卸载被占用的磁盘（取决于 `SafeUnmountOnly`）。卸载失败时先关闭资源管理器、编辑器、压缩软件或终端中正在访问虚拟磁盘的进程。
- `config.ini` 是本机私有配置，不建议上传或分发。`PasswordSecret` 依赖当前 Windows 用户和机器的 DPAPI，复制到其他电脑或其他用户下通常无法解密。
- 清除已保存密码只清空本地的 `PasswordSecret`，不会修改 VHDX 里 BitLocker 的实际密码。
- 备份到 FAT32 的 U 盘时，单个文件不能达到 4 GB；VHDX 超过这个大小请使用 exFAT 或 NTFS。
- 开机自启动任务以当前用户身份运行，换用户或移动工具目录后可能需要重新启用，运行记录在 `autostart.log`。
- 从 `start.cmd` 启动时使用 `ExecutionPolicy Bypass`，只对本次进程放行，不会修改系统执行策略。

## 常见问题

### 提示找不到 VHDX 文件

修改 `config.ini` 的 `VhdxPath`，确认文件真实存在、路径正确。使用伪装后缀时保持 `ImageStorageType=VHDX`。

### 解锁失败或提示密码无法解密

可能是 BitLocker 密码改过、密文损坏，或换到了其他 Windows 账户或电脑。进入主菜单 `[3]` 校验、更新或清除密码后重试；如果只是本机密文失效，重新保存一次密码即可。

### 卸载失败

通常是有文件仍被打开。关闭相关程序后重试，不建议把 `SafeUnmountOnly` 改成 `false` 来强行卸载。

### 备份被拒绝

检查目标盘剩余空间、是否为 FAT32 且 VHDX 超过 4 GB、目标目录是否与源目录冲突，以及是否有同名文件需要覆盖。

### 开机自启动没有生效

在 `[5]` 查看任务状态和 `autostart.log`。常见原因是本地密码未保存或当前账户无法解密、任务被暂停、延迟时间太长，或工具目录被移动后没有重新启用或更新。

### 提示已有实例正在运行

脚本有防重入互斥锁。关闭正在运行的菜单窗口，或等待当前操作结束后再试。

### rclone 同步失败

检查 `sync-config.ini` 的 `SyncDestination`、排除规则写法和网络或远程配置；使用远程存储时确认 `rclone.conf` 与 `sync.cmd` 在同一目录。可以先执行 `-Mode DryRun` 模拟预演。
