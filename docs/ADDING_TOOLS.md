# AI 新增工具指南

本文档给后续维护这个仓库的 AI 或开发者使用。目标是在新增一个脚本工具时，同时新增前端工具页面、源文件代理路由和一键复制 Shortcut。

## 现有约定

- 脚本源文件放在仓库根目录的独立工具目录中，例如 `linux-init/`、`ca-install/`。
- Worker 前端项目放在 `apps/tools-web/`。
- 前端不使用 React/Vite/Astro，页面由 `apps/tools-web/src/index.ts` 直接渲染 HTML。
- 工具清单集中维护在 `apps/tools-web/src/tools.ts`。
- UI 文案使用中文；命令、路径、环境变量名、平台名可以保持英文或技术原文。
- Worker 不执行脚本，只负责展示命令和代理源文件下载。

## 新增工具目录

在仓库根目录新增一个工具目录，例如：

```text
my-tool/
  install.sh
  uninstall.sh
  readme.md
```

脚本源文件应保持可直接从 GitHub raw URL 下载。不要把敏感信息写进脚本或前端代码。

## 新增工具 README

每个工具目录必须包含 `readme.md`，用于说明该工具的用途和使用方法。README 面向实际使用者，不只面向维护者，内容至少包括：

- 工具用途：用一到两段中文说明这个工具解决什么问题、适用哪些系统或场景。
- 文件说明：列出目录内主要脚本、配置、证书或资源文件的作用。
- 使用方法：提供工具站源文件路由对应的一键命令；如果支持本地执行，也给出本地命令。
- 参数说明：如果脚本支持命令参数或用户输入，说明每个参数的含义和示例。
- 注意事项：写清楚 `root`、`sudo`、管理员权限、网络依赖、系统级变更、敏感输入等风险。

命令示例中的工具站域名使用 `https://<tools-origin>` 占位，实际页面命令由 `apps/tools-web/src/tools.ts` 生成。README 里的命令、源文件路由和前端 Shortcut 命令应保持一致。

## 新增运行时变量类型

编辑 `apps/tools-web/src/tools.ts`，在 `EnvKey` 中增加新工具需要的源文件 URL 变量。

示例：

```ts
export type EnvKey =
  | "LINUX_INIT_SH_URL"
  | "CA_INSTALL_URL_LINUX"
  | "CA_INSTALL_URL_WINDOWS"
  | "CA_INSTALL_URL_MAC"
  | "CA_CERT_URL"
  | "MY_TOOL_INSTALL_URL"
  | "MY_TOOL_UNINSTALL_URL";
```

命名建议：

- 使用全大写和下划线。
- URL 变量以 `_URL` 结尾。
- 多平台工具可以使用类似 `MY_TOOL_URL_LINUX`、`MY_TOOL_URL_WINDOWS`、`MY_TOOL_URL_MAC`。

## 新增源文件代理路由

继续编辑 `apps/tools-web/src/tools.ts`，在 `sourceFiles` 中增加路由。

示例：

```ts
export const sourceFiles = {
  "/source/my-tool/install.sh": {
    envKey: "MY_TOOL_INSTALL_URL",
    filename: "install.sh",
    contentType: "text/x-shellscript; charset=utf-8",
    label: "my-tool 安装脚本"
  },
  "/source/my-tool/uninstall.sh": {
    envKey: "MY_TOOL_UNINSTALL_URL",
    filename: "uninstall.sh",
    contentType: "text/x-shellscript; charset=utf-8",
    label: "my-tool 卸载脚本"
  }
} as const satisfies Record<string, SourceFile>;
```

常用 `contentType`：

```text
Shell:      text/x-shellscript; charset=utf-8
Batch:      application/x-bat; charset=utf-8
PowerShell: text/plain; charset=utf-8
证书:       application/x-x509-ca-cert
JSON:       application/json; charset=utf-8
文本:       text/plain; charset=utf-8
```

## 新增工具页面

在 `getToolPages(origin: string)` 中先定义该工具的源文件 URL：

```ts
const myToolInstallUrl = `${origin}/source/my-tool/install.sh`;
const myToolUninstallUrl = `${origin}/source/my-tool/uninstall.sh`;
```

然后在返回数组中增加一个 `ToolPage`：

```ts
{
  slug: "my-tool",
  route: "/tools/my-tool",
  title: "my-tool",
  kicker: "工具分类或用途",
  description: "用一句中文说明这个工具解决什么问题。",
  accent: "amber",
  commands: [
    {
      id: "my-tool-install",
      title: "安装 my-tool",
      description: "下载并执行 my-tool 安装脚本。",
      platform: "Linux",
      language: "bash",
      badges: ["root"],
      template: `curl -fsSL ${myToolInstallUrl} -o /tmp/my-tool-install.sh && sudo bash /tmp/my-tool-install.sh`
    }
  ]
}
```

新增后，横向导航栏会自动出现该工具入口，不需要修改 `index.ts` 的导航逻辑。

## 新增 Shortcut 命令

每个 Shortcut 对应 `commands` 数组中的一个 `CommandSpec`。

基础字段：

```ts
{
  id: "my-tool-action",
  title: "按钮卡片标题",
  description: "中文说明这条命令会做什么。",
  platform: "Linux",
  language: "bash",
  badges: ["root"],
  template: `curl -fsSL ${myToolInstallUrl} -o /tmp/my-tool.sh && sudo bash /tmp/my-tool.sh`
}
```

如果命令需要用户输入参数，增加 `inputs`，并在 `template` 中使用 `{{inputId}}` 占位：

```ts
{
  id: "my-tool-login",
  title: "配置登录令牌",
  description: "使用本地输入的令牌执行配置。",
  platform: "Linux",
  language: "bash",
  badges: ["root", "本地输入"],
  inputs: [
    {
      id: "token",
      label: "访问令牌",
      placeholder: "请输入访问令牌",
      type: "password",
      quote: "posix"
    }
  ],
  template: `curl -fsSL ${myToolInstallUrl} -o /tmp/my-tool.sh && sudo bash /tmp/my-tool.sh login {{token}}`
}
```

前端会在浏览器本地完成参数替换和 POSIX 单引号转义，不会把输入值发送给 Worker。

命令设计建议：

- 交互式脚本不要使用 `curl | bash`，优先下载到临时文件再执行。
- 需要 `sudo` 或管理员权限的命令，要在 `badges` 和说明中写清楚。
- 不要在命令模板中内置密码、token、secret。
- Windows 命令通常使用 `powershell`，可通过 `Start-Process -Verb RunAs` 触发管理员权限。
- macOS 需要系统级变更时，优先使用 `sudo` 并在说明中标明。

## 配置 Cloudflare 运行时变量

新增工具后，需要在 Cloudflare 面板中添加对应变量：

```text
Workers & Pages -> 选择 Worker -> Settings -> Variables and Secrets -> Add
```

变量类型使用 `Text`。公开 GitHub 仓库示例：

```text
MY_TOOL_INSTALL_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/my-tool/install.sh
MY_TOOL_UNINSTALL_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/my-tool/uninstall.sh
```

这些变量必须是运行时变量，不要放在 Build variables 中。

## 测试清单

新增工具后至少检查：

```bash
cd apps/tools-web
npm run build
npm run typecheck
npm run dev
```

浏览器检查：

- `/tools/<slug>` 能打开。
- 横向导航中出现新工具。
- 命令卡片文案为中文。
- 复制按钮可用。
- 有输入参数的命令在未填写时显示“填写参数”。
- 填写参数后，命令中的 `{{inputId}}` 被替换。
- `/source/<tool>/<file>` 能返回远端源文件。

部署检查：

- push 到 GitHub 后 Cloudflare Workers Builds 成功。
- Worker 运行时变量已配置完整。
- 生产页面能打开并复制命令。

## 不要做的事

- 不要把新增工具页面写死在 `index.ts` 中。
- 不要绕过 `sourceFiles` 直接在页面里引用 GitHub raw URL。
- 不要把用户输入发送到 Worker。
- 不要把敏感值提交进仓库。
- 不要把构建期 Build variables 当成运行时变量使用。
