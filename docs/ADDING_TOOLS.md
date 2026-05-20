# 新增工具指南

本文档给后续维护这个仓库的 AI 或开发者使用。目标是在新增脚本工具时，只维护工具目录内的源文件、`readme.md` 和 `tool.config.json`，由构建脚本自动生成前端页面、命令卡片和源文件路由。

## 现有约定

- 每个工具放在仓库根目录的独立目录中，例如 `linux-init/`、`ca-install/`。
- 每个工具目录必须包含 `readme.md` 和 `tool.config.json`。
- Worker 前端项目放在 `apps/tools-web/`。
- 页面由 `apps/tools-web/src/index.ts` 渲染，工具数据由 `apps/tools-web/scripts/build-tools.mjs` 生成到 `apps/tools-web/src/generated/tools.ts`。
- UI 文案使用中文；命令、路径、环境变量名、平台名可以保持英文或技术原文。
- Worker 不执行脚本，只负责展示命令和提供源文件下载。

## 新增工具目录

在仓库根目录新增一个工具目录，例如：

```text
my-tool/
  install.sh
  uninstall.sh
  readme.md
  tool.config.json
```

脚本源文件不要包含敏感信息。公开脚本可使用 `"delivery": "asset"`，构建时会复制到 `apps/tools-web/public/source/` 并通过 `/source/<tool>/<file>` 提供下载。

## README 要求

`readme.md` 面向实际使用者，不只面向维护者。建议至少包括：

- 工具用途：说明这个工具解决什么问题、适用哪些系统或场景。
- 文件说明：列出目录内主要脚本、配置、证书或资源文件的作用。
- 使用方法：提供工具站源文件路由对应的一键命令；如支持本地执行，也给出本地命令。
- 参数说明：如果脚本支持命令参数或用户输入，说明每个参数的含义和示例。
- 注意事项：写清楚 `root`、`sudo`、管理员权限、网络依赖、系统级变更、敏感输入等风险。

命令示例中的工具站域名使用 `https://<tools-origin>` 占位，实际页面命令会根据访问域名生成。

## tool.config.json

基础示例：

```json
{
  "slug": "my-tool",
  "title": "my-tool",
  "category": "工具分类",
  "summary": "用一句中文说明这个工具解决什么问题。",
  "platforms": ["Linux"],
  "tags": ["root"],
  "order": 30,
  "accent": "amber",
  "sourceFiles": [
    {
      "id": "install",
      "path": "install.sh",
      "route": "/source/my-tool/install.sh",
      "filename": "install.sh",
      "contentType": "text/x-shellscript; charset=utf-8",
      "label": "my-tool 安装脚本",
      "delivery": "asset"
    }
  ],
  "commands": [
    {
      "id": "my-tool-install",
      "title": "安装 my-tool",
      "description": "下载并执行 my-tool 安装脚本。",
      "platform": "Linux",
      "language": "bash",
      "badges": ["root"],
      "template": "curl -fsSL {{source:install}} -o /tmp/my-tool-install.sh && sudo bash /tmp/my-tool-install.sh"
    }
  ]
}
```

字段说明：

- `slug`：小写 kebab-case，用于 `/tools/<slug>`。
- `category`、`summary`：用于工具列表和详情页顶部说明。
- `platforms`：用于首页筛选。
- `tags`：用于权限、风险或场景标签。
- `order`：工具列表排序，数字越小越靠前。
- `accent`：可选 `emerald`、`sky`、`amber`。
- `sourceFiles[].path`：工具目录内的源文件相对路径，不允许跳出工具目录。
- `sourceFiles[].route`：必须以 `/source/<slug>/` 开头。
- `sourceFiles[].delivery`：公开仓库文件使用 `asset`；外部或私有 URL 使用 `remote`。
- `sourceFiles[].envKey`：可选，配置后可作为静态资源不可用时的远程兜底，或作为 `remote` 源文件 URL。

常用 `contentType`：

```text
Shell:      text/x-shellscript; charset=utf-8
Batch:      application/x-bat; charset=utf-8
PowerShell: text/plain; charset=utf-8
证书:       application/x-x509-ca-cert
JSON:       application/json; charset=utf-8
文本:       text/plain; charset=utf-8
```

## 命令模板

命令中的源文件 URL 使用 `{{source:<id>}}` 占位：

```json
"template": "curl -fsSL {{source:install}} -o /tmp/my-tool.sh && sudo bash /tmp/my-tool.sh"
```

页面渲染时会替换为当前访问域名下的完整 URL。

如果命令需要用户输入参数，增加 `inputs`，并在 `template` 中使用 `{{inputId}}` 占位：

```json
{
  "id": "my-tool-login",
  "title": "配置登录令牌",
  "description": "使用本地输入的令牌执行配置。",
  "platform": "Linux",
  "language": "bash",
  "badges": ["root", "本地输入"],
  "inputs": [
    {
      "id": "token",
      "label": "访问令牌",
      "placeholder": "请输入访问令牌",
      "type": "password",
      "quote": "posix"
    }
  ],
  "template": "curl -fsSL {{source:install}} -o /tmp/my-tool.sh && sudo bash /tmp/my-tool.sh login {{token}}"
}
```

前端会在浏览器本地完成参数替换和 POSIX 单引号转义，不会把输入值发送给 Worker。

命令设计建议：

- 交互式脚本不要使用 `curl | bash`，优先下载到临时文件再执行。
- 需要 `sudo` 或管理员权限的命令，要在 `badges` 和说明中写清楚。
- 不要在命令模板中内置密码、token、secret。
- Windows 命令通常使用 `powershell`，可通过 `Start-Process -Verb RunAs` 触发管理员权限。
- macOS 需要系统级变更时，优先使用 `sudo` 并在说明中标明。

## 构建与测试

新增或修改工具后至少检查：

```bash
cd apps/tools-web
npm run build
npm run dev
```

浏览器检查：

- `/tools` 能展示新工具卡片。
- `/tools/<slug>` 能打开。
- 搜索和平台筛选可用。
- 命令卡片文案为中文。
- 复制按钮可用。
- 有输入参数的命令在未填写时显示“填写参数”。
- 填写参数后，命令中的 `{{inputId}}` 被替换。
- `/source/<tool>/<file>` 能返回源文件。

部署检查：

- push 到 GitHub 后 Cloudflare Workers Builds 成功。
- 如使用 `remote` 或 `envKey` 兜底，Worker 运行时变量已配置完整。
- 生产页面能打开并复制命令。

## 不要做的事

- 不要把新增工具页面写死在 `apps/tools-web/src/index.ts` 中。
- 不要绕过 `/source/*` 路由直接在页面里引用 GitHub raw URL。
- 不要把用户输入发送到 Worker。
- 不要把敏感值提交进仓库。
- 不要把构建期 Build variables 当成运行时变量使用。
