#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$ROOT_DIR/logs/clients"
PID_DIR="$LOG_DIR/pids"
BACKEND_HEALTH_URL="${BACKEND_HEALTH_URL:-http://127.0.0.1:8080/api/v1/health}"

mkdir -p "$PID_DIR"

port_in_use() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

kill_port() {
  local port="$1"
  local pids
  pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  if [ -n "$pids" ]; then
    echo "$pids" | xargs kill >/dev/null 2>&1 || true
    sleep 1
  fi
}

url_ready() {
  local port="$1"
  curl -fsS "http://127.0.0.1:${port}/login" >/dev/null 2>&1 ||
    curl -fsS "http://localhost:${port}/login" >/dev/null 2>&1
}

pid_running() {
  local pid_file="$1"
  [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" >/dev/null 2>&1
}

wait_web() {
  local key="$1"
  local port="$2"
  local pid_file="$3"
  local log_file="$4"
  local attempts="${CLIENTS_WAIT_ATTEMPTS:-30}"

  for _ in $(seq 1 "$attempts"); do
    if url_ready "$port"; then
      echo "OK: ${key} 页面已就绪，端口 ${port}"
      return
    fi
    if ! pid_running "$pid_file"; then
      echo "错误：${key} 启动进程已退出，日志如下：" >&2
      tail -n 80 "$log_file" >&2 || true
      rm -f "$pid_file"
      exit 1
    fi
    sleep 1
  done

  echo "错误：${key} 在 ${attempts}s 内未就绪，日志如下：" >&2
  tail -n 80 "$log_file" >&2 || true
  exit 1
}

start_web() {
  local key="$1"
  local app_dir="$2"
  local port="$3"
  local pid_file="$PID_DIR/$key.pid"
  local log_file="$LOG_DIR/$key.log"

  if pid_running "$pid_file"; then
    echo "OK: ${key} 已在运行，pid=$(cat "$pid_file")，端口 ${port}"
    return
  fi

  if port_in_use "$port"; then
    if url_ready "$port"; then
      echo "OK: ${key} 已有可用服务监听端口 ${port}"
      return
    fi
    if [ "${CLIENTS_FORCE_PORTS:-0}" = "1" ]; then
      echo "提示：端口 ${port} 被不可访问的进程占用，正在释放后重试"
      kill_port "$port"
    fi
  fi

  if port_in_use "$port"; then
    echo "错误：端口 ${port} 已被占用，无法启动 ${key}。" >&2
    echo "      如确认这是坏的旧 dev server，可执行：CLIENTS_FORCE_PORTS=1 make clients-up" >&2
    exit 1
  fi

  (
    cd "$ROOT_DIR/apps/$app_dir"
    nohup npm run dev -- --host 127.0.0.1 --port "$port" >"$log_file" 2>&1 &
    echo $! >"$pid_file"
  )
  echo "OK: 已启动 ${key}，端口 ${port}，日志 ${log_file}"
  wait_web "$key" "$port" "$pid_file" "$log_file"
}

if curl -fsS "$BACKEND_HEALTH_URL" >/dev/null 2>&1; then
  echo "OK: 后端网关可用：$BACKEND_HEALTH_URL"
else
  echo "提示：后端网关暂不可用：$BACKEND_HEALTH_URL"
  echo "      需要接口联调时，请先在 askXuan-backend 执行：make stack-up"
fi

start_web "web-temple-admin" "web-temple-admin" "5173"
start_web "web-shop-admin" "web-shop-admin" "5174"
start_web "web-platform-admin" "web-platform-admin" "5175"

echo
echo "Web 管理端："
echo "  寺院管理台：  http://127.0.0.1:5173/login"
echo "  商城管理台：  http://127.0.0.1:5174/login"
echo "  平台管理台：  http://127.0.0.1:5175/login"
echo
echo "iOS 原生客户端："
echo "  C 端：        $ROOT_DIR/apps/ios-customer/DongFangApp.xcworkspace"
echo "  大师端：      $ROOT_DIR/apps/ios-master/MasterApp.xcworkspace"

if [ "${OPEN_IOS:-0}" = "1" ]; then
  open "$ROOT_DIR/apps/ios-customer/DongFangApp.xcworkspace"
  open "$ROOT_DIR/apps/ios-master/MasterApp.xcworkspace"
  echo "OK: 已打开两个 iOS workspace"
else
  echo "  自动打开 Xcode：OPEN_IOS=1 make clients-up"
fi
