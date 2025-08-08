# GitLab 全量递归克隆与更新脚本

## 📌 功能特性

* **递归拉取**：支持从 GitLab 拉取所有 Group、子 Group 及个人空间项目。
* **全量克隆**：克隆时拉取完整历史（非浅克隆）+ 全分支（`--mirror` 效果）。
* **自动更新**：已存在仓库会自动执行：

  * `git fetch --all --prune`
  * 强制同步默认分支（`reset --hard`）
  * 自动创建并跟踪远程分支
* **并发控制**：支持设置 Group 并发 & 仓库并发，提升效率并避免网络阻塞。
* **日志记录**：

  * 所有成功克隆仓库的 SSH 地址会写入 `repos.log`
  * 失败仓库写入 `repos_fail.log`
* **优雅退出**：支持 `Ctrl+C`，捕获信号后会清理后台任务，安全退出。
* **进度显示**：实时输出“已完成 / 总数 / 正在运行中”的进度信息。

---

## ⚙️ 环境依赖

脚本依赖以下工具：

* **bash**
* **git**
* **curl**
* **jq**

安装 `jq`（示例，Debian/Ubuntu）：

```bash
sudo apt update && sudo apt install jq -y
```

---

## 🚀 使用方法

### 1. 获取 GitLab API Token

1. 登录 GitLab
2. 进入 **Settings → Access Tokens / Personal Access Tokens**
3. 创建 Token，需勾选 `api` 权限
4. 复制 Token（非常重要）

---

### 2. 运行脚本

```bash
chmod +x gitlab_clone_all.sh

./gitlab_clone_all.sh \
  -t <your_token> \
  -u https://gitlab.example.com \
  -d /path/to/clone_dir \
  -g 3 \
  -r 5
```

---

### 3. 参数说明

| 参数   | 说明                           | 默认值                  | 必填 |
| ---- | ---------------------------- | -------------------- | -- |
| `-t` | GitLab Personal Access Token | 无                    | ✅  |
| `-u` | GitLab 服务器 URL               | `https://gitlab.com` | ❌  |
| `-d` | 仓库存放目录                       | `./gitlab_repos`     | ❌  |
| `-g` | 最大 Group 并发数                 | `3`                  | ❌  |
| `-r` | 最大仓库并发数                      | `5`                  | ❌  |
| `-h` | 显示帮助信息                       | 无                    | ❌  |

---

## 📂 日志文件

* `repos.log`：所有成功克隆/更新的仓库 SSH 地址
* `repos_fail.log`：克隆失败的仓库 SSH 地址（可再次运行脚本重试）

---

## 💡 示例

```bash
./gitlab_clone_all.sh \
  -t glpat-xxxxxxxxxxxxxxxxxx \
  -u https://gitlab.company.com \
  -d ~/gitlab_backup \
  -g 4 \
  -r 8
```

输出示例：

```
🚀 开始递归拉取所有 Group 及子组的项目
📁 处理组: devops/tools (ID: 123)
⬇️ 克隆仓库: devops/tools/repo1
🔄 更新仓库: devops/tools/repo2
进度: 已完成 15 / 68，运行中 5
✅ 全部项目拉取完成！
```

---

## ⚠️ 注意事项

1. 脚本会**强制同步**仓库默认分支（本地修改会丢失）。
2. 需确保本机已配置 GitLab SSH Key 并可正常 `git clone`。
3. 若仓库较多，请根据网络与磁盘性能合理调整 `-g` 与 `-r`。
4. `Ctrl+C` 可安全退出，已完成的仓库不会重复克隆。

---

## 📜 许可证

MIT License
