# Railway 3x-ui

在 Railway 上通过 Docker 一键部署 [3x-ui](https://github.com/MHSanaei/3x-ui)（Xray 代理管理面板），支持 VLESS / VMess / Trojan / Shadowsocks / Hysteria2 等协议。

## 为什么是这个仓库

3x-ui 官方提供 Docker 镜像，本仓库只做一层轻量封装，针对 Railway / 低配容器（512MB）做了优化：

- 关闭了镜像内置的 fail2ban（省内存，面板的 IP 限制功能不受影响）
- 明确的端口声明，Railway 一键识别

## 一键部署（Railway）

1. 打开 [Railway](https://railway.com) → 登录（GitHub 账号）
2. **Projects → New Project → Deploy from GitHub repo**
3. 选择本仓库（`railway-3x-ui`），Railway 会自动识别 Dockerfile 构建
4. 等待构建完成（约 2-5 分钟），看到绿色 **Online** 即成功
5. **Settings → Networking → Generate Domain**，端口填 **54321**（面板端口）
6. 浏览器打开生成的域名，进入面板登录页

## 首次登录（重要！）

- 默认账号：**admin**
- 默认密码：**admin**
- ⚠️ **登录后第一件事：面板设置里立即修改用户名和密码**
- 3x-ui 面板有账号密码保护，但默认凭据是公开的，不改等于裸奔

> 忘了密码？在容器终端执行 `x-ui` 打开管理菜单，选择重置密码。

## 创建第一个节点（VLESS + WebSocket）

Railway 的域名自带 HTTPS 证书（`.up.railway.app`），所以代理节点建议这样配：

1. 面板 → **入站列表 → 添加入站**
2. 协议：`VLESS`，备注随意，端口填 **8080**
3. 传输：`ws`（WebSocket），路径随意写个，如 `/hello`
4. **TLS 不勾选**（TLS 由 Railway 的 HTTPS 域名层终止，不需要容器内证书）
5. 保存 → 点击"重启 Xray"生效

客户端连接地址：

```
地址：你的域名（xxx.up.railway.app）
端口：443（走 HTTPS）
TLS：开启
SNI：你的域名
传输：ws，路径 /hello
UUID：面板里生成的客户端 UUID
```

> 为什么不走 8080？客户端用 `wss://` 连接时，TLS 握手由 Railway 反向代理完成，实际落到容器时已经是 HTTP，所以 xray 内部监听明文 ws 即可。

## 可选：面板和代理共用一个端口（fallback 玩法）

如果 Railway 只给了你一个可用域名端口，可以让**一个端口同时服务面板和代理**：

1. 建 inbound：端口 **8080**，VLESS + ws，路径 `/hello`
2. 入站编辑 → **Fallback（回落）** → 填写 `127.0.0.1:54321`（面板地址）
3. 保存生效后：
   - 浏览器访问 `https://你的域名/` → 非 VLESS 流量自动回落 → 显示面板登录页
   - 代理客户端连 `wss://你的域名/hello` → 正常代理
4. 此时 Generate Domain 端口填 8080 即可，54321 不需要公网暴露（更安全）

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `XUI_ENABLE_FAIL2BAN` | `false`（本仓库） | 镜像内置 fail2ban，低内存建议关闭 |
| `XUI_WEB_BASE_PATH` | `/` | 面板访问路径，可设为 `/abc` 增加隐蔽性（需同时设置 `XUI_INIT_WEB_BASE_PATH` 才会在首次启动生效，或装好后在面板设置里改） |

## 数据持久化

- 面板数据库在 `/etc/x-ui`（容器卷，Railway 默认磁盘）
- 所有节点配置、流量统计、用户数据都存这里，容器重建后不丢
- 建议定期在面板里做**备份**（面板设置 → 备份），下载 json 存档

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
