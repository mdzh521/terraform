#!/usr/bin/env bash
set -Eeuo pipefail

REDIS_EXPORTER_VERSION="${REDIS_EXPORTER_VERSION:-1.89.0}"
REDIS_ADDR="${REDIS_ADDR:-redis://127.0.0.1:6379}"
REDIS_USER="${REDIS_USER:-}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
REDIS_ALIAS="${REDIS_ALIAS:-$(hostname -s)}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0:9121}"
ASK_PASSWORD=false
PASSWORD_STDIN=false

SERVICE_USER="redis_exporter"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/redis_exporter"
ENV_FILE="${CONFIG_DIR}/redis_exporter.env"
SERVICE_FILE="/etc/systemd/system/redis_exporter.service"
DOWNLOAD_ROOT="https://github.com/oliver006/redis_exporter/releases/download"
TEMPORARY_DIR=""

log() {
  printf '[redis-exporter] %s\n' "$*"
}

fatal() {
  printf '[redis-exporter] ERROR: %s\n' "$*" >&2
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
  sudo ./redis-exporter-install.sh [参数]

参数：
  --version VERSION          redis_exporter 版本，默认 1.89.0
  --redis-addr URI           Redis 地址，默认 redis://127.0.0.1:6379
  --redis-user USER          Redis 6+ ACL 用户名
  --redis-alias NAME         Prometheus 中显示的实例名称，默认当前主机名
  --listen-address ADDRESS   Exporter 监听地址，默认 0.0.0.0:9121
  --ask-password             安全交互输入 Redis 密码
  --password-stdin           从标准输入读取一行 Redis 密码
  -h, --help                 显示帮助

主备节点使用同一脚本，分别在两台 Redis 主机执行。Exporter 会从 INFO
replication 自动识别 master/slave，并附加 instance_role 指标标签。

示例：
  # 无密码 Redis
  sudo ./redis-exporter-install.sh --redis-alias redis-master-01

  # requirepass
  sudo ./redis-exporter-install.sh --redis-alias redis-master-01 --ask-password

  # Redis 6+ ACL
  sudo ./redis-exporter-install.sh \
    --redis-user exporter \
    --redis-alias redis-replica-01 \
    --ask-password

  # 自动化输入密码
  printf '%s\n' "$REDIS_PASSWORD" | sudo ./redis-exporter-install.sh --password-stdin
EOF
}

while (($#)); do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fatal "--version 缺少值"
      REDIS_EXPORTER_VERSION="$2"; shift 2 ;;
    --redis-addr)
      [[ $# -ge 2 ]] || fatal "--redis-addr 缺少值"
      REDIS_ADDR="$2"; shift 2 ;;
    --redis-user)
      [[ $# -ge 2 ]] || fatal "--redis-user 缺少值"
      REDIS_USER="$2"; shift 2 ;;
    --redis-alias)
      [[ $# -ge 2 ]] || fatal "--redis-alias 缺少值"
      REDIS_ALIAS="$2"; shift 2 ;;
    --listen-address)
      [[ $# -ge 2 ]] || fatal "--listen-address 缺少值"
      LISTEN_ADDRESS="$2"; shift 2 ;;
    --ask-password)
      ASK_PASSWORD=true; shift ;;
    --password-stdin)
      PASSWORD_STDIN=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fatal "未知参数：$1" ;;
  esac
done

[[ "$EUID" -eq 0 ]] || fatal "请使用 root 或 sudo 执行"
[[ "$(uname -s)" == "Linux" ]] || fatal "仅支持 Linux"
command -v systemctl >/dev/null 2>&1 || fatal "系统未使用 systemd"
[[ "$ASK_PASSWORD" != true || "$PASSWORD_STDIN" != true ]] || fatal "密码输入方式只能选择一种"

REDIS_EXPORTER_VERSION="${REDIS_EXPORTER_VERSION#v}"
[[ "$REDIS_EXPORTER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fatal "版本格式无效"
[[ "$REDIS_ADDR" =~ ^rediss?://[^[:space:]]+$ ]] || fatal "Redis 地址必须以 redis:// 或 rediss:// 开头"
[[ "$LISTEN_ADDRESS" =~ ^[A-Za-z0-9._:-]+:[0-9]{1,5}$ ]] || fatal "Exporter 监听地址格式无效"
[[ "$REDIS_ALIAS" != *[[:space:]]* ]] || fatal "Redis alias 不能包含空格"

if [[ "$ASK_PASSWORD" == true ]]; then
  read -r -s -p 'Redis password: ' REDIS_PASSWORD
  printf '\n'
elif [[ "$PASSWORD_STDIN" == true ]]; then
  IFS= read -r REDIS_PASSWORD
fi

install_dependencies() {
  local missing=() command_name
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
    armv7l|armv6l) printf 'arm' ;;
    ppc64le) printf 'ppc64le' ;;
    s390x) printf 's390x' ;;
    riscv64) printf 'riscv64' ;;
    *) fatal "不支持的 CPU 架构：$(uname -m)" ;;
  esac
}

create_service_user() {
  id "$SERVICE_USER" >/dev/null 2>&1 && return
  local nologin_shell=/usr/sbin/nologin
  [[ -x "$nologin_shell" ]] || nologin_shell=/sbin/nologin
  useradd --system --no-create-home --shell "$nologin_shell" "$SERVICE_USER"
}

download_and_install() {
  local arch="$1"
  local archive="redis_exporter-v${REDIS_EXPORTER_VERSION}.linux-${arch}.tar.gz"
  local release_url="${DOWNLOAD_ROOT}/v${REDIS_EXPORTER_VERSION}"
  local expected_checksum actual_checksum binary

  TEMPORARY_DIR="$(mktemp -d /tmp/redis-exporter-install.XXXXXX)"
  log "下载 redis_exporter ${REDIS_EXPORTER_VERSION} (${arch})"
  curl --fail --location --silent --show-error --retry 3 \
    --output "${TEMPORARY_DIR}/${archive}" "${release_url}/${archive}"
  curl --fail --location --silent --show-error --retry 3 \
    --output "${TEMPORARY_DIR}/sha256sums.txt" "${release_url}/sha256sums.txt"

  expected_checksum="$(awk -v file="$archive" '$2 == file || $2 == "*" file {print $1; exit}' "${TEMPORARY_DIR}/sha256sums.txt")"
  [[ -n "$expected_checksum" ]] || fatal "官方校验文件中找不到 ${archive}"
  actual_checksum="$(sha256sum "${TEMPORARY_DIR}/${archive}" | awk '{print $1}')"
  [[ "$actual_checksum" == "$expected_checksum" ]] || fatal "SHA256 校验失败"
  log "SHA256 校验通过"

  tar -xzf "${TEMPORARY_DIR}/${archive}" -C "$TEMPORARY_DIR"
  binary="$(find "$TEMPORARY_DIR" -type f -name redis_exporter -print -quit)"
  [[ -n "$binary" ]] || fatal "压缩包内找不到 redis_exporter"
  systemctl stop redis_exporter.service 2>/dev/null || true
  install -o root -g root -m 0755 "$binary" "${INSTALL_DIR}/redis_exporter"
}

systemd_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//\`/\\\`}"
  printf '"%s"' "$value"
}

write_configuration() {
  install -d -o root -g "$SERVICE_USER" -m 0750 "$CONFIG_DIR"
  {
    printf 'REDIS_ADDR=%s\n' "$(systemd_quote "$REDIS_ADDR")"
    printf 'REDIS_USER=%s\n' "$(systemd_quote "$REDIS_USER")"
    printf 'REDIS_PASSWORD=%s\n' "$(systemd_quote "$REDIS_PASSWORD")"
    printf 'REDIS_ALIAS=%s\n' "$(systemd_quote "$REDIS_ALIAS")"
    printf 'REDIS_EXPORTER_WEB_LISTEN_ADDRESS=%s\n' "$(systemd_quote "$LISTEN_ADDRESS")"
    printf 'REDIS_EXPORTER_APPEND_INSTANCE_ROLE_LABEL=true\n'
    printf 'REDIS_EXPORTER_INCL_SYSTEM_METRICS=true\n'
    printf 'REDIS_EXPORTER_LOG_FORMAT=txt\n'
  } >"$ENV_FILE"
  chown root:"$SERVICE_USER" "$ENV_FILE"
  chmod 0640 "$ENV_FILE"

  cat >"$SERVICE_FILE" <<'EOF'
[Unit]
Description=Prometheus Redis Exporter
Documentation=https://github.com/oliver006/redis_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=redis_exporter
Group=redis_exporter
EnvironmentFile=/etc/redis_exporter/redis_exporter.env
ExecStart=/usr/local/bin/redis_exporter
Restart=on-failure
RestartSec=5s
TimeoutStopSec=20s

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
  systemctl enable --now redis_exporter.service
  sleep 2
  systemctl is-active --quiet redis_exporter.service || {
    journalctl -u redis_exporter.service --no-pager -n 80 >&2
    fatal "redis_exporter 启动失败"
  }

  listen_host="${LISTEN_ADDRESS%:*}"
  port="${LISTEN_ADDRESS##*:}"
  case "$listen_host" in
    0.0.0.0|'') health_host=127.0.0.1 ;;
    ::|'[::]') health_host='[::1]' ;;
    *) health_host="$listen_host" ;;
  esac

  metrics_file="$(mktemp /tmp/redis-exporter-metrics.XXXXXX)"
  curl --fail --silent --show-error --max-time 10 \
    --output "$metrics_file" "http://${health_host}:${port}/metrics" \
    || fatal "无法访问 redis_exporter metrics 接口"
  grep -Eq '^redis_up(\{[^}]*\})? 1$' "$metrics_file" || {
    journalctl -u redis_exporter.service --no-pager -n 80 >&2
    fatal "Exporter 已启动，但无法连接 Redis；请检查地址、ACL 和密码"
  }
  rm -f -- "$metrics_file"

  log "安装完成：$("${INSTALL_DIR}/redis_exporter" --version 2>&1 | head -n 1)"
  log "Redis：${REDIS_ADDR}，别名：${REDIS_ALIAS}"
  log "指标：http://${LISTEN_ADDRESS}/metrics"
  log "主备角色由 redis_instance_info / instance_role 指标自动识别。"
  log "请只允许 Prometheus Server 访问 TCP ${port}，不要向公网开放。"
}

install_dependencies
architecture="$(detect_architecture)"
create_service_user
download_and_install "$architecture"
write_configuration
verify_installation
