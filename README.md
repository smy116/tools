# SMY 工具站

这是一个部署在 Cloudflare Workers 上的脚本工具入口站。仓库根目录保留各工具的源文件、README 和结构化配置，Worker 项目位于 `apps/tools-web`。

前端页面由构建脚本生成工具数据：`readme.md` 负责长说明，`tool.config.json` 负责命令、源文件路由、平台、标签和权限提示。这样后续新增工具时不需要手工改 Worker 页面代码。

## 仓库结构

```text
linux-init/               VPS 初始化脚本源文件
  readme.md               面向使用者的说明文档
  tool.config.json        前端展示和命令配置
ca-install/               CA 证书安装脚本源文件
apps/tools-web/           Cloudflare Worker 前端项目
docs/                     项目维护文档
```

## 前端生成流程

`apps/tools-web/scripts/build-tools.mjs` 会在构建阶段完成这些工作：

- 扫描仓库根目录下带有 `tool.config.json` 的工具目录。
- 校验 `slug`、源文件路由、命令占位符和输入参数。
- 将各工具的 `readme.md` 转换为安全 HTML。
- 复制公开源文件到 `apps/tools-web/public/source/`。
- 生成 `apps/tools-web/src/generated/tools.ts`，供 Worker 渲染页面和处理 `/source/*` 使用。

当前前端保留轻量 Worker 架构，不引入 React/Astro/Vite。`/tools` 是工具列表页，`/tools/<slug>` 是工具详情页，`/source/<tool>/<file>` 是统一源文件下载入口。

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

仓库内公开源文件会在构建时复制到 Worker 静态资源中，当前工具不再强制依赖 GitHub raw URL 运行时变量。

只有以下情况才需要在 Cloudflare Worker 的运行时环境中配置变量：

- 某个源文件在 `tool.config.json` 中配置为 `"delivery": "remote"`。
- 希望在静态资源不可用时，用 `envKey` 指向的远程 URL 作为兜底。

变量需要配置在 Worker 的运行时环境中，不要放到 Build variables：

```text
Workers & Pages -> 选择 Worker -> Settings -> Variables and Secrets -> Add
```

## 本地开发

进入 Worker 项目目录：

```bash
cd apps/tools-web
npm install
npm run build
npm run dev
```

`npm run build` 会先生成工具数据和静态源文件，再构建 CSS 并执行 TypeScript 检查。

## 新增工具

后续新增工具时，请参考 [新增工具指南](docs/ADDING_TOOLS.md)。
