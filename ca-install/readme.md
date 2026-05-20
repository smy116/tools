# ca-install

`ca-install` 用于把 `SMY Root Certification Authority ECC` 安装到系统信任库，适用于需要信任 SMY Root CA 的 Linux、Windows 和 macOS 设备。目录中的安装脚本会内置证书内容，`SMY-Root-CA.crt` 可用于直接下载或手动导入。

## 文件说明

- `Install-To-Linux.sh`：Linux 根证书安装脚本。
- `Install-To-Windows.ps1`：Windows 根证书安装脚本，会自动请求管理员权限。
- `Install-To-Mac.sh`：macOS 根证书安装脚本。
- `SMY-Root-CA.crt`：SMY Root CA 证书文件。

## 使用方法

从工具站在内存中加载并执行 Linux 安装脚本：

```bash
sudo bash -c 'bash <(curl -fsSL "$1")' _ "https://<tools-origin>/source/ca-install/linux.sh"
```

从工具站在 Windows PowerShell 中安装：

```powershell
$SmyCaInstallUrl="https://<tools-origin>/source/ca-install/windows.ps1"; irm $SmyCaInstallUrl | iex
```

从工具站在内存中加载并执行 macOS 安装脚本：

```bash
sudo bash -c 'bash <(curl -fsSL "$1")' _ "https://<tools-origin>/source/ca-install/mac.sh"
```

仅下载证书文件：

```bash
curl -fsSL https://<tools-origin>/source/ca-install/root-ca.crt -o SMY-Root-CA.crt
```

Linux 和 macOS 的工具站安装命令使用 Bash process substitution 在内存中加载脚本，不会把安装脚本写入临时目录。证书文件下载命令会按需把 `SMY-Root-CA.crt` 保存到当前目录。

如果已经克隆本仓库，也可以直接在本目录执行对应脚本：

```bash
sudo bash Install-To-Linux.sh
sudo bash Install-To-Mac.sh
```

Windows 本地执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-To-Windows.ps1
```

## 支持范围

- Linux：支持 Debian、Ubuntu、Alpine、CentOS、Fedora、RHEL、OpenWrt 及带有 `update-ca-certificates` 或 `update-ca-trust` 的兼容发行版。
- Windows：安装到 `LocalMachine\Root` 证书存储区，并校验证书指纹。
- macOS：安装到系统钥匙串 `/Library/Keychains/System.keychain`。

## 注意事项

- Linux 和 macOS 安装需要 `root` 或 `sudo` 权限。
- Windows 安装需要管理员权限，脚本会在需要时触发 UAC 提权。
- 安装根证书会影响系统级 TLS 信任，请只在受信任设备上执行。
