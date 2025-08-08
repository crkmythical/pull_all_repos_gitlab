当然！这里是配合上面脚本的 **README**，方便你快速上手和使用：

---

# GitLab 仓库批量递归克隆脚本

## 简介

此脚本用于递归拉取 GitLab 上的所有 Group（包含子组）以及个人空间下的所有项目，支持并发克隆，自动跳过已存在仓库，并实时显示进度和日志。

---

## 功能特点

* 支持递归拉取 Group 及子组中的所有仓库
* 支持拉取个人空间（非 Group）项目
* 支持最大并发数限制（组级并发和仓库级并发）
* 自动跳过已存在仓库
* 支持命令行参数配置 Token、目录、并发数
* 实时显示克隆进度
* 支持 Ctrl+C 安全退出，自动终止所有子进程
* 日志记录所有克隆过的仓库地址和失败仓库列表
* 兼容 Bash 3+（无 flock，使用目录锁防止写冲突）

---

## 环境依赖

* `bash` 3 及以上版本
* `curl`
* `jq` （处理 JSON，建议安装最新版）
* `git`
* `md5sum`（大部分 Linux 系统默认自带）

---

## 使用方法

1. **准备：**

   克隆脚本到本地，或者直接创建 `gitlab_clone.sh`，将脚本内容复制进去。

2. **赋予执行权限：**

   ```bash
   chmod +x gitlab_clone.sh
   ```

3. **执行脚本：**

   ```bash
   ./gitlab_clone.sh -t <your_gitlab_personal_access_token> [-d <clone_directory>] [-g <max_group_concurrent>] [-r <max_repo_concurrent>]
   ```

   参数说明：

   * `-t` GitLab 个人访问令牌（必填）
   * `-d` 克隆目标目录（默认 `./gitlab_repos`）
   * `-g` 最大组并发数（默认 3）
   * `-r` 最大仓库并发数（默认 5）

   示例：

   ```bash
   ./gitlab_clone.sh -t glpat-xxxxxxx -d /data/gitlab_repos -g 4 -r 10
   ```

---

## 目录结构说明

* 所有仓库会被克隆到你指定的目录内，路径会根据仓库的 `path_with_namespace` 自动生成，路径会做简化防止过长。
* `repos.log`：记录所有成功开始克隆的仓库的 Git 地址
* `repos_fail.log`：记录克隆失败的仓库 Git 地址，方便后续重试
* 运行过程中，控制台会实时显示当前克隆进度（已完成 / 总数 / 运行中任务数）

---

## 终止脚本

* 按 `Ctrl+C` 可以安全终止脚本，同时会自动结束所有子进程，避免孤儿进程。

---

## 注意事项

* Token 权限应至少包含：`api` 或 `read_api`，并且有权限访问对应的 Group 和项目。
* 网络环境良好，避免中途网络抖动导致克隆失败。
* 日志文件在指定克隆目录下，可随时查看。

---

## 常见问题

* **jq 命令找不到？**

  安装 jq：

  ```bash
  sudo apt install jq       # Debian/Ubuntu
  brew install jq           # macOS (Homebrew)
  ```

* **git clone 失败？**

  请检查 Token 是否有权限、网络是否通畅、GitLab 地址是否正确。

