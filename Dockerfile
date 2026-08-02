# Railway 上跑的 3x-ui 容器
FROM ghcr.io/mhsanaei/3x-ui:latest

# 低内存优化：官方镜像默认内置 fail2ban（IP 限制功能用），
# 在 512MB 内存的免费/低配容器上建议关闭以省内存。
# 面板自带的"客户端 IP 限制"功能仍可正常使用。
ENV XUI_ENABLE_FAIL2BAN=false

# 面板端口（x-ui 默认 54321）
# Railway 部署后：Settings -> Networking -> Generate Domain -> 端口填 54321
EXPOSE 54321

# 代理 inbound 默认端口（面板里建节点时建议用它）
EXPOSE 8080

# 面板数据库/证书/配置都在这里，保持容器内路径即可
VOLUME /etc/x-ui
