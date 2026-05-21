# vhd-bitlocker

`vhd-bitlocker` 是一个 Windows 本地小工具，用来一键切换固定的 VHDX 虚拟磁盘和其中的 BitLocker 卷。

- VHDX 未挂载时：挂载 VHDX，并解锁其中的 BitLocker 卷。
- VHDX 已挂载时：锁定其中的 BitLocker 卷，并卸载 VHDX。

适合把个人文件、工作资料或便携加密空间放在一个 VHDX 文件里，需要时打开，用完后安全锁定并卸载。

## 文件说明

- `vhd-bitlocker.zip`：工具站提供下载的完整 Windows 工具包。
- `start.cmd`：执行“开关”操作。未挂载时会挂载并解锁，已挂载时会锁定并卸载。
- `status.cmd`：只查看当前 VHDX 和 BitLocker 状态，不会修改磁盘状态。
- `reset-password.cmd`：重新保存 BitLocker 密码，适合密码改过、输错过或想清空后重新保存时使用。
- `toggle-vhd-bitlocker.ps1`：核心 PowerShell 脚本，一般不需要修改。
- `config.sample.ini`：可分发的配置样例，不包含本机保存的密码密文。
- `config.ini`：本机私有配置文件。首次运行会自动创建，也可以从 `config.sample.ini` 复制后手动编辑。

## 使用方法

从工具站下载并解压到当前目录：

```powershell
Invoke-WebRequest -Uri "https://<tools-origin>/source/vhd-bitlocker/vhd-bitlocker.zip" -OutFile ".\vhd-bitlocker.zip"
Expand-Archive -LiteralPath ".\vhd-bitlocker.zip" -DestinationPath "." -Force
```

创建并编辑本机配置：

```powershell
cd .\vhd-bitlocker
if (-not (Test-Path -LiteralPath .\config.ini)) { Copy-Item -LiteralPath .\config.sample.ini -Destination .\config.ini }
notepad .\config.ini
```

打开或关闭加密虚拟磁盘：

```powershell
.\start.cmd
```

查看当前状态：

```powershell
.\status.cmd
```

重新保存 BitLocker 密码：

```powershell
.\reset-password.cmd
```

也可以直接在资源管理器里双击 `start.cmd`、`status.cmd` 或 `reset-password.cmd`。

## 配置文件

`VhdxPath` 是 VHDX 文件路径。相对路径从工具目录开始计算，后缀名可以伪装成 `.dat`、`.bin` 等，但文件真实内容必须仍然是 VHDX。

```ini
VhdxPath=.\secure-disk.dat
VhdxPath=.\vault\secure-disk.vhdx
VhdxPath=D:\Private\secure-disk.vhdx
```

`ImageStorageType` 用来强制告诉 Windows 这个文件是什么磁盘镜像类型。如果只是把 `.vhdx` 改成其他后缀，保持 `VHDX`。

```ini
ImageStorageType=VHDX
```

`PasswordSecret` 是 BitLocker 密码的 DPAPI 加密密文。不要手动填写真实密码。首次运行或执行 `reset-password.cmd` 后，脚本会自动写入这一行。

```ini
PasswordSecret=
```

`SafeUnmountOnly` 为 `true` 时，如果虚拟磁盘里还有文件被占用，卸载会安全失败并提示关闭文件后重试。不建议改成 `false`，强制锁定可能导致未保存数据丢失。

```ini
SafeUnmountOnly=true
```

`MountWaitSeconds` 是挂载 VHDX 后等待 Windows 识别卷的秒数，普通情况不用修改。

```ini
MountWaitSeconds=25
```

## 参数说明

日常使用建议通过 `.cmd` 入口执行。核心脚本支持以下 PowerShell 参数：

- `-Status`：只输出状态，不挂载、解锁、锁定或卸载。
- `-ResetPassword`：重新输入并保存 BitLocker 密码到 `PasswordSecret`。
- `-PauseOnExit`：执行结束后暂停窗口，方便查看输出。

## 注意事项

- 仅适用于 Windows，需要系统支持 `Mount-DiskImage`、`Get-BitLockerVolume`、`Unlock-BitLocker` 和 `Lock-BitLocker` 等 PowerShell cmdlet。
- 挂载、卸载、解锁和锁定 BitLocker 卷需要管理员权限。脚本会在需要时触发 UAC，请确认操作来源后再允许。
- 默认不会强制卸载被占用的磁盘，避免未保存数据丢失。卸载失败时请先关闭资源管理器、编辑器、压缩软件或终端中正在访问虚拟磁盘的进程。
- `config.ini` 是本机私有配置，不建议上传或分发。需要给别人样例时使用 `config.sample.ini`。
- `PasswordSecret` 不是明文密码，但它依赖当前 Windows 用户和机器的 DPAPI。复制到另一台电脑或另一个 Windows 用户下通常无法解密。
- 如果不想继续保存密码，把 `config.ini` 里的 `PasswordSecret=` 后面的内容清空即可。下次运行会重新要求输入。
- 从 `start.cmd` 启动时会使用 `ExecutionPolicy Bypass` 仅对本次运行放行，不会修改系统执行策略。

## 常见问题

### 提示找不到 VHDX 文件

修改 `config.ini` 里的 `VhdxPath`，确保路径指向真实存在的 VHDX 文件。如果使用伪装后缀，也可以指向 `.dat`、`.bin` 等文件。

### 提示镜像类型错误或挂载失败

检查 `ImageStorageType`。VHDX 文件即使改了后缀，也应该写 `VHDX`。如果文件真实内容不是 VHDX，Windows 会拒绝挂载。

### 解锁失败

可能是 BitLocker 密码保存错了，或磁盘密码后来改过。执行 `reset-password.cmd` 重新保存密码，然后再执行 `start.cmd`。

### 卸载失败

通常是虚拟磁盘里有文件被打开。关闭相关程序后重试。
