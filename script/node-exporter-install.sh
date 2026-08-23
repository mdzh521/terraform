#!/usr/bin/env bash
set -Eeuo pipefail

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.12.1}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9100}"
TEXTFILE_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
ENV_FILE="/etc/default/node_exporter"
SERVICE_USER="node_exporter"
DOWNLOAD_ROOT="https://github.com/prometheus/node_exporter/releases/download"
TEMPORARY_DIR=""

log() {
  printf '[node-exporter] %s\n' "$*"
}

fatal() {
  printf '[node-exporter] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMPORARY_DIR" && -d "$TEMPORARY_DIR" ]]; then
    rm -rf -- "$TEMPORARY_DIR"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
用法：
  sudo ./node-exporter-install.sh [参数]

参数：
  --version VERSION          安装版本，默认 1.12.1
  --listen-address ADDRESS   监听地址，默认 0.0.0.0:9100
  --textfile-dir DIR         textfile collector 目录
  -h, --help                 显示帮助

也可以使用同名环境变量：
  NODE_EXPORTER_VERSION=1.12.1
  LISTEN_ADDRESS=127.0.0.1:9100
  TEXTFILE_DIR=/var/lib/node_exporter/textfile_collector

示例：
  sudo ./node-exporter-install.sh
  sudo ./node-exporter-install.sh --listen-address 10.0.1.20:9100
EOF
}

while (($#)); do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fatal "--version 缺少值"
      NODE_EXPORTER_VERSION="$2"
      shift 2
      ;;
    --listen-address)
      [[ $# -ge 2 ]] || fatal "--listen-address 缺少值"
      LISTEN_ADDRESS="$2"
      shift 2
      ;;
    --textfile-dir)
      [[ $# -ge 2 ]] || fatal "--textfile-dir 缺少值"
      TEXTFILE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fatal "未知参数：$1"
      ;;
  esac
done

[[ "${EUID}" -eq 0 ]] || fatal "请使用 root 或 sudo 执行"
[[ "$(uname -s)" == "Linux" ]] || fatal "仅支持 Linux"
command -v systemctl >/dev/null 2>&1 || fatal "系统未使用 systemd"

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION#v}"
[[ "$NODE_EXPORTER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fatal "版本格式无效：${NODE_EXPORTER_VERSION}"
[[ "$LISTEN_ADDRESS" =~ ^[A-Za-z0-9._:-]+:[0-9]{1,5}$ ]] || fatal "监听地址格式无效：${LISTEN_ADDRESS}"
[[ "$TEXTFILE_DIR" == /* && "$TEXTFILE_DIR" != *[[:space:]]* ]] || fatal "textfile 目录必须是不含空格的绝对路径"

install_dependencies() {
  local missing=()
  local command_name
  for command_name in curl tar sha256sum awk grep install; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done
  ((${#missing[@]} == 0)) && return

  log "安装依赖：${missing[*]}"
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y curl tar coreutils grep gawk
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl tar coreutils grep gawk
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl tar coreutils grep gawk
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install curl tar coreutils grep gawk
  else
    fatal "无法识别包管理器，请先安装：${missing[*]}"
  fi
}

detect_architecture() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    armv7l) printf 'armv7' ;;
    ppc64le) printf 'ppc64le' ;;
    s390x) printf 's390x' ;;
    riscv64) printf 'riscv64' ;;
    *) fatal "不支持的 CPU 架构：$(uname -m)" ;;
  esac
}

create_service_user() {
  if id "$SERVICE_USER" >/dev/null 2>&1; then
    return
  fi

  local nologin_shell="/usr/sbin/nologin"
  [[ -x "$nologin_shell" ]] || nologin_shell="/sbin/nologin"
  useradd --system --no-create-home --shell "$nologin_shell" "$SERVICE_USER"
}

download_and_install() {
  local arch="$1"
  local archive="node_exporter-${NODE_EXPORTER_VERSION}.linux-${arch}.tar.gz"
  local release_url="${DOWNLOAD_ROOT}/v${NODE_EXPORTER_VERSION}"
  local expected_checksum actual_checksum

  TEMPORARY_DIR="$(mktemp -d /tmp/node-exporter-install.XXXXXX)"

  log "下载 node_exporter ${NODE_EXPORTER_VERSION} (${arch})"
  curl --fail --location --silent --show-error --retry 3 \
    --output "${TEMPORARY_DIR}/${archive}" \
    "${release_url}/${archive}"
  curl --fail --location --silent --show-error --retry 3 \
    --output "${TEMPORARY_DIR}/sha256sums.txt" \
    "${release_url}/sha256sums.txt"

  expected_checksum="$(awk -v file="$archive" '$2 == file || $2 == "*" file {print $1; exit}' "${TEMPORARY_DIR}/sha256sums.txt")"
  [[ -n "$expected_checksum" ]] || fatal "官方校验文件中找不到 ${archive}"
  actual_checksum="$(sha256sum "${TEMPORARY_DIR}/${archive}" | awk '{print $1}')"
  [[ "$actual_checksum" == "$expected_checksum" ]] || fatal "SHA256 校验失败"
  log "SHA256 校验通过"

  tar -xzf "${TEMPORARY_DIR}/${archive}" -C "$TEMPORARY_DIR"
  systemctl stop node_exporter.service 2>/dev/null || true
  install -o root -g root -m 0755 \
    "${TEMPORARY_DIR}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${arch}/node_exporter" \
    "${INSTALL_DIR}/node_exporter"
}

write_configuration() {
  install -d -o root -g root -m 0755 "$CONFIG_DIR"
  install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$TEXTFILE_DIR"
  install -d -o root -g root -m 0755 "$(dirname "$ENV_FILE")"

  cat >"$ENV_FILE" <<EOF
# 由 node-exporter-install.sh 管理
NODE_EXPORTER_ARGS=--web.listen-address=${LISTEN_ADDRESS} --collector.textfile.directory=${TEXTFILE_DIR}
EOF
  chmod 0644 "$ENV_FILE"

  cat >"$SERVICE_FILE" <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
EnvironmentFile=/etc/default/node_exporter
ExecStart=/usr/local/bin/node_exporter $NODE_EXPORTER_ARGS
Restart=on-failure
RestartSec=5s
TimeoutStopSec=20s

# systemd 安全加固
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
RestrictSUIDSGID=true
LockPersonality=true
CapabilityBoundingSet=
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
[Install]
WantedBy=multi-user.target
EOF
  chmod 0644 "$SERVICE_FILE"
}

verify_installation() {
  local listen_host port health_host metrics_file
  systemctl daemon-reload
  systemctl enable --now node_exporter.service
  sleep 2
  systemctl is-active --quiet node_exporter.service || {
    journalctl -u node_exporter.service --no-pager -n 80 >&2
    fatal "node_exporter 启动失败"
  }

  listen_host="${LISTEN_ADDRESS%:*}"
  port="${LISTEN_ADDRESS##*:}"
  case "$listen_host" in
    0.0.0.0|'') health_host="127.0.0.1" ;;
    ::|'[::]') health_host="[::1]" ;;
    *) health_host="$listen_host" ;;
  esac

  metrics_file="$(mktemp /tmp/node-exporter-metrics.XXXXXX)"
  curl --fail --silent --show-error --max-time 5 \
    --output "$metrics_file" \
    "http://${health_host}:${port}/metrics" \
    || fatal "服务已启动，但无法访问 metrics 接口"
  grep -q '^node_exporter_build_info' "$metrics_file" \
    || fatal "metrics 接口没有 node_exporter_build_info 指标"
  rm -f -- "$metrics_file"

  log "安装完成：$("${INSTALL_DIR}/node_exporter" --version 2>&1 | head -n 1)"
  log "监听地址：http://${LISTEN_ADDRESS}/metrics"
  log "服务状态：systemctl status node_exporter"
  log "注意：请只允许 Prometheus Server 访问 TCP ${port}，不要向公网开放。"
}

install_dependencies
architecture="$(detect_architecture)"
create_service_user
download_and_install "$architecture"
write_configuration
verify_installation
