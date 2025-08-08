当然可以！下面是一个详细、结构清晰、易读易用的 README 模板，专门针对你这个带并发控制和信号捕获的 GitLab 多组多仓库克隆脚本：

---

# GitLab 多组多仓库并发克隆脚本

> 这是一个用于递归拉取 GitLab 上所有组及子组中所有项目的 Bash 脚本，支持自建 GitLab 实例，具备组和仓库两级并发控制，支持信号捕获，方便安全地中断运行。

---

## 功能特点

* 递归遍历所有组和子组，拉取所有仓库
* 同时支持拉取个人空间（非 Group）的项目
* 支持指定 GitLab URL，兼容官方及自建 GitLab 实例
* 支持命令行参数灵活配置：

  * GitLab 私有 Token
  * 克隆目录
  * 组并发数限制
  * 仓库并发数限制
* 并发克隆，提高拉取效率
* 支持 Ctrl+C 安全中断，自动终止所有后台克隆任务
* 进度实时展示，方便掌握拉取状态
* 日志记录所有克隆仓库地址与失败项目

---

## 环境依赖

* Bash（推荐 4.x 以上，脚本也兼容部分老版本，但建议升级）
* curl
* jq
* git
* md5sum（Linux 标准工具，macOS 可用 `md5` 替代，脚本中可自行调整）

---

## 使用方法

### 1. 下载脚本并赋予执行权限

```bash
curl -O https://your-repo-url/your-script.sh
chmod +x your-script.sh
```

### 2. 运行脚本

```bash
./your-script.sh -t <your_gitlab_token> [-u <gitlab_url>] [-d <clone_dir>] [-g <max_group_concurrent>] [-r <max_repo_concurrent>]
```

#### 参数说明

| 参数                          | 说明                                   | 默认值                  | 是否必填 |
| --------------------------- | ------------------------------------ | -------------------- | ---- |
| `-t <token>`                | GitLab 私有访问令牌（Personal Access Token） | 无                    | 是    |
| `-u <gitlab_url>`           | GitLab 服务器地址，支持自建 GitLab             | `https://gitlab.com` | 否    |
| `-d <clone_dir>`            | 仓库克隆的本地根目录                           | `./gitlab_repos`     | 否    |
| `-g <max_group_concurrent>` | 同时并发克隆组数量                            | `3`                  | 否    |
| `-r <max_repo_concurrent>`  | 每个组内同时并发克隆仓库数量                       | `5`                  | 否    |
| `-h`                        | 显示帮助信息                               | -                    | 否    |

### 3. 示例

```bash
./pull_all_repos.sh -t glpat_xxx12345 -u https://gitlab.example.com -d /tmp/gitlab_clone -g 2 -r 4
```

---

## 脚本工作流程简述

1. 获取所有顶层组，递归遍历组和子组
2. 拉取每个组下的所有项目（仓库）
3. 另外拉取用户个人空间（非组）项目
4. 使用信号捕获保证 `Ctrl+C` 能优雅终止所有正在执行的克隆任务
5. 所有克隆仓库的 SSH 地址会被记录在 `repos.log`
6. 克隆失败的仓库会记录在 `repos_fail.log`
7. 显示实时进度：已完成仓库数 / 总仓库数 / 当前活跃克隆任务数

---

## 注意事项

* 请确保 GitLab Token 具备读取组和项目权限。
* 建议提前配置好 SSH 免密登录，避免每个仓库克隆时频繁输入密码。
* 并发数请根据本机性能和网络状况合理配置，避免过多任务导致拥堵。
* macOS 用户如遇 `md5sum` 不可用，可将脚本中 `md5sum` 替换为 `md5 -q`。

---

## 常见问题

### Q: Ctrl+C 后进程没有完全退出怎么办？

* 脚本设计成进程组组长，捕获 SIGINT/SIGTERM 后会终止所有子进程，确保不会有残留后台任务。
* 请确认脚本以 Bash 运行，且当前 shell 允许发送信号。
* 若仍有问题，请尝试手动 `ps` 查看残留 clone 进程，杀死它们。

### Q: 日志文件在哪？

* 克隆仓库 SSH 地址会写入 `${CLONE_BASE_DIR}/repos.log`
* 克隆失败的仓库 SSH 地址会写入 `${CLONE_BASE_DIR}/repos_fail.log`

---

## 版本历史

* v1.0 初始版本，支持递归组与子组克隆
* v1.1 增加并发限制与信号捕获支持
* v1.2 增加自定义 GitLab URL，完善日志与进度显示

---

## 贡献

欢迎提交 issue 和 PR，欢迎加星 ⭐️ ！

---

## 许可证

MIT License

---
