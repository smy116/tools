import {
  getToolPages,
  sourceFiles,
  type CommandInput,
  type CommandSpec,
  type Env,
  type SourceFile,
  type SourceRoute,
  type ToolPage
} from "./tools.ts";

const HTML_HEADERS = {
  "Content-Type": "text/html; charset=utf-8",
  "Content-Security-Policy":
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff"
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/" || url.pathname === "/tools") {
      return Response.redirect(`${url.origin}/tools/linux-init`, 302);
    }

    if (url.pathname === "/styles.css" && env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    const source = sourceFiles[url.pathname as SourceRoute];
    if (source) {
      return proxySource(url.pathname, source, env);
    }

    const tools = getToolPages(url.origin);
    const activeTool = tools.find((tool) => tool.route === url.pathname);
    if (activeTool) {
      return html(renderPage(activeTool, tools));
    }

    return html(renderNotFound(tools), 404);
  }
};

async function proxySource(pathname: string, source: SourceFile, env: Env): Promise<Response> {
  const sourceUrl = env[source.envKey];
  if (!sourceUrl) {
    return text(`缺少 ${pathname} 对应的运行时变量 ${source.envKey}。`, 500);
  }

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

  const headers = new Headers();
  headers.set("Content-Type", source.contentType);
  headers.set("Content-Disposition", `attachment; filename="${source.filename}"`);
  headers.set("Cache-Control", "no-store");
  headers.set("X-Content-Type-Options", "nosniff");

  return new Response(upstream.body, {
    status: 200,
    headers
  });
}

function renderPage(activeTool: ToolPage, tools: ToolPage[]): string {
  return `<!doctype html>
<html lang="zh-CN">
${renderHead(activeTool.title)}
<body>
  <div class="min-h-screen bg-[radial-gradient(circle_at_top_left,#ecfdf5_0,#fbfaf7_28rem,#fafaf9_55rem)]">
    ${renderHeader(activeTool, tools)}
    <main class="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
      <section class="min-w-0">
        <div class="border-b border-line pb-7">
          <p class="${accentText(activeTool.accent)} text-sm font-semibold uppercase tracking-normal">${escapeHtml(activeTool.kicker)}</p>
          <h1 class="mt-2 text-4xl font-semibold tracking-normal text-zinc-950 sm:text-5xl">${escapeHtml(activeTool.title)}</h1>
          <p class="mt-4 max-w-3xl text-base leading-7 text-zinc-600">${escapeHtml(activeTool.description)}</p>
        </div>
        <div class="mt-6 grid gap-4">
          ${activeTool.commands.map((command) => renderCommand(command)).join("")}
        </div>
      </section>
    </main>
  </div>
  ${renderClientScript()}
</body>
</html>`;
}

function renderHead(title: string): string {
  return `<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)} | SMY 工具</title>
  <link rel="stylesheet" href="/styles.css">
</head>`;
}

function renderHeader(activeTool: ToolPage, tools: ToolPage[]): string {
  return `<header class="sticky top-0 z-20 border-b border-line bg-paper/90 backdrop-blur">
  <div class="mx-auto flex max-w-7xl flex-col gap-3 px-4 py-4 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
    <a href="/tools/linux-init" class="flex items-center gap-3 text-zinc-950">
      <span class="grid size-9 place-items-center rounded-md bg-zinc-950 text-sm font-semibold text-white">SMY</span>
      <span>
        <span class="block text-sm font-semibold leading-5">SMY 工具站</span>
        <span class="block text-xs leading-5 text-zinc-500">Cloudflare Worker</span>
      </span>
    </a>
    <nav aria-label="工具导航" class="flex gap-1 overflow-x-auto">
      ${tools.map((tool) => renderNavLink(tool, tool.slug === activeTool.slug)).join("")}
    </nav>
  </div>
</header>`;
}

function renderNavLink(tool: ToolPage, active: boolean): string {
  const activeClass = active
    ? "border-zinc-950 bg-zinc-950 text-white"
    : "border-transparent text-zinc-600 hover:border-line hover:bg-white hover:text-zinc-950";
  return `<a class="${activeClass} whitespace-nowrap rounded-md border px-3 py-2 text-sm font-medium transition" href="${escapeAttr(tool.route)}">${escapeHtml(tool.title)}</a>`;
}

function renderCommand(command: CommandSpec): string {
  const required = command.inputs?.map((input) => input.id).join(",") ?? "";
  return `<article class="min-w-0 overflow-hidden rounded-lg border border-line bg-white shadow-sm" data-command-card data-command-id="${escapeAttr(command.id)}">
  <div class="flex flex-col gap-4 p-5 sm:flex-row sm:items-start sm:justify-between">
    <div class="min-w-0">
      <div class="flex flex-wrap items-center gap-2">
        <span class="rounded-md border border-line bg-stone-50 px-2 py-1 text-xs font-medium text-zinc-600">${escapeHtml(command.platform)}</span>
        ${command.badges?.map((badge) => `<span class="rounded-md bg-emerald-50 px-2 py-1 text-xs font-medium text-emerald-800">${escapeHtml(badge)}</span>`).join("") ?? ""}
      </div>
      <h2 class="mt-3 text-xl font-semibold tracking-normal text-zinc-950">${escapeHtml(command.title)}</h2>
      <p class="mt-2 text-sm leading-6 text-zinc-600">${escapeHtml(command.description)}</p>
    </div>
    <button class="inline-flex h-10 shrink-0 items-center justify-center rounded-md bg-zinc-950 px-4 text-sm font-semibold text-white transition hover:bg-zinc-800 disabled:cursor-not-allowed disabled:bg-zinc-300 disabled:text-zinc-600" type="button" data-copy-command data-required="${escapeAttr(required)}">复制</button>
  </div>
  ${renderInputs(command)}
  <div class="min-w-0 max-w-full border-t border-line bg-zinc-950">
    <div class="flex items-center justify-between border-b border-white/10 px-4 py-2">
      <span class="text-xs font-medium uppercase tracking-normal text-zinc-400">${escapeHtml(command.language)}</span>
      <span class="text-xs text-zinc-500">${escapeHtml(command.id)}</span>
    </div>
    <pre class="command-scroll min-w-0 max-w-full overflow-x-auto p-4 text-sm leading-6 text-emerald-50"><code data-command-output data-template="${escapeAttr(command.template)}">${escapeHtml(command.template)}</code></pre>
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

function renderNotFound(tools: ToolPage[]): string {
  return `<!doctype html>
<html lang="zh-CN">
${renderHead("页面不存在")}
<body>
  <div class="min-h-screen bg-paper">
    ${renderHeader(tools[0], tools)}
    <main class="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:px-8">
      <p class="text-sm font-semibold uppercase tracking-normal text-zinc-500">404</p>
      <h1 class="mt-2 text-3xl font-semibold tracking-normal text-zinc-950">页面不存在</h1>
      <p class="mt-4 text-zinc-600">请求的工具页面不存在。</p>
      <a class="mt-6 inline-flex h-10 items-center rounded-md bg-zinc-950 px-4 text-sm font-semibold text-white" href="/tools/linux-init">打开 linux-init</a>
    </main>
  </div>
</body>
</html>`;
}

function renderClientScript(): string {
  return `<script>
(() => {
  const shellQuote = (value) => "'" + value.replace(/'/g, "'\\\\''") + "'";
  const fallbackToken = (id) => "<" + id.replace(/[A-Z]/g, (letter) => "-" + letter.toLowerCase()) + ">";

  const renderCommand = (card) => {
    const output = card.querySelector("[data-command-output]");
    const button = card.querySelector("[data-copy-command]");
    if (!output || !button) return;

    let command = output.dataset.template || "";
    let complete = true;

    card.querySelectorAll("[data-command-input]").forEach((input) => {
      const id = input.dataset.inputId;
      if (!id) return;

      const value = input.value;
      const replacement = value ? shellQuote(value) : fallbackToken(id);
      command = command.replaceAll("{{" + id + "}}", replacement);
      if (!value) complete = false;
    });

    output.textContent = command;
    button.disabled = !complete;
    if (!complete) {
      button.textContent = "填写参数";
    } else if (button.dataset.copied !== "true") {
      button.textContent = "复制";
    }
  };

  const copyText = async (text) => {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return;
    }

    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    textarea.remove();
  };

  document.querySelectorAll("[data-command-card]").forEach((card) => {
    renderCommand(card);

    card.querySelectorAll("[data-command-input]").forEach((input) => {
      input.addEventListener("input", () => renderCommand(card));
    });

    const button = card.querySelector("[data-copy-command]");
    const output = card.querySelector("[data-command-output]");
    button?.addEventListener("click", async () => {
      if (!output || button.disabled) return;
      await copyText(output.textContent || "");
      button.dataset.copied = "true";
      button.textContent = "已复制";
      window.setTimeout(() => {
        button.dataset.copied = "false";
        renderCommand(card);
      }, 1400);
    });
  });
})();
</script>`;
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
