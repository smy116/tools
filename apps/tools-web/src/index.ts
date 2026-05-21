import { sourceFiles, toolPages } from "./generated/tools.ts";
import type { CommandInput, CommandSpec, Env, SourceFile, ToolPage } from "./tools.ts";

const HTML_HEADERS = {
  "Content-Type": "text/html; charset=utf-8",
  "Content-Security-Policy":
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff"
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/" || url.pathname === "/tools") {
      return html(renderHome(toolPages));
    }

    if ((url.pathname === "/styles.css" || url.pathname === "/client.js") && env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    const source = sourceFiles[url.pathname];
    if (source) {
      return serveSource(request, url, source, env);
    }

    const activeTool = toolPages.find((tool) => tool.route === url.pathname);
    if (activeTool) {
      return html(renderToolPage(activeTool, url.origin));
    }

    return html(renderNotFound(), 404);
  }
};

async function serveSource(request: Request, url: URL, source: SourceFile, env: Env): Promise<Response> {
  if (source.delivery === "asset" && env.ASSETS) {
    const asset = await env.ASSETS.fetch(
      new Request(`${url.origin}${source.route}`, {
        method: request.method,
        headers: request.headers
      })
    );
    if (asset.ok) {
      return withSourceHeaders(asset, source);
    }
  }

  const remoteUrl = source.envKey ? env[source.envKey] : undefined;
  if (typeof remoteUrl === "string" && remoteUrl) {
    return proxyRemoteSource(source, remoteUrl);
  }

  const detail = source.envKey
    ? `本地静态资源不可用，且运行时变量 ${source.envKey} 未配置。`
    : "本地静态资源不可用。";
  return text(`无法获取 ${source.route}。${detail}`, 404);
}

async function proxyRemoteSource(source: SourceFile, sourceUrl: string): Promise<Response> {
  let upstream: Response;
  try {
    upstream = await fetch(sourceUrl, {
      headers: {
        Accept: "*/*"
      }
    });
  } catch (error) {
    return text(`获取 ${source.envKey} 失败：${formatError(error)}`, 502);
  }

  if (!upstream.ok) {
    const body = await upstream.text().catch(() => "");
    const detail = body ? `\n\n${body.slice(0, 800)}` : "";
    return text(`上游 ${source.envKey} 返回 ${upstream.status} ${upstream.statusText}。${detail}`, 502);
  }

  return withSourceHeaders(upstream, source);
}

function withSourceHeaders(response: Response, source: SourceFile): Response {
  const headers = new Headers(response.headers);
  headers.set("Content-Type", source.contentType);
  headers.set("Content-Disposition", `attachment; filename="${source.filename}"`);
  headers.set("Cache-Control", "public, max-age=300");
  headers.set("X-Content-Type-Options", "nosniff");

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}

function renderHome(tools: ToolPage[]): string {
  return `<!doctype html>
<html lang="zh-CN">
${renderHead("工具列表", "SMY 工具站收纳脚本工具、安装命令和源文件下载。")}
<body>
  <div class="min-h-screen bg-paper">
    ${renderHeader(true)}
    <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <section class="border-b border-line pb-8">
        <div class="min-w-0">
          <h1 class="mt-2 text-3xl font-semibold tracking-normal text-zinc-950 sm:text-4xl">SMY 工具站</h1>
          <p class="mt-4 max-w-3xl text-base leading-7 text-zinc-600">集中展示每个工具的用途、适用平台、权限风险、源文件和一键命令。</p>
        </div>
      </section>

      <section class="mt-7">
        <div class="mb-4 flex items-center justify-between gap-3">
          <h2 class="text-base font-semibold text-zinc-950">工具列表</h2>
          <p class="text-sm text-zinc-500"><span data-tool-count>${tools.length}</span> 个工具</p>
        </div>
        <div class="grid gap-4 md:grid-cols-2">
          ${tools.map((tool) => renderToolCard(tool)).join("")}
        </div>
      </section>
    </main>
  </div>
</body>
</html>`;
}

function renderToolCard(tool: ToolPage): string {
  const searchText = [tool.title, tool.category, tool.summary, ...tool.platforms, ...tool.tags].join(" ");

  return `<article class="min-w-0 rounded-lg border border-line bg-white p-5 shadow-sm" data-tool-card data-platforms="${escapeAttr(tool.platforms.join(","))}" data-search="${escapeAttr(searchText)}">
  <div class="min-w-0">
    <p class="${accentText(tool.accent)} text-sm font-semibold">${escapeHtml(tool.category)}</p>
    <h3 class="mt-1 text-xl font-semibold tracking-normal text-zinc-950">${escapeHtml(tool.title)}</h3>
  </div>
  <p class="mt-3 text-sm leading-6 text-zinc-600">${escapeHtml(tool.summary)}</p>
  <div class="mt-4 flex flex-wrap gap-2">
    ${tool.platforms.map((platform) => renderBadge(platform, "neutral")).join("")}
    ${tool.tags.slice(0, 4).map((tag) => renderBadge(tag, "soft")).join("")}
  </div>
  <a class="mt-5 inline-flex h-10 items-center justify-center rounded-md bg-zinc-950 px-4 text-sm font-semibold text-white transition hover:bg-zinc-800" href="${escapeAttr(tool.route)}">打开工具</a>
</article>`;
}

function renderToolPage(activeTool: ToolPage, origin: string): string {
  return `<!doctype html>
<html lang="zh-CN">
${renderHead(activeTool.title, activeTool.summary)}
<body>
  <div class="min-h-screen bg-paper">
    ${renderHeader()}
    <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <section class="border-b border-line pb-7">
        <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="min-w-0">
            <p class="${accentText(activeTool.accent)} text-sm font-semibold">${escapeHtml(activeTool.category)}</p>
            <h1 class="mt-2 text-3xl font-semibold tracking-normal text-zinc-950 sm:text-4xl">${escapeHtml(activeTool.title)}</h1>
            <p class="mt-4 max-w-3xl text-base leading-7 text-zinc-600">${escapeHtml(activeTool.summary)}</p>
          </div>
          <div class="flex flex-wrap gap-2">
            ${activeTool.platforms.map((platform) => renderBadge(platform, "neutral")).join("")}
            ${activeTool.tags.map((tag) => renderBadge(tag, "soft")).join("")}
          </div>
        </div>
      </section>

      <div class="mt-7 grid gap-8 lg:grid-cols-[minmax(0,1fr)_20rem] lg:items-start">
        <div class="min-w-0">
          <section>
            <div class="mb-4">
              <div>
                <p class="text-sm font-semibold text-zinc-500">Shortcuts</p>
                <h2 class="mt-1 text-2xl font-semibold tracking-normal text-zinc-950">一键命令</h2>
              </div>
            </div>
            <div class="grid gap-4">
              ${activeTool.commands.map((command) => renderCommand(command, activeTool, origin)).join("")}
            </div>
          </section>

          <section class="mt-10">
            <div class="mb-4">
              <p class="text-sm font-semibold text-zinc-500">README</p>
              <h2 class="mt-1 text-2xl font-semibold tracking-normal text-zinc-950">完整说明</h2>
            </div>
            <article class="readme-content">
              ${activeTool.readmeHtml}
            </article>
          </section>
        </div>

        <aside class="grid gap-4 lg:sticky lg:top-24">
          ${renderSourcePanel(activeTool, origin)}
          <section class="rounded-lg border border-line bg-white p-4 shadow-sm">
            <h2 class="text-sm font-semibold text-zinc-950">维护入口</h2>
            <p class="mt-2 text-sm leading-6 text-zinc-600">页面内容由工具目录下的 <code>readme.md</code> 和 <code>tool.config.json</code> 生成。</p>
          </section>
        </aside>
      </div>
    </main>
  </div>
</body>
</html>`;
}

function renderSourcePanel(tool: ToolPage, origin: string): string {
  return `<section class="rounded-lg border border-line bg-white p-4 shadow-sm">
  <h2 class="text-sm font-semibold text-zinc-950">源文件</h2>
  <div class="mt-3 grid gap-3">
    ${tool.sourceFiles.map((source) => `<a class="block rounded-md border border-line bg-stone-50 p-3 transition hover:border-zinc-300 hover:bg-white" href="${escapeAttr(source.route)}">
      <span class="block text-sm font-semibold text-zinc-950">${escapeHtml(source.label)}</span>
      <span class="mt-1 block break-all text-xs leading-5 text-zinc-500">${escapeHtml(`${origin}${source.route}`)}</span>
    </a>`).join("")}
  </div>
</section>`;
}

function renderHeader(showSearch = false): string {
  return `<header class="sticky top-0 z-20 border-b border-line bg-paper/95 backdrop-blur">
  <div class="mx-auto flex max-w-7xl flex-col gap-3 px-4 py-4 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
    <a href="/tools" class="flex items-center gap-3 text-zinc-950">
      <span class="grid size-9 place-items-center rounded-md bg-zinc-950 text-sm font-semibold text-white">SMY</span>
      <span>
        <span class="block text-sm font-semibold leading-5">SMY 工具站</span>
      </span>
    </a>
    ${showSearch ? renderHeaderSearch() : ""}
  </div>
</header>`;
}

function renderHeaderSearch(): string {
  return `<label class="w-full lg:w-80">
    <span class="sr-only">搜索工具</span>
    <input class="h-10 w-full rounded-md border border-line bg-white px-3 text-sm text-zinc-950 outline-none transition placeholder:text-zinc-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100" type="search" placeholder="按名称、平台、用途或标签搜索" data-tool-search>
  </label>`;
}

function renderCommand(command: CommandSpec, tool: ToolPage, origin: string): string {
  const required = command.inputs?.map((input) => input.id).join(",") ?? "";
  const template = resolveSourcePlaceholders(command.template, tool, origin);

  return `<article class="min-w-0 overflow-hidden rounded-lg border border-line bg-white shadow-sm" data-command-card data-command-id="${escapeAttr(command.id)}">
  <div class="flex flex-col gap-4 p-5 sm:flex-row sm:items-start sm:justify-between">
    <div class="min-w-0">
      <div class="flex flex-wrap items-center gap-2">
        ${renderBadge(command.platform, "neutral")}
        ${command.badges?.map((badge) => renderBadge(badge, "soft")).join("") ?? ""}
      </div>
      <h3 class="mt-3 text-xl font-semibold tracking-normal text-zinc-950">${escapeHtml(command.title)}</h3>
      <p class="mt-2 text-sm leading-6 text-zinc-600">${escapeHtml(command.description)}</p>
    </div>
    <button class="inline-flex h-10 shrink-0 items-center justify-center rounded-md bg-zinc-950 px-4 text-sm font-semibold text-white transition hover:bg-zinc-800 disabled:cursor-not-allowed disabled:bg-zinc-300 disabled:text-zinc-600" type="button" data-copy-command data-required="${escapeAttr(required)}">复制</button>
  </div>
  ${renderInputs(command)}
  <div class="min-w-0 max-w-full border-t border-line bg-zinc-950">
    <div class="flex items-center justify-between gap-4 border-b border-white/10 px-4 py-2">
      <span class="text-xs font-medium uppercase tracking-normal text-zinc-400">${escapeHtml(command.language)}</span>
      <span class="truncate text-xs text-zinc-500">${escapeHtml(command.id)}</span>
    </div>
    <pre class="command-scroll min-w-0 max-w-full overflow-x-auto p-4 text-sm leading-6 text-emerald-50"><code data-command-output data-template="${escapeAttr(template)}">${escapeHtml(template)}</code></pre>
  </div>
</article>`;
}

function renderInputs(command: CommandSpec): string {
  if (!command.inputs?.length) {
    return "";
  }

  return `<div class="grid gap-3 border-t border-line bg-stone-50 px-5 py-4 sm:grid-cols-2">
    ${command.inputs.map((input) => renderInput(command.id, input)).join("")}
  </div>`;
}

function renderInput(commandId: string, input: CommandInput): string {
  return `<label class="grid gap-1.5 text-sm font-medium text-zinc-700">
  <span>${escapeHtml(input.label)}</span>
  <input class="h-10 rounded-md border border-line bg-white px-3 text-sm text-zinc-950 outline-none transition placeholder:text-zinc-400 focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100" type="${escapeAttr(input.type)}" placeholder="${escapeAttr(input.placeholder)}" autocomplete="off" data-command-input data-command-id="${escapeAttr(commandId)}" data-input-id="${escapeAttr(input.id)}" data-quote="${escapeAttr(input.quote)}">
</label>`;
}

function renderNotFound(): string {
  return `<!doctype html>
<html lang="zh-CN">
${renderHead("页面不存在", "请求的工具页面不存在。")}
<body>
  <div class="min-h-screen bg-paper">
    ${renderHeader()}
    <main class="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:px-8">
      <p class="text-sm font-semibold uppercase tracking-normal text-zinc-500">404</p>
      <h1 class="mt-2 text-3xl font-semibold tracking-normal text-zinc-950">页面不存在</h1>
      <p class="mt-4 text-zinc-600">请求的工具页面不存在。</p>
      <a class="mt-6 inline-flex h-10 items-center rounded-md bg-zinc-950 px-4 text-sm font-semibold text-white" href="/tools">打开工具列表</a>
    </main>
  </div>
</body>
</html>`;
}

function renderHead(title: string, description: string): string {
  return `<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeAttr(description)}">
  <title>${escapeHtml(title)} | SMY 工具</title>
  <link rel="stylesheet" href="/styles.css">
  <script defer src="/client.js"></script>
</head>`;
}

function resolveSourcePlaceholders(template: string, tool: ToolPage, origin: string): string {
  return template.replace(/\{\{source:([^}]+)\}\}/g, (_match, sourceId: string) => {
    const source = tool.sourceFiles.find((item) => item.id === sourceId);
    return source ? `${origin}${source.route}` : `<missing-source:${sourceId}>`;
  });
}

function renderBadge(value: string, tone: "neutral" | "soft"): string {
  const classes =
    tone === "neutral"
      ? "rounded-md border border-line bg-stone-50 px-2 py-1 text-xs font-medium text-zinc-600"
      : "rounded-md bg-emerald-50 px-2 py-1 text-xs font-medium text-emerald-800";
  return `<span class="${classes}">${escapeHtml(value)}</span>`;
}

function accentText(accent: ToolPage["accent"]): string {
  switch (accent) {
    case "sky":
      return "text-skyline";
    case "amber":
      return "text-copper";
    default:
      return "text-accent";
  }
}

function html(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: HTML_HEADERS
  });
}

function text(body: string, status: number): Response {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff"
    }
  });
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escapeAttr(value: string): string {
  return escapeHtml(value).replace(/\n/g, "&#10;");
}

function formatError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
