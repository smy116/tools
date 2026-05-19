# SMY 工具站

这是一个部署在 Cloudflare Workers 上的脚本工具入口站。仓库根目录保留脚本源文件，Worker 项目位于 `apps/tools-web`，网页会展示每个工具的说明和一键复制命令。

## 仓库结构

```text
linux-init/          VPS 初始化脚本源文件
ca-install/          CA 证书安装脚本源文件
apps/tools-web/      Cloudflare Worker 前端项目
docs/                项目维护文档
```

## Cloudflare Workers Builds 配置

在 Cloudflare 面板关联 GitHub 仓库时，使用以下配置：

```text
Root directory: apps/tools-web
Build command: npm run build
Deploy command: npx wrangler deploy
Preview command: npx wrangler versions upload
```

`apps/tools-web/wrangler.jsonc` 里的 `name` 必须和 Cloudflare 面板中的 Worker 名称一致。当前默认值是：

```text
smy-tools-web
```

如果你在面板里使用其他 Worker 名称，需要同步修改 `wrangler.jsonc`。

## 运行时变量

这些变量需要配置在 Worker 的运行时环境中：

```text
Settings -> Variables and Secrets -> Add
```

添加以下 `Text` 类型变量：

```text
LINUX_INIT_SH_URL
CA_INSTALL_URL_LINUX
CA_INSTALL_URL_WINDOWS
CA_INSTALL_URL_MAC
CA_CERT_URL
```

公开 GitHub 仓库可以使用 raw URL，例如：

```text
https://raw.githubusercontent.com/<owner>/<repo>/main/linux-init/init.sh
https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/Install-To-Linux.sh
https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/Install-To-Windows.ps1
https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/Install-To-Mac.sh
https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/SMY-Root-CA.crt
```

这些变量不要填到 Build variables 里。Build variables 只在构建阶段可用，而本项目是在 Worker 运行时拉取脚本源文件。

## 本地开发

进入 Worker 项目目录：

```bash
cd apps/tools-web
npm install
npm run build
npm run dev
```

本地调试运行时变量可以放在 `apps/tools-web/.dev.vars`：

```text
LINUX_INIT_SH_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/linux-init/init.sh
CA_INSTALL_URL_LINUX=https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/Install-To-Linux.sh
CA_INSTALL_URL_WINDOWS=https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/Install-To-Windows.ps1
CA_INSTALL_URL_MAC=https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/Install-To-Mac.sh
CA_CERT_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/ca-install/SMY-Root-CA.crt
```

## 新增工具

后续新增工具时，请参考 [AI 新增工具指南](docs/ADDING_TOOLS_FOR_AI.md)。
