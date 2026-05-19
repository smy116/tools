export type AssetBinding = {
  fetch(request: Request): Promise<Response>;
};

export type EnvKey =
  | "LINUX_INIT_SH_URL"
  | "CA_INSTALL_URL_LINUX"
  | "CA_INSTALL_URL_WINDOWS"
  | "CA_INSTALL_URL_MAC"
  | "CA_CERT_URL";

export type Env = Partial<Record<EnvKey, string>> & {
  ASSETS?: AssetBinding;
};

export type SourceFile = {
  envKey: EnvKey;
  filename: string;
  contentType: string;
  label: string;
};

export type CommandInput = {
  id: string;
  label: string;
  placeholder: string;
  type: "password" | "text";
  quote: "posix";
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

export type ToolPage = {
  slug: string;
  route: string;
  title: string;
  kicker: string;
  description: string;
  accent: "emerald" | "sky" | "amber";
  commands: CommandSpec[];
};

export const sourceFiles = {
  "/source/linux-init/init.sh": {
    envKey: "LINUX_INIT_SH_URL",
    filename: "init.sh",
    contentType: "text/x-shellscript; charset=utf-8",
    label: "linux-init 脚本"
  },
  "/source/ca-install/linux.sh": {
    envKey: "CA_INSTALL_URL_LINUX",
    filename: "Install-To-Linux.sh",
    contentType: "text/x-shellscript; charset=utf-8",
    label: "Linux CA 安装脚本"
  },
  "/source/ca-install/windows.ps1": {
    envKey: "CA_INSTALL_URL_WINDOWS",
    filename: "Install-To-Windows.ps1",
    contentType: "text/plain; charset=utf-8",
    label: "Windows CA 安装脚本"
  },
  "/source/ca-install/mac.sh": {
    envKey: "CA_INSTALL_URL_MAC",
    filename: "Install-To-Mac.sh",
    contentType: "text/x-shellscript; charset=utf-8",
    label: "macOS CA 安装脚本"
  },
  "/source/ca-install/root-ca.crt": {
    envKey: "CA_CERT_URL",
    filename: "SMY-Root-CA.crt",
    contentType: "application/x-x509-ca-cert",
    label: "SMY 根证书文件"
  }
} as const satisfies Record<string, SourceFile>;

export type SourceRoute = keyof typeof sourceFiles;

export function getToolPages(origin: string): ToolPage[] {
  const linuxInitUrl = `${origin}/source/linux-init/init.sh`;
  const caLinuxUrl = `${origin}/source/ca-install/linux.sh`;
  const caWindowsUrl = `${origin}/source/ca-install/windows.ps1`;
  const caMacUrl = `${origin}/source/ca-install/mac.sh`;
  const caCertUrl = `${origin}/source/ca-install/root-ca.crt`;

  return [
    {
      slug: "linux-init",
      route: "/tools/linux-init",
      title: "linux-init",
      kicker: "VPS 初始化",
      description: "面向 Debian、Ubuntu、OpenWrt、Alpine 及兼容 Linux 服务器的初始化快捷命令。",
      accent: "emerald",
      commands: [
        {
          id: "linux-menu",
          title: "交互式菜单",
          description: "打开完整初始化菜单，由脚本内菜单继续选择具体操作。",
          platform: "Linux",
          language: "bash",
          badges: ["root"],
          template: `curl -fsSL ${linuxInitUrl} -o /tmp/smy-init.sh && sudo bash /tmp/smy-init.sh`
        },
        {
          id: "linux-ca",
          title: "安装 SMY 根证书",
          description: "将 SMY Root Certification Authority 导入系统信任库。",
          platform: "Linux",
          language: "bash",
          badges: ["root"],
          template: `curl -fsSL ${linuxInitUrl} -o /tmp/smy-init.sh && sudo bash /tmp/smy-init.sh ca`
        },
        {
          id: "linux-sshport",
          title: "设置 SSH 端口",
          description: "将 SSH 端口修改为 54422，并重启 SSH 服务。",
          platform: "Linux",
          language: "bash",
          badges: ["root", "SSH"],
          template: `curl -fsSL ${linuxInitUrl} -o /tmp/smy-init.sh && sudo bash /tmp/smy-init.sh sshport`
        },
        {
          id: "linux-root",
          title: "配置 root 登录",
          description: "设置 root 密码，并写入脚本内置的 SSH 公钥。",
          platform: "Linux",
          language: "bash",
          badges: ["root", "本地输入"],
          inputs: [
            {
              id: "rootPassword",
              label: "root 密码",
              placeholder: "请输入 root 密码",
              type: "password",
              quote: "posix"
            }
          ],
          template: `curl -fsSL ${linuxInitUrl} -o /tmp/smy-init.sh && sudo bash /tmp/smy-init.sh root {{rootPassword}}`
        },
        {
          id: "linux-nezha",
          title: "安装 Nezha Agent",
          description: "使用你在本地输入的客户端密钥安装 Nezha Agent。",
          platform: "Linux",
          language: "bash",
          badges: ["root", "本地输入"],
          inputs: [
            {
              id: "nezhaSecret",
              label: "Nezha 客户端密钥",
              placeholder: "请输入客户端密钥",
              type: "password",
              quote: "posix"
            }
          ],
          template: `curl -fsSL ${linuxInitUrl} -o /tmp/smy-init.sh && sudo bash /tmp/smy-init.sh nezha {{nezhaSecret}}`
        },
        {
          id: "linux-caddy",
          title: "安装 Caddy",
          description: "安装 Caddy 并启动服务。",
          platform: "Linux",
          language: "bash",
          badges: ["root"],
          template: `curl -fsSL ${linuxInitUrl} -o /tmp/smy-init.sh && sudo bash /tmp/smy-init.sh caddy`
        }
      ]
    },
    {
      slug: "ca-install",
      route: "/tools/ca-install",
      title: "ca-install",
      kicker: "根证书安装",
      description: "在 Linux、Windows 和 macOS 上安装 SMY Root Certification Authority。",
      accent: "sky",
      commands: [
        {
          id: "ca-linux",
          title: "Linux 安装",
          description: "将证书安装到 Linux 系统信任库。",
          platform: "Linux",
          language: "bash",
          badges: ["root"],
          template: `curl -fsSL ${caLinuxUrl} -o /tmp/smy-ca-install.sh && sudo bash /tmp/smy-ca-install.sh`
        },
        {
          id: "ca-windows",
          title: "Windows 安装",
          description: "使用一行 PowerShell 命令安装到系统信任库，并自动请求管理员权限。",
          platform: "Windows",
          language: "powershell",
          badges: ["管理员"],
          template: `$SmyCaInstallUrl="${caWindowsUrl}"; irm $SmyCaInstallUrl | iex`
        },
        {
          id: "ca-macos",
          title: "macOS 安装",
          description: "下载安装脚本，并安装到系统钥匙串。",
          platform: "macOS",
          language: "bash",
          badges: ["sudo"],
          template: `tmpdir="$(mktemp -d)" && curl -fsSL ${caMacUrl} -o "$tmpdir/Install-To-Mac.sh" && sudo bash "$tmpdir/Install-To-Mac.sh"`
        },
        {
          id: "ca-cert",
          title: "证书文件",
          description: "直接下载 SMY Root CA 证书文件。",
          platform: "通用",
          language: "bash",
          badges: ["crt"],
          template: `curl -fsSL ${caCertUrl} -o SMY-Root-CA.crt`
        }
      ]
    }
  ];
}
