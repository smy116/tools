export type AssetBinding = {
  fetch(request: Request): Promise<Response>;
};

export type Env = {
  ASSETS?: AssetBinding;
  [key: string]: string | AssetBinding | undefined;
};

export type SourceDelivery = "asset" | "remote";

export type SourceFile = {
  id: string;
  toolSlug: string;
  path: string;
  route: string;
  filename: string;
  contentType: string;
  label: string;
  delivery: SourceDelivery;
  envKey?: string;
};

export type Shortcut = {
  name: string;
  toolSlug: string;
  // 指向的源文件路由，例如 /source/linux-init/init.sh
  route: string;
};

export type CommandInput = {
  id: string;
  label: string;
  placeholder: string;
  type: "password" | "text";
  quote: "posix";
  // 留空时从命令中移除该参数；可选参数必须位于模板中所有必填参数之后
  optional?: boolean;
};

export type CommandSpec = {
  id: string;
  title: string;
  description: string;
  platform: string;
  language: "bash" | "powershell";
  template: string;
  inputs?: CommandInput[];
  badges?: string[];
};

export type ToolAccent = "emerald" | "sky" | "amber";

export type ToolPage = {
  slug: string;
  route: string;
  title: string;
  category: string;
  summary: string;
  platforms: string[];
  tags: string[];
  order: number;
  accent: ToolAccent;
  readmeHtml: string;
  sourceFiles: SourceFile[];
  shortcuts: Shortcut[];
  commands: CommandSpec[];
};
