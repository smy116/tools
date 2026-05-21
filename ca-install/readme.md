# ca-install

`ca-install` 用于把 `SMY Root Certification Authority ECC` 安装到系统信任库，适用于需要信任 SMY Root CA 的 Linux、Windows、macOS 和 Android 设备。目录中的安装脚本和 Android 模块会内置证书内容，`SMY-Root-CA.crt` 可用于直接下载或手动导入。

## 文件说明

- `Install-To-Linux.sh`：Linux 根证书安装脚本。
- `Install-To-Windows.ps1`：Windows 根证书安装脚本，会自动请求管理员权限。
- `Install-To-Mac.sh`：macOS 根证书安装脚本。
- `SMY-Root-CA.crt`：SMY Root CA 证书文件。
- `magisk-android.zip`：Android Root CA 模块，可通过 Magisk、KernelSU 或 APatch 管理器安装。
- `magisk-android/`：Android Root CA 模块源码目录，重新打包时使用。

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

下载 Android Magisk / KernelSU / APatch 模块：

```bash
curl -fsSL https://<tools-origin>/source/ca-install/magisk-android.zip -o magisk-android.zip
```

把 `magisk-android.zip` 传到 Android 设备后，在 Magisk、KernelSU 或 APatch 管理器中作为模块安装并重启。模块会把证书以内置系统 CA 文件名 `7c45bb5f.0` 安装到系统证书目录；在 Android 14+ 或带 Conscrypt Mainline 更新的设备上，模块会在开机后把证书集合注入到 `/apex/com.android.conscrypt/cacerts` 可见的挂载命名空间中。

Linux 和 macOS 的工具站安装命令使用 Bash process substitution 在内存中加载脚本，不会把安装脚本写入临时目录。证书文件和 Android 模块下载命令会按需保存到当前目录。

如果已经克隆本仓库，也可以直接在本目录执行对应脚本：

```bash
sudo bash Install-To-Linux.sh
sudo bash Install-To-Mac.sh
```

Windows 本地执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-To-Windows.ps1
```

Android 本地安装：

- 将 `magisk-android.zip` 复制到 Android 设备。
- 在 Magisk、KernelSU 或 APatch 管理器中选择该 ZIP 安装。
- 重启设备后生效。

## 支持范围

- Linux：支持 Debian、Ubuntu、Alpine、CentOS、Fedora、RHEL、OpenWrt、ImmortalWrt、LEDE 及带有 `update-ca-certificates` 或 `update-ca-trust` 的兼容发行版。
- Windows：安装到 `LocalMachine\Root` 证书存储区，并校验证书指纹。
- macOS：安装到系统钥匙串 `/Library/Keychains/System.keychain`。
- Android：支持 Android 7+ 的常见 Magisk、KernelSU、APatch 模块安装场景；兼容传统 `/system/etc/security/cacerts` 和 Android 14+ 常见的 Conscrypt APEX 证书目录。

## 注意事项

- Linux 和 macOS 安装需要 `root` 或 `sudo` 权限。
- Windows 安装需要管理员权限，脚本会在需要时触发 UAC 提权。
- Android 安装需要已通过 Magisk、KernelSU 或 APatch 获取 root，并需要安装模块后重启。
- Android 模块不会绕过应用证书固定（SSL pinning），也不保证使用自定义 trust store 的应用信任系统 CA。
- 安装根证书会影响系统级 TLS 信任，请只在受信任设备上执行。
