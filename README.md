# Railway 3x-ui

在 Railway 上通过 Docker 一键部署 [3x-ui](https://github.com/MHSanaei/3x-ui)（Xray 代理管理面板），支持 VLESS / VMess / Trojan / Shadowsocks / Hysteria2 等协议。**本仓库为实战验证版本**，所有步骤均已实测通过。

## 特性

- 基于官方镜像 `ghcr.io/mhsanaei/3x-ui:latest`，保持最新
- 关闭镜像内置 fail2ban（省内存，面板自带"客户端 IP 限制"功能不受影响）
- 面板端口固定为 `54321`（官方镜像默认是 2053，此处显式覆盖，避免混淆）
- 支持 Railway 免费额度（512MB 内存可流畅运行，实测面板常驻 ~90MB）
- 支持绑定自己的域名（推荐，见下文）

## 一键部署（Railway）

### 1. 创建项目

1. 打开 [Railway](https://railway.com) → 用 GitHub 账号登录
2. **Projects → New Project → Deploy from GitHub repo**
3. 选择本仓库（`railway-3x-ui`），Railway 自动识别 Dockerfile 构建
   - 仓库设为 **public** 或确保 Railway 的 GitHub App 有访问权限（GitHub → Settings → Applications → Railway → 授权仓库）
4. 等待构建完成（约 2-5 分钟），出现绿色 **Online** 即成功

### 2. 添加数据卷（必须！）

Railway **不支持 Dockerfile 里的 `VOLUME` 指令**（构建会直接报错），需要手动创建：

- **Settings → Volumes → Add Volume** → 挂载路径填 `/etc/x-ui`
- 作用：面板数据库、节点配置、流量统计都存这里，容器重建/升级不丢

### 3. 生成访问域名

- **Settings → Networking → Generate Domain** → 端口填 **54321**（面板端口）
- 浏览器打开生成的域名 → 进入面板登录页

## 首次登录（重要！）

- 默认账号：**admin**
- 默认密码：**admin**
- ⚠️ **登录后第一件事：面板设置里立即修改用户名和密码**
- 3x-ui 面板有账号密码保护，但默认凭据是公开的，不改等于裸奔

> 忘了密码？容器终端（Railway 的 Web Terminal）执行 `x-ui` 打开管理菜单 → 选择重置密码。

## 创建第一个节点（VLESS + WebSocket）

Railway 的域名自带 HTTPS 证书，所以代理节点这样配（**TLS 由 Railway 层终止，容器内无需证书**）：

1. 面板 → **入站列表 → 添加入站**
2. 基础配置：协议 `VLESS`，备注随意，端口填 **8080**
3. 传输标签：传输方式选 **WebSocket**，路径填 `/hello`（随意，记住即可）
4. 安全标签：保持 **无**（不要开 TLS）
5. 创建入站 → 侧边栏 **客户端 → 添加客户端** → 关联入站选刚创建的 → 创建
6. 在客户端列表复制 UUID

> 为什么不走 8080？客户端用 `wss://` 连接时，TLS 握手由 Railway 反向代理完成，实际落到容器时已经是 HTTP，所以 xray 内部监听明文 ws 即可。

## 网络方案（重点）

Railway 有两种暴露端口的方式，**推荐方案二**：

### 方案一：TCP Proxy（简单，但国内经常连不通）

- **Settings → Networking → TCP Proxy** → 端口 8080
- 得到 `xxx.proxy.rlwy.net:端口` 地址
- ⚠️ 实测：该域名是 Railway 独立基础设施（`.proxy.rlwy.net`），**国内网络大概率 SYN 超时被墙**，不推荐

### 方案二：绑定自己的域名（推荐）

前提：有一个域名（如 `example.com`），DNS 托管在 Cloudflare / 阿里云等任意服务商。

1. **Railway → Settings → Networking → Custom Domain** → 输入想用的子域名（如 `x.example.com`）
2. Railway 会给出两条验证记录（类似）：
   - `CNAME x.example.com → 3yvw4omw.up.railway.app`
   - `TXT _railway-verify.x.example.com → railway-verify=xxxxxxxx...`
3. 去你的 DNS 服务商添加这两条记录：
   - CNAME 记录：**必须 DNS-only（不代理/灰色云朵）**，让客户端直连 Railway
   - TXT 记录：DNS-only
4. 回 Railway 点验证 → 通过后 Railway 自动为你的域名签发证书
5. 验证是否生效：

```bash
# 应解析到 Railway IP（不是 Cloudflare 104.x 之类的 IP）
nslookup x.example.com 8.8.8.8

# WS 握手应返回 101 Switching Protocols（这是 xray 在响应，证明链路通了）
curl -i -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://x.example.com/hello
```

> ⚠️ 不要用 Cloudflare 的橙色云朵（代理模式）回源 Railway：Cloudflare 回源时保留你的域名作为 Host，Railway 边缘不识别该 Host，会返回 404 死路。自定义域名必须 DNS-only 直连。

## 客户端配置

### 方式 A：绑定自定义域名后（推荐）

```
协议：VLESS
地址：x.example.com（你的子域名）
端口：443
UUID：面板中复制的 UUID
传输：WebSocket（ws）
路径：/hello
TLS：开启
SNI：x.example.com
```

分享链接：

```
vless://UUID@x.example.com:443?encryption=none&security=tls&type=ws&host=x.example.com&path=%2Fhello#Railway-WS
```

### 方式 B：直接用 Railway 域名

```
协议：VLESS
地址：xxx.up.railway.app
端口：443
UUID：面板中复制的 UUID
传输：WebSocket（ws）
路径：/hello
TLS：开启
SNI：xxx.up.railway.app
```

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `XUI_ENABLE_FAIL2BAN` | `false`（本仓库） | 镜像内置 fail2ban，低内存建议关闭 |
| `XUI_PORT` | `54321`（本仓库） | 面板监听端口，与 README 保持一致 |
| `XUI_WEB_BASE_PATH` | `/` | 面板访问路径，可设为 `/abc` 增加隐蔽性（装好后在面板设置里改） |

## 数据持久化

- 面板数据库在 `/etc/x-ui`，通过 **Railway Volume** 挂载
- 所有节点配置、流量统计、用户数据都存这里，容器重建后不丢
- 换实例（地区迁移）时：新建 Volume 挂载到 `/etc/x-ui`，把旧 Volume 数据拷贝过去即可
- 建议定期在面板里做**备份**（面板设置 → 备份），下载 json 存档

## 常见问题排查

| 症状 | 原因 | 解决 |
|---|---|---|
| 构建报错 `docker VOLUME ... is not supported` | Railway 不支持 Dockerfile VOLUME | 删除该行，改用 Railway 控制台 Volume |
| 部署成功但访问 502 | 域名端口与容器实际监听端口不匹配 | 检查 Networking 的 Target Port 是否等于面板端口（本仓库为 54321） |
| 面板能开但代理连不上 | 代理端口（8080）没有公网入口 | 用方案二绑定域名，或检查 TCP Proxy 是否连通 |
| TCP Proxy 连接超时 | `.proxy.rlwy.net` 被墙/不可达 | 换方案二（自定义域名） |
| 自定义域名 404 | CF 橙色云朵代理导致 Host 不匹配 | 改为 DNS-only，让客户端直连 Railway |
| Xray 日志出现 WebSocket deprecated 警告 | Xray 提示 WS 将被淘汰 | 无害，可继续使用；未来可迁移 XHTTP |

## VPS 上也能用（备用）

```bash
docker run -d --name 3x-ui \
  -p 54321:54321 \
  -p 443:443 \
  -e XUI_ENABLE_FAIL2BAN=false \
  -v xui-data:/etc/x-ui \
  --restart unless-stopped \
  ghcr.io/mhsanaei/3x-ui:latest
```

VPS 场景推荐用原生安装脚本（更省内存）：`bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)`

## 免责声明

本项目仅用于个人学习与合法用途，请遵守当地法律法规。
