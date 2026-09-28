# OpenWrt WAN Pause

用 iPhone 快捷指令远程暂停 OpenWrt 的 WAN 连接，并在一小时后由路由器自动尝试恢复。

这是一个为个人网络切换场景制作的小项目：手机需要使用同一网络账号时，点一下快捷指令让路由器断开 WAN；路由器仍保持开机，计时结束后自行重新连接。当前实现以 OpenWrt 的 `wan` 接口为目标，不修改校园网的认证系统。

## 工作流程

```text
iPhone 快捷指令 ── POST「OFF」──> ntfy.sh
                                  │
                                  ▼
OpenWrt 监听脚本 ── 收到指令 ──> 记录一小时后的恢复时间 ──> ifdown wan
                                                           │
一小时后：路由器本地 cron ── 每分钟检查 ──> ifup wan（直到 WAN 显示已连接）
```

路由器主动连接 ntfy.sh，无需把 LuCI 管理页面开放到公网。WAN 断开后，恢复计时和 `ifup wan` 都在路由器本地运行，不依赖手机或 ntfy.sh 继续在线。

## 功能与边界

- 手机远程发送 `OFF`，路由器断开 WAN。
- 收到 `OFF` 时开始计时；约一小时后，路由器在下一次 cron 检查时尝试恢复 WAN。
- 到期后若 WAN 仍显示断开，每分钟再次尝试 `ifup wan`；WAN 显示已连接后结束重试。
- 手机提前退出校园网不会使路由器提前恢复。需要提前恢复时，可连接路由器局域网，在 LuCI 中启动 WAN，或执行 `ifup wan`。
- 检查依据是 OpenWrt 报告的 WAN 接口状态；它无法判断认证页面是否仍阻止上网。
- 如果路由器重启，存放在 `/tmp` 的计时记录会消失；WAN 是否随开机恢复取决于路由器原有的网络配置。

## 适用环境

本项目在小米 Redmi AC2100、OpenWrt 21.02-SNAPSHOT、PPPoE WAN 上配置和检查。其他设备、OpenWrt 版本及 WAN 类型尚未验证。路由器需要 `curl`、`jsonfilter`、`cron`、`procd` 和可用的 HTTPS 访问；如果你的接口不叫 `wan`，需相应修改脚本。

## 安装概览

> 下列命令在你自己的路由器上执行。安装前请先阅读脚本，并保留原有的 crontab 内容。

1. 将 [`router/`](router/) 中的两个 Shell 脚本复制到路由器的 `/root/`，将 `campus-off.init` 复制到 `/etc/init.d/campus-off`。
2. 在路由器上生成仅供自己使用的 ntfy 主题，并保存到 `/etc/campus-off.topic`：

   ```sh
   umask 077
   head -c 32 /dev/urandom | hexdump -v -e '1/1 "%02x"' > /etc/campus-off.topic
   ```

3. 添加本地恢复任务（只添加一次，不要覆盖已有定时任务）：

   ```sh
   mkdir -p /etc/crontabs
   grep -Fqx '* * * * * /bin/sh /root/campus-off-recover.sh' /etc/crontabs/root 2>/dev/null || \
     printf '%s\n' '* * * * * /bin/sh /root/campus-off-recover.sh' >> /etc/crontabs/root
   chmod 600 /etc/crontabs/root
   ```

4. 检查语法、设置权限并启用服务：

   ```sh
   sh -n /root/campus-off-listener.sh
   sh -n /root/campus-off-recover.sh
   chmod 700 /root/campus-off-listener.sh /root/campus-off-recover.sh /etc/init.d/campus-off
   /etc/init.d/cron enable
   /etc/init.d/cron restart
   /etc/init.d/campus-off enable
   /etc/init.d/campus-off start
   ```

5. 按照 [iPhone 快捷指令设置](docs/iphone-shortcut.md)创建发送 `OFF` 的快捷指令。手机和路由器必须使用**同一个**私密主题。

服务状态可用 `/etc/init.d/campus-off status` 和 `/etc/init.d/cron status` 查看。

## 验证情况

- 手机发送 `OFF` 后，路由器断开 WAN，手机能够使用校园网：已实测。
- 路由器定时任务能处理到期标记，且不影响当前已连接的 WAN：已实测。
- 真正断开 WAN 后等待完整一小时，再验证自动恢复：**尚未完整实测**。

## 安全说明

ntfy.sh 的公开主题默认不要求登录。这里使用随机、难猜的主题名作为控制入口；**知道主题名的人可以发送断网指令**。不要把真实主题、管理员密码、校园网凭据、包含真实主题的快捷指令导出文件或截图提交到仓库。仓库只包含读取 `/etc/campus-off.topic` 的脚本，主题由每位使用者自行生成。[ntfy 官方说明](https://docs.ntfy.sh/publish/)

## 参与改进

欢迎通过 Issue 讨论兼容性、恢复策略和安全性，也欢迎提交 Pull Request。报告问题时请说明设备型号、OpenWrt 版本和 WAN 类型；粘贴日志前请删除账号、密码与 ntfy 主题。项目需求与实际使用验证来自维护者，脚本和文档在 AI 协助下整理。

## 许可证

本项目采用 [MIT License](LICENSE)。欢迎学习、修改和分享；分发时请保留许可证与版权声明。
