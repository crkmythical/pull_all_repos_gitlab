# GitLab 全量仓库递归克隆脚本

本脚本用于递归获取 GitLab 组及子组下所有项目，支持并发克隆和更新已有仓库，支持自建 GitLab 服务器。

## 功能特点

- 支持自建 GitLab 服务器 URL (`-u` 参数)，默认 `https://gitlab.com`
- 支持指定克隆目录，默认 `./gitlab_repos`
- 支持最大组并发和仓库克隆并发控制，避免过载
- 已存在仓库自动更新，强制同步默认分支代码
- 克隆时拉取完整历史和所有远程分支，非浅克隆
- 支持优雅退出信号处理（Ctrl+C）
- 记录所有成功克隆仓库 SSH 地址到 `repos.log`
- 记录克隆失败仓库到 `repos_fail.log`
- 简洁进度输出，显示完成数和并发中仓库数

## 环境依赖

- bash
- git
- curl
- jq（用于解析 GitLab API JSON）

确保以上工具均已安装并在系统 PATH 中。

## 使用说明

### 脚本参数

| 参数         | 说明                                         | 默认值                  | 必填    |
|--------------|----------------------------------------------|-------------------------|---------|
| `-t`         | GitLab Personal Access Token                  | 无                      | 是      |
| `-u`         | GitLab 服务器 URL                             | `https://gitlab.com`    | 否      |
| `-d`         | 克隆仓库的根目录                             | `./gitlab_repos`        | 否      |
| `-g`         | 最大组并发数（组递归拉取时）                 | `3`                     | 否      |
| `-r`         | 最大仓库克隆并发数                           | `5`                     | 否      |
| `-h`         | 显示帮助信息并退出                           |                         | 否      |

### 使用示例

```bash
# 克隆 gitlab.com，默认目录，默认并发
./gitlab_clone_all.sh -t your_token_here

# 克隆自建 GitLab，指定目录和并发
./gitlab_clone_all.sh -t your_token_here -u https://gitlab.company.com -d /data/repos -g 4 -r 8
