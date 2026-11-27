[English](README.en.md) | [العربية](README.ar.md) | [فارسی](README.fa.md) | **中文** | [Español](README.es.md) | [Русский](README.md) | [Türkçe](README.tr.md)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="media/logo-dark.svg">
    <img src="media/logo-light.svg" alt="X-Fleet" width="420">
  </picture>
</p>

# X-Fleet — 安装

这里存放 X-Fleet 的正式发布版本（**Releases** 标签页）：Linux 程序（amd64、arm64）、
安装脚本 `install.sh` 和校验和 `SHA256SUMS`。下面介绍如何安装。

X-Fleet 是一个同时在多台服务器上管理 Xray VPN 的面板。一条命令即可安装，
无需 Docker，也无需单独的数据库。

> 安装程序和面板界面提供**英文**和**俄文**。下文中的菜单和按钮名称使用面板中的英文名称。

## 准备条件

- 一台运行 **Ubuntu 22.04+** 或 **Debian 12+** 的服务器（VPS），amd64 或 arm64 处理器。
- 可以通过 SSH 以 **root** 登录。
- 最好有自己的域名（例如 `panel.example.com`），并将 A 记录指向服务器 IP。
  没有域名也可以：面板会使用类似 `1-2-3-4.sslip.io` 的免费域名。
- 在服务商处开放端口（如果服务商控制台有自己的防火墙）：

| 端口 | 用途 |
|---|---|
| 80 | Let's Encrypt 验证域名以签发证书 |
| 随机（安装程序会显示） | 登录面板 |
| 8444 | 节点连接面板 |
| 2096 | 客户端的订阅链接 |
| 443 和 8443 | VPN 本身（如果这台服务器也提供 VPN） |

如果服务器启用了 `ufw`，安装程序会自动在其中开放所需端口。

## 1. 安装面板

以 root 登录服务器并执行：

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh)
```

将打开安装向导，按步骤提问。不确定时直接按 Enter，即选择默认选项。

1. **语言：** 俄文或英文。
2. **系统检查和软件包。** 安装程序会建议更新系统（`apt upgrade`）。
   如果服务器上已经运行着其他服务，可以拒绝。
3. **地址和 HTTPS。** 输入你的域名，或选择无域名选项（sslip.io）。
   面板会自动获取 Let's Encrypt 证书。
4. **面板设置。** 端口、秘密路径和登录名随机生成，密码自动创建。
5. **在本服务器上部署 VPN。** 可以直接把这台服务器作为第一个节点：
   - 443 端口上的 VLESS Reality XHTTP（主连接）；
   - 8443 端口上的 TCP + Vision（备用）。

   这里还会选择伪装网站并创建第一个用户。
6. **启动和检查。** 服务会启动，服务器重启后也会自动运行。

最后屏幕上会显示**面板地址、登录名和密码**，以及第一个用户的订阅二维码。
登录信息保存在 `/root/x-fleet-admin.txt` 文件中。再次查看：

```bash
cat /root/x-fleet-admin.txt
```

### 无交互安装

加上 `--yes`，所有选项都使用默认值。其他参数可以直接指定：

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh) --yes --domain panel.example.com
```

| 参数 | 作用 |
|---|---|
| `--lang ru\|en` | 安装程序和菜单的语言 |
| `--domain panel.example.com` | 面板和订阅使用的自有域名 |
| `--https le\|ip\|self\|none` | HTTPS：自有域名 / 无域名（sslip.io）/ 自签名 / 不用 HTTPS（仅通过 SSH 隧道） |
| `--cert 文件 --key 文件` | 使用自己的证书代替 Let's Encrypt |
| `--email you@example.com` | 接收 Let's Encrypt 通知的邮箱 |
| `--port 31234` | 面板端口（默认随机） |
| `--login 名称` | 管理员登录名（默认随机） |
| `--connections rec\|xhttp\|vision\|none` | 本服务器上的 VPN：两种连接 / 仅 XHTTP / 仅 Vision / 不安装 |
| `--mask neighbor\|self\|<网站>` | Reality 伪装：同网段的邻居网站 / 服务器上自己的网站 / 指定网站 |
| `--user 名称` | 第一个用户（默认 `user`） |
| `--name 名称` | 客户端应用中显示的服务器名称，使用拉丁字母 |
| `--upgrade` / `--no-upgrade` | 是否更新系统 |
| `--bbr` / `--no-bbr` | 是否启用 TCP 加速（BBR），默认启用 |
| `--version v0.7.1` | 安装指定版本 |

完整参数说明：

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh) --help
```

## 2. 首次登录

1. 在浏览器中打开安装程序显示的地址，例如
   `https://panel.example.com:31234/AbCdEf123/`。
   地址是保密的：没有正确的路径，面板无法打开，扫描器也找不到它。
2. 使用 `/root/x-fleet-admin.txt` 中的登录名和密码登录。
3. 建议立即：
   - **Settings → Security**：修改密码并启用两步验证登录；
   - **Settings → Notifications**：连接 Telegram，及时获知故障；
   - **Settings → System**：启用定时备份。

## 3. 添加节点（其他 VPN 服务器）

**节点**（node）是客户端连接 VPN 所经过的服务器。面板远程管理节点。
每个新节点都需要一条**安装命令**。命令由面板生成，GitHub 上没有：
命令中包含你的面板地址和一次性密钥。

### 第 1 步：在面板中获取命令

1. 在浏览器中打开面板并登录。
2. 在左侧菜单中选择 **Nodes**。
3. 点击蓝色的 **Add node** 按钮（右上角）。
4. 填写表单：

   | 字段 | 填写内容 |
   |---|---|
   | **Name** | 任意清楚的拉丁字母名称，例如 `amsterdam-1` |
   | **Address (IP or domain)** | 新服务器的 IP，例如 `203.0.113.10`。客户端会在订阅中看到它 |
   | **Node domain (for camouflage)** | 可以留空。如果有 A 记录指向此服务器 IP 的域名，请填写，例如 `nl1.example.com` |
   | **Country** 和 **City** | 可以留空：面板会根据 IP 自动识别。客户端会看到例如 `🇳🇱 Netherlands, Amsterdam` |
   | **Add inbounds from templates right away** | 保持勾选：节点上的连接会自动创建 |

5. 点击 **Create**。
6. 会打开 **Install node** 窗口，里面有一条很长的命令，以 `curl -fsSL https://…/node.sh | bash -s -- …` 开头。
   点击命令右侧的**复制**图标。

命令大致如下（你的地址、令牌和指纹会不同）：

```text
curl -fsSL https://panel.example.com:2096/install/Ab12Cd/node.sh | bash -s -- --panel panel.example.com:8444 --token 7f3a… --pin 9c1e…
```

> **重要：** 命令只能使用一次，有效期 **15 分钟**（到期时间显示在窗口中）。
> 没来得及或关掉了窗口？打开 **Nodes** → 点击该节点 → **New install token**，
> 就会出现新的命令。

**另一种方法：在面板服务器上。** 通过 SSH 登录安装了面板的服务器并执行：

```bash
x-fleet node-cmd
```

程序会询问节点名称、IP 和域名（按 Enter 表示没有域名），然后输出现成的命令。有效期 30 分钟。

### 第 2 步：在新服务器上执行命令

1. 以 root 通过 SSH 登录**新服务器**（即未来的节点，而不是面板服务器）：
   ```bash
   ssh root@203.0.113.10
   ```
2. 粘贴复制的命令（在终端中：右键，或 Ctrl+Shift+V / Cmd+V），然后按 Enter。
3. 等待 1–2 分钟。节点会自动：
   - 从你的面板下载程序并校验校验和；
   - 通过安全通道连接面板；
   - 下载并启动 Xray。

### 第 3 步：检查

回到面板 → **Nodes**。几秒钟后新节点会显示绿色状态。
模板中的连接已经创建好。节点会出现在其所属分组用户的订阅中
（**Squads** 部分）。订阅链接无需更改：应用刷新订阅时会自动获取新服务器。

### 如果没有成功

- **"install token expired"（安装令牌已过期）：** 获取新命令：节点页面 → **New install token**。
- **节点无法连接面板：** 面板服务器上必须开放 **8444** 端口
  （以及 **2096**，程序从这里下载）。检查服务商的防火墙。
- **新服务器上已经运行着其他 VPN**（例如 3x-ui），443/8443 端口被占用：安装程序会停止
  并显示占用端口的程序。这样旧的 VPN 不会被破坏。请释放端口，或在面板中为该节点设置
  其他端口。
- **节点就是面板所在的服务器：** 无需安装任何东西，面板安装向导一开始就会提供这一选项（"在本服务器上部署 VPN"步骤）。

## 4. 用户和订阅

**Users** → **New user**。每个用户都有一个订阅链接，把它添加到应用中即可。
订阅页面会显示二维码和各应用的按钮。

### 客户端应用

| 应用 | 如何添加订阅 |
|---|---|
| **NOX**（推荐，Android 7+） | [下载 NOX.apk](https://github.com/richdodcom-pixel/nox-updates/releases/latest/download/NOX.apk)。订阅页面上的 **NOX** 按钮会打开应用并添加订阅 |
| Happ、Hiddify、INCY、v2RayTun、Streisand、v2rayNG、Clash Verge / FlClash | 订阅页面上对应应用的按钮（或把订阅链接粘贴到应用中） |
| sing-box 及其他 Clash / Mihomo 客户端 | 粘贴订阅链接——面板会自动提供合适的格式 |

## 在服务器上管理：`x-fleet` 命令

在服务器上输入 `x-fleet` 即可打开菜单。快捷命令：

| 命令 | 作用 |
|---|---|
| `x-fleet url` | 显示面板地址和登录名 |
| `x-fleet password` | 设置新的管理员密码 |
| `x-fleet 2fa off` | 关闭两步验证（手机丢失时） |
| `x-fleet status` | 服务状态 |
| `x-fleet restart` | 重启服务 |
| `x-fleet log` | 日志 |
| `x-fleet port 31234` | 修改面板端口 |
| `x-fleet path` | 新的面板秘密路径 |
| `x-fleet https` | 面板证书 |
| `x-fleet update` | 更新 X-Fleet |
| `x-fleet backup` | 立即备份 |
| `x-fleet check` | 检查服务器 |
| `x-fleet link 名称` | 用户的订阅链接和二维码 |
| `x-fleet node-cmd` | 新节点的安装命令 |

## 更新

- **面板：** **Settings → System → Panel update**。或在服务器上执行：`x-fleet update`。
  旧版本会保留，以便回滚。
- **节点：** **Settings → Cores**：一次性更新所有节点上的 Xray 和代理程序。
  也可以在节点页面逐个更新。**Settings → System → Update all servers** 一键更新所有节点。

## 更改面板地址或域名

**Settings → Network & certificates**。在这里修改端口、秘密路径和证书
（自有域名、sslip.io 或自签名）。

- 面板会在切换**之前**先为新域名获取证书。如果 Let's Encrypt 拒绝，什么都不会改变，
  屏幕上会显示原因。
- 修改后，请在 **10 分钟内**用新地址打开面板并登录。否则之前的设置会自动恢复，
  不会失去访问权限。

## 故障排查

- **无法获取证书：**
  - 检查域名的 A 记录是否指向服务器 IP，Cloudflare 中是否为灰色云朵（仅 DNS）；
  - 检查服务商是否开放了 80 端口；
  - Let's Encrypt 每个域名每周最多签发 5 个证书。如果频繁重装，请等待，
    或暂时选择无域名选项（sslip.io）。
- **忘记地址或密码：** 登录服务器并执行 `x-fleet url` 或 `x-fleet password`。
- **综合检查：** `x-fleet check`。

## 卸载

```bash
x-fleet uninstall
```

该命令会停止服务，删除程序、设置和数据。备份保留在 `/var/lib/x-fleet/backups` 中。

---

## 从旧版本（nodepanel）升级

v0.5.0 之前程序名为 `nodepanel`。通过按钮更新时，所有内容会自动迁移到新名称：

| 以前 | 现在 |
|---|---|
| `/usr/local/bin/nodepanel` | `/usr/local/bin/x-fleet`（旧名称保留为链接） |
| 服务 `nodepanel-panel`、`nodepanel-node` | `x-fleet-panel`、`x-fleet-node` |
| `/etc/nodepanel`、`/var/lib/nodepanel`、`/var/lib/nodepanel-node` | `/etc/x-fleet`、`/var/lib/x-fleet`、`/var/lib/x-fleet-node` |
| `/root/nodepanel-admin.txt` | `/root/x-fleet-admin.txt` |

如果新服务没有启动，一切都会恢复原样。手动重试：`x-fleet migrate`；
迁移日志：`journalctl -u x-fleet-migrate`。

## 支持项目

X-Fleet 是免费的，由一名开发者利用业余时间开发。如果面板对你有用，
可以用任意金额支持它的开发。这是自愿的：所有功能都无需付费即可使用。

| 币种 | 网络 | 地址 |
|---|---|---|
| USDT | **TRON (TRC20)** | `TYWjc2oNwm32wcQUX5cDjQ2vWCCLuS1vkH` |
| USDT, TON | **TON** | `UQB6Fryf-lEQXMGQlOIdHu5QTk_lcOgeKL0m424k92hbiWhw` |

> ⚠️ 只能通过所列网络转账——从其他网络转入的币会丢失。
> 这些地址的二维码在面板中：菜单中的 **Support** 项。

谢谢！💙
