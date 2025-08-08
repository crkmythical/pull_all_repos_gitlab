#!/bin/bash

# -t <token> 必填，GitLab API Token
# -u <gitlab_url> GitLab 服务器地址，默认 https://gitlab.com
# -d 指定克隆目录，默认./gitlab_repos
# -g 最大组并发，默认3
# -r 最大仓库克隆并发，默认5
# 已存在仓库自动拉取更新（fetch + reset 强制同步默认分支，且创建并跟踪所有远程分支）
# 克隆时拉取完整历史和所有分支（无浅克隆）
# 并发控制，优雅退出信号处理
# 记录所有克隆仓库SSH URL到日志repos.log
# 失败仓库记录到repos_fail.log

set -e
set -m

# ====== 默认配置 ======
GITLAB_URL="https://gitlab.com"
GITLAB_TOKEN=""
CLONE_BASE_DIR="./gitlab_repos"
MAX_GROUP_CONCURRENT=3
MAX_REPO_CONCURRENT=5

LOG_FILE=""
FAIL_LOG_FILE=""
LOCK_DIR=""
CLONED_COUNT=0
TOTAL_COUNT=0

GROUP_JOBS=()
CHILD_REPO_PIDS=()

usage() {
  cat <<EOF
Usage: $0 -t <gitlab_token> [-u gitlab_url] [-d clone_dir] [-g max_group_concurrent] [-r max_repo_concurrent] [-h]

Options:
  -t   GitLab Personal Access Token (required)
  -u   GitLab server URL (default: https://gitlab.com)
  -d   Clone base directory (default: ./gitlab_repos)
  -g   Max concurrent groups fetching (default: 3)
  -r   Max concurrent repo clones per group (default: 5)
  -h   Show this help and exit

Example:
  $0 -t yourtoken -u https://gitlab.company.com -d /tmp/repos -g 2 -r 4
EOF
  exit 1
}

while getopts "t:u:d:g:r:h" opt; do
  case $opt in
    t) GITLAB_TOKEN="$OPTARG" ;;
    u) GITLAB_URL="$OPTARG" ;;
    d) CLONE_BASE_DIR="$OPTARG" ;;
    g) MAX_GROUP_CONCURRENT="$OPTARG" ;;
    r) MAX_REPO_CONCURRENT="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [ -z "$GITLAB_TOKEN" ]; then
  echo "Error: GitLab token is required"
  usage
fi

LOG_FILE="$CLONE_BASE_DIR/repos.log"
FAIL_LOG_FILE="$CLONE_BASE_DIR/repos_fail.log"
LOCK_DIR="$CLONE_BASE_DIR/lockdir"

mkdir -p "$CLONE_BASE_DIR"
: > "$LOG_FILE"
: > "$FAIL_LOG_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

write_log() {
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.1; done
  echo "$1" >> "$LOG_FILE"
  rmdir "$LOCK_DIR"
}

inc_cloned_count() {
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.05; done
  CLONED_COUNT=$((CLONED_COUNT + 1))
  rmdir "$LOCK_DIR"
}

safe_dir() {
  echo "$1" | tr ' ' '_' | tr -cd '[:alnum:]_.-/'
}

safe_clone() {
  local repo_url="$1"
  local path_ns="$2"

  local safe_path
  safe_path=$(safe_dir "$path_ns")
  local dest_dir="$CLONE_BASE_DIR/$safe_path"
  mkdir -p "$(dirname "$dest_dir")"

  if [ -d "$dest_dir/.git" ]; then
    log "🔄 更新仓库: $path_ns"
    (
      cd "$dest_dir" || return
      git fetch --all --prune

      default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
      [ -z "$default_branch" ] && default_branch="master"

      git checkout "$default_branch" || git checkout -b "$default_branch" "origin/$default_branch"
      git reset --hard "origin/$default_branch"

      # 创建并跟踪所有远程分支
      git branch -r | grep -v '\->' | while read -r remote; do
        branch=${remote#origin/}
        git branch --track "$branch" "$remote" 2>/dev/null || true
      done
    )
    inc_cloned_count
    return 0
  fi

  log "⬇️ 克隆仓库: $path_ns"
  write_log "$repo_url"
  if git clone "$repo_url" "$dest_dir"; then
    inc_cloned_count
    return 0
  else
    log "⚠️ 克隆失败: $path_ns"
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.05; done
    echo "$repo_url" >> "$FAIL_LOG_FILE"
    rmdir "$LOCK_DIR"
    inc_cloned_count
    return 1
  fi
}

run_clone_bg() {
  safe_clone "$1" "$2" &
  CHILD_REPO_PIDS+=($!)
}

LAST_PROGRESS_TIME=0
PROGRESS_INTERVAL=3

show_progress() {
  local now
  now=$(date +%s)
  if (( now - LAST_PROGRESS_TIME >= PROGRESS_INTERVAL )); then
    printf "\r进度: 已完成 %d / %d，运行中 %d\n" "$CLONED_COUNT" "$TOTAL_COUNT" "$(jobs -rp | wc -l | tr -d ' ')"
    LAST_PROGRESS_TIME=$now
  fi
}

trap_cleanup() {
  log "⚠️ 捕获退出信号，终止所有后台任务..."
  kill -- -$$ 2>/dev/null || true
  wait
  log "✅ 所有后台任务已终止，脚本退出。"
  exit 1
}

trap trap_cleanup INT TERM EXIT

clone_with_limit() {
  local ssh_url="$1"
  local path_ns="$2"
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$MAX_REPO_CONCURRENT" ]; do
    sleep 0.8
    show_progress
  done
  run_clone_bg "$ssh_url" "$path_ns"
}

fetch_groups_recursive() {
  local group_id="$1"
  local group_path="$2"

  log "📁 处理组: $group_path (ID: $group_id)"

  local page=1
  while :; do
    local projects_json
    projects_json=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "$GITLAB_URL/api/v4/groups/$group_id/projects?per_page=100&page=$page")

    local proj_count
    proj_count=$(echo "$projects_json" | jq 'length')
    [ "$proj_count" -eq 0 ] && break

    TOTAL_COUNT=$((TOTAL_COUNT + proj_count))

    echo "$projects_json" | jq -c '.[]' | while read -r proj; do
      local ssh_url path_ns
      ssh_url=$(echo "$proj" | jq -r '.ssh_url_to_repo')
      path_ns=$(echo "$proj" | jq -r '.path_with_namespace')

      if [ -n "$ssh_url" ] && [ -n "$path_ns" ]; then
        clone_with_limit "$ssh_url" "$path_ns"
      fi
    done

    wait
    page=$((page+1))
  done

  local sub_page=1
  while :; do
    local subgroups_json
    subgroups_json=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "$GITLAB_URL/api/v4/groups/$group_id/subgroups?per_page=100&page=$sub_page")

    local sub_count
    sub_count=$(echo "$subgroups_json" | jq 'length')
    [ "$sub_count" -eq 0 ] && break

    echo "$subgroups_json" | jq -c '.[]' | while read -r subgroup; do
      local sub_id sub_path
      sub_id=$(echo "$subgroup" | jq -r '.id')
      sub_path=$(echo "$subgroup" | jq -r '.full_path')
      wait_for_group_slot
      fetch_groups_recursive "$sub_id" "$sub_path" &
      GROUP_JOBS+=($!)
    done

    wait
    sub_page=$((sub_page+1))
  done
}

fetch_personal_projects() {
  log "👤 拉取个人空间项目（非Group）"

  local page=1
  while :; do
    local projects_json
    projects_json=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "$GITLAB_URL/api/v4/projects?membership=true&per_page=100&page=$page")

    local proj_count
    proj_count=$(echo "$projects_json" | jq 'length')
    [ "$proj_count" -eq 0 ] && break

    TOTAL_COUNT=$((TOTAL_COUNT + proj_count))

    echo "$projects_json" | jq -c '.[]' | while read -r proj; do
      local ssh_url path_ns
      ssh_url=$(echo "$proj" | jq -r '.ssh_url_to_repo')
      path_ns=$(echo "$proj" | jq -r '.path_with_namespace')

      if [ -n "$ssh_url" ] && [ -n "$path_ns" ]; then
        clone_with_limit "$ssh_url" "$path_ns"
      fi
    done

    wait
    page=$((page+1))
  done
}

wait_for_group_slot() {
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$MAX_GROUP_CONCURRENT" ]; do
    sleep 0.3
    show_progress
  done
}

main() {
  mkdir -p "$CLONE_BASE_DIR"

  log "🚀 开始递归拉取所有 Group 及子组的项目"

  local page=1
  while :; do
    local groups_json
    groups_json=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "$GITLAB_URL/api/v4/groups?per_page=100&page=$page")

    local group_count
    group_count=$(echo "$groups_json" | jq 'length')
    [ "$group_count" -eq 0 ] && break

    echo "$groups_json" | jq -c '.[]' | while read -r group; do
      local gid gpath
      gid=$(echo "$group" | jq -r '.id')
      gpath=$(echo "$group" | jq -r '.full_path')

      wait_for_group_slot
      fetch_groups_recursive "$gid" "$gpath" &
      GROUP_JOBS+=($!)
    done

    wait
    page=$((page+1))
  done

  fetch_personal_projects

  wait
  echo
  log "✅ 全部项目拉取完成！"
}

trap trap_cleanup INT TERM EXIT

main "$@"
