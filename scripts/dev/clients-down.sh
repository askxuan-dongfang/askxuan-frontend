#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID_DIR="$ROOT_DIR/logs/clients/pids"

stop_pid_file() {
  local pid_file="$1"
  local name
  name="$(basename "$pid_file" .pid)"

  if [ ! -f "$pid_file" ]; then
    return
  fi

  local pid
  pid="$(cat "$pid_file")"
  if kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    echo "OK: 已停止 ${name}，pid=${pid}"
  else
    echo "OK: $name 进程已不存在，清理 pid 文件"
  fi
  rm -f "$pid_file"
}

if [ -d "$PID_DIR" ]; then
  for pid_file in "$PID_DIR"/*.pid; do
    [ -e "$pid_file" ] || continue
    stop_pid_file "$pid_file"
  done
else
  echo "OK: 没有找到客户端 pid 目录"
fi

echo "OK: 客户端 Web dev server 停止完成"
