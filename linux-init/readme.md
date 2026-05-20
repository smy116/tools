# linux-init

`linux-init` 是 VPS 和轻量 Linux 主机的初始化脚本，面向 Debian、Ubuntu、OpenWrt、Alpine 及兼容发行版。它提供交互式菜单，也支持部分操作通过命令参数直接执行。

## 文件说明

- `init.sh`：主初始化脚本，包含交互式菜单和快捷参数入口。
- `nginx/nginx.conf`：安装 Nginx 时使用的默认配置模板。
- `nginx/fake-page.tar.gz`：Nginx 默认站点的静态页面资源。

## 主要功能

- 设置系统时区为 UTC+8。
- 配置 root 密码和脚本内置 SSH 公钥。
- 将 SSH 端口修改为 `54422`。
- 安装 `SMY Root Certification Authority ECC`。
- 安装 Nezha Agent。
- 安装并启动 Nginx 或 Caddy。
- 重启系统。

## 使用方法

从工具站在内存中加载脚本并打开交互式菜单：

```bash
sudo bash -c 'bash <(curl -fsSL "$1")' _ "https://<tools-origin>/source/linux-init/init.sh"
```

如果已经克隆本仓库，也可以直接在本目录执行：

```bash
sudo bash init.sh
```

脚本支持以下快捷参数：

```bash
sudo bash init.sh ca
sudo bash init.sh sshport
sudo bash init.sh root '<root-password>'
sudo bash init.sh nezha '<nezha-client-secret>'
sudo bash init.sh caddy
```

通过工具站源文件在内存中执行快捷参数时：

```bash
sudo bash -c 'bash <(curl -fsSL "$1") "$2"' _ "https://<tools-origin>/source/linux-init/init.sh" ca
```

工具站命令使用 Bash process substitution 在内存中加载远端脚本，不会把主脚本写入 `/tmp`。交互式菜单也可以继续从当前终端读取输入。

## 参数说明

- `ca`：安装 SMY Root CA 到系统信任库。
- `sshport`：将 SSH 端口改为 `54422` 并重启 SSH 服务。
- `root <root-password>`：设置 root 密码，并写入脚本内置 SSH 公钥。
- `nezha <nezha-client-secret>`：使用指定客户端密钥安装 Nezha Agent。
- `caddy`：安装 Caddy，并根据提示写入站点配置。

Nginx 安装、时区设置、系统重启等操作可通过交互式菜单执行。

## 注意事项

- 脚本需要 `root` 或 `sudo` 权限。
- 修改 SSH 端口或 root 登录配置前，请确保当前控制台不会因 SSH 重启而丢失访问。
- `root` 密码和 Nezha 客户端密钥只应在本地命令中输入，不要写入仓库或提交记录。
- 脚本会根据发行版安装依赖，执行前建议先确认系统包管理器可用。
