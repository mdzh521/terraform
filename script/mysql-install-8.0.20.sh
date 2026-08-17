#!/usr/bin/env bash
set -Eeuo pipefail

# MySQL 8.0.20 二进制包安装脚本。
#
# 使用示例：
#   bash mysql-install-8.0.20.sh
#   ROOT_PASSWORD='change-me' APP_DB=toastio APP_USER=appuser APP_PASSWORD='change-me' bash mysql-install-8.0.20.sh
#
# 注意：
#   - 这个脚本适合新机器首次安装。
#   - 如果数据目录已经初始化，默认会拒绝继续，避免误覆盖数据库。
#   - MySQL 8.0 的账号来源通配符是 "%"，不是 "*"。

################################################################################
# 用户配置区
################################################################################

# root 初始密码。全新初始化时，脚本会从 error.log 读取 MySQL 临时密码，
# 然后把 root@localhost 修改成这里配置的密码。
ROOT_PASSWORD="${ROOT_PASSWORD:-CAI@2026Mysql}"

# 初始业务库名。全新安装时脚本会自动创建这个数据库。
APP_DB="${APP_DB:-toastio}"

# 初始业务账号。脚本会给这个账号授予 APP_DB 的全部权限。
# APP_HOSTS 里配置了几个来源，就会分别创建几条账号授权。
APP_USER="${APP_USER:-appuser}"
APP_PASSWORD="${APP_PASSWORD:-wqe2f22f24fda34}"

# MySQL 账号来源列表，多个来源用英文逗号分隔。
# 支持这些写法：
#   - %                               允许任意来源
#   - 10.100.64.10                    精确 IP
#   - 10.100.64.%                     MySQL 通配符
#   - 10.100.64.0/22                  CIDR，脚本会自动转换成 MySQL 支持的格式
#   - 10.100.64.0/255.255.252.0       MySQL IPv4 netmask 写法
APP_HOSTS="${APP_HOSTS:-${APP_HOST:-10.100.64.0/22,10.100.68.0/22}}"

# MySQL 二进制版本和服务监听配置。
MYSQL_VERSION="${MYSQL_VERSION:-8.0.20}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
BIND_ADDRESS="${BIND_ADDRESS:-0.0.0.0}"
DATA_DIR="${DATA_DIR:-/data/mysql}"
MYSQL_HOME="${MYSQL_HOME:-/usr/local/mysql}"

# 必须在初始化数据目录前确定。初始化后不要随意修改；
# 如果后续要改，通常需要重建或迁移数据。
LOWER_CASE_TABLE_NAMES="${LOWER_CASE_TABLE_NAMES:-1}"

# MySQL 最大连接数。这个值不会自动计算，因为合理值取决于业务连接池配置。
# 默认值：1000。
MAX_CONNECTIONS="${MAX_CONNECTIONS:-1000}"

# 内存临时表上限，单位 MB。这是单个会话的上限；
# 如果和很高的 MAX_CONNECTIONS 一起调得过大，可能耗尽内存。
TMP_TABLE_SIZE_MB="${TMP_TABLE_SIZE_MB:-256}"
MAX_HEAP_TABLE_SIZE_MB="${MAX_HEAP_TABLE_SIZE_MB:-256}"

# binlog 保留时间，单位秒。默认 604800 = 7 天。
BINLOG_EXPIRE_SECONDS="${BINLOG_EXPIRE_SECONDS:-604800}"

# 安装路径和 Linux 用户/用户组。
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/usr/local/src}"
INSTALL_PARENT="${INSTALL_PARENT:-/usr/local}"
MYSQL_USER="${MYSQL_USER:-mysql}"
MYSQL_GROUP="${MYSQL_GROUP:-mysql}"
SERVER_ID="${SERVER_ID:-1}"

# 安全开关：
#   ALLOW_EXISTING_DATADIR=1 表示允许脚本处理已有数据目录周边的服务和配置文件，
#   但仍然会跳过数据库初始化。
#   CONFIGURE_EXISTING_DATADIR=1 表示已有数据目录时，也尝试用 ROOT_PASSWORD
#   连接 MySQL 并执行 root 密码、业务库、业务账号相关 SQL。
ALLOW_EXISTING_DATADIR="${ALLOW_EXISTING_DATADIR:-0}"
CONFIGURE_EXISTING_DATADIR="${CONFIGURE_EXISTING_DATADIR:-0}"

# 可选性能参数：
#   INNODB_BUFFER_POOL_SIZE_MB 这里故意不赋默认值。
#   如果不设置，脚本会自动按系统总内存的 60% 计算。
#   如果这台机器还跑其它吃内存的服务，建议显式设置这个值。

################################################################################
# 派生路径
################################################################################

MYSQL_PACKAGE="${MYSQL_PACKAGE:-mysql-${MYSQL_VERSION}-linux-glibc2.12-x86_64}"
MYSQL_ARCHIVE="${MYSQL_ARCHIVE:-${MYSQL_PACKAGE}.tar.xz}"
MYSQL_URL="${MYSQL_URL:-https://dev.mysql.com/get/Downloads/MySQL-8.0/${MYSQL_ARCHIVE}}"
INSTALL_DIR="${INSTALL_DIR:-${INSTALL_PARENT}/${MYSQL_PACKAGE}}"
SOCKET_FILE="${SOCKET_FILE:-${DATA_DIR}/mysql.sock}"
PID_FILE="${PID_FILE:-${DATA_DIR}/mysql.pid}"
ERROR_LOG="${ERROR_LOG:-${DATA_DIR}/error.log}"

DB_INITIALIZED=0

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Run this script as root."
  fi
}

install_dependencies() {
  log "Installing OS dependencies when a supported package manager is available"

  if command -v dnf >/dev/null 2>&1; then
    local packages=(libaio numactl-libs libxcrypt-compat ncurses-compat-libs xz tar)
    if ! command -v wget >/dev/null 2>&1; then
      packages+=(wget)
    fi
    dnf install -y "${packages[@]}" || {
      packages=(libaio numactl-libs libxcrypt-compat xz tar)
      if ! command -v wget >/dev/null 2>&1; then
        packages+=(wget)
      fi
      dnf install -y "${packages[@]}"
    }
  elif command -v yum >/dev/null 2>&1; then
    local packages=(libaio numactl-libs ncurses-compat-libs xz tar)
    if ! command -v wget >/dev/null 2>&1; then
      packages+=(wget)
    fi
    yum install -y "${packages[@]}" || {
      packages=(libaio numactl-libs xz tar)
      if ! command -v wget >/dev/null 2>&1; then
        packages+=(wget)
      fi
      yum install -y "${packages[@]}"
    }
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update
    local packages=(libaio1 libnuma1 libncurses5 xz-utils tar)
    if ! command -v curl >/dev/null 2>&1; then
      packages+=(curl)
    fi
    if ! command -v wget >/dev/null 2>&1; then
      packages+=(wget)
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
  else
    log "No supported package manager found; assuming dependencies are already installed"
  fi
}

create_mysql_user() {
  log "Ensuring ${MYSQL_GROUP}/${MYSQL_USER} exists"

  if ! getent group "${MYSQL_GROUP}" >/dev/null; then
    groupadd "${MYSQL_GROUP}"
  fi

  if ! id -u "${MYSQL_USER}" >/dev/null 2>&1; then
    useradd -g "${MYSQL_GROUP}" -s /sbin/nologin -M "${MYSQL_USER}"
  fi
}

download_mysql() {
  mkdir -p "${DOWNLOAD_DIR}"

  if [ -f "${DOWNLOAD_DIR}/${MYSQL_ARCHIVE}" ]; then
    log "Using existing ${DOWNLOAD_DIR}/${MYSQL_ARCHIVE}"
    return
  fi

  log "Downloading ${MYSQL_URL}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL "${MYSQL_URL}" -o "${DOWNLOAD_DIR}/${MYSQL_ARCHIVE}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "${DOWNLOAD_DIR}/${MYSQL_ARCHIVE}" "${MYSQL_URL}"
  else
    die "Neither curl nor wget is available."
  fi
}

install_mysql_files() {
  if [ -d "${INSTALL_DIR}" ]; then
    log "Install directory already exists: ${INSTALL_DIR}"
  else
    log "Extracting ${MYSQL_ARCHIVE} to ${INSTALL_PARENT}"
    tar -xf "${DOWNLOAD_DIR}/${MYSQL_ARCHIVE}" -C "${INSTALL_PARENT}"
  fi

  if [ -L "${MYSQL_HOME}" ] || [ ! -e "${MYSQL_HOME}" ]; then
    ln -sfn "${INSTALL_DIR}" "${MYSQL_HOME}"
  else
    die "${MYSQL_HOME} exists and is not a symlink. Move it first or set MYSQL_HOME to another path."
  fi

  chown -R "${MYSQL_USER}:${MYSQL_GROUP}" "${INSTALL_DIR}"
}

data_dir_has_only_retry_safe_files() {
  local non_safe_entry

  non_safe_entry="$(
    find "${DATA_DIR}" -mindepth 1 -maxdepth 1 \
      ! -name "$(basename "${ERROR_LOG}")" \
      ! -name "slow_query_log.log" \
      ! -name "mysql.sock" \
      ! -name "mysql.pid" \
      -print -quit
  )"

  [ -z "${non_safe_entry}" ]
}

remove_retry_safe_files() {
  # 这些文件可能是上一次初始化失败留下的；MySQL --initialize 要求数据目录为空。
  rm -f \
    "${ERROR_LOG}" \
    "${DATA_DIR}/slow_query_log.log" \
    "${SOCKET_FILE}" \
    "${PID_FILE}"
}

prepare_directories() {
  mkdir -p "${DATA_DIR}"

  if [ -d "${DATA_DIR}/mysql" ]; then
    DB_INITIALIZED=1
    if [ "${ALLOW_EXISTING_DATADIR}" != "1" ]; then
      die "${DATA_DIR} already looks initialized. Set ALLOW_EXISTING_DATADIR=1 if you intentionally want to manage it."
    fi
  elif find "${DATA_DIR}" -mindepth 1 -maxdepth 1 | grep -q .; then
    if data_dir_has_only_retry_safe_files; then
      log "${DATA_DIR} only contains retry-safe log/socket/pid files; continuing initialization"
      remove_retry_safe_files
      DB_INITIALIZED=0
    else
      die "${DATA_DIR} is not empty. Move existing files away before initializing MySQL."
    fi
  else
    DB_INITIALIZED=0
  fi

  if [ "${DB_INITIALIZED}" = "1" ]; then
    touch "${ERROR_LOG}"
  fi
  chown -R "${MYSQL_USER}:${MYSQL_GROUP}" "${DATA_DIR}"
  chmod 750 "${DATA_DIR}"
}

memory_mb() {
  awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo
}

innodb_buffer_pool_mb() {
  if [ -n "${INNODB_BUFFER_POOL_SIZE_MB:-}" ]; then
    printf '%s\n' "${INNODB_BUFFER_POOL_SIZE_MB}"
    return
  fi

  local total_mb
  total_mb="$(memory_mb)"
  local bp_mb=$((total_mb * 60 / 100))

  if [ "${bp_mb}" -lt 512 ]; then
    bp_mb=512
  fi

  printf '%s\n' "${bp_mb}"
}

innodb_buffer_pool_instances() {
  local bp_mb="$1"
  local instances=1

  if [ "${bp_mb}" -ge 1024 ]; then
    instances=$((bp_mb / 1024))
  fi

  if [ "${instances}" -gt 8 ]; then
    instances=8
  fi

  printf '%s\n' "${instances}"
}

backup_file() {
  local file="$1"

  if [ -f "${file}" ]; then
    cp -a "${file}" "${file}.$(date '+%Y%m%d%H%M%S').bak"
  fi
}

write_my_cnf() {
  local bp_mb
  bp_mb="$(innodb_buffer_pool_mb)"
  local bp_instances
  bp_instances="$(innodb_buffer_pool_instances "${bp_mb}")"

  log "Writing /etc/my.cnf with innodb_buffer_pool_size=${bp_mb}M, innodb_buffer_pool_instances=${bp_instances}"
  backup_file /etc/my.cnf

  cat >/etc/my.cnf <<EOF
[client]
port = ${MYSQL_PORT}
socket = ${SOCKET_FILE}
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4

[mysqld]
server-id = ${SERVER_ID}
port = ${MYSQL_PORT}
bind-address = ${BIND_ADDRESS}
socket = ${SOCKET_FILE}
pid-file = ${PID_FILE}
basedir = ${MYSQL_HOME}
datadir = ${DATA_DIR}
user = ${MYSQL_USER}

log-error = ${ERROR_LOG}
lower_case_table_names = ${LOWER_CASE_TABLE_NAMES}
default_authentication_plugin = mysql_native_password
character_set_server = utf8mb4
collation_server = utf8mb4_bin
explicit_defaults_for_timestamp = ON
event_scheduler = ON
skip-name-resolve
local_infile = 0
symbolic-links = 0
log_bin_trust_function_creators = 1
performance_schema = ON
sql_mode = NO_ENGINE_SUBSTITUTION

log-bin = mysql-bin
sync_binlog = 1
binlog_format = ROW
binlog_expire_logs_seconds = ${BINLOG_EXPIRE_SECONDS}

back_log = 512
max_connections = ${MAX_CONNECTIONS}
max_user_connections = 0
max_connect_errors = 100000
max_allowed_packet = 256M
thread_stack = 256K
thread_cache_size = 256
table_open_cache = 4096
table_definition_cache = 4096
open_files_limit = 65535
interactive_timeout = 28800
wait_timeout = 28800
net_buffer_length = 16K

sort_buffer_size = 4M
read_buffer_size = 2M
read_rnd_buffer_size = 4M
join_buffer_size = 4M
tmp_table_size = ${TMP_TABLE_SIZE_MB}M
max_heap_table_size = ${MAX_HEAP_TABLE_SIZE_MB}M

key_buffer_size = 32M
myisam_sort_buffer_size = 64M
bulk_insert_buffer_size = 32M

slow_query_log = ON
slow_query_log_file = ${DATA_DIR}/slow_query_log.log
long_query_time = 1
log_error_verbosity = 2

innodb_buffer_pool_size = ${bp_mb}M
innodb_buffer_pool_instances = ${bp_instances}
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_read_io_threads = 8
innodb_write_io_threads = 8
innodb_open_files = 4096
innodb_purge_threads = 4
innodb_log_buffer_size = 64M
innodb_log_file_size = 512M
innodb_log_files_in_group = 2
innodb_max_dirty_pages_pct = 75
innodb_io_capacity = 1000
innodb_io_capacity_max = 2000
innodb_file_per_table = 1
innodb_change_buffering = inserts
innodb_adaptive_flushing = 1
innodb_flush_neighbors = 0
EOF
}

show_mysql_diagnostics() {
  local exit_code="$1"

  log "MySQL 初始化失败，mysqld 退出码：${exit_code}"

  if [ -f "${ERROR_LOG}" ]; then
    log "最近的 MySQL 错误日志如下："
    tail -n 120 "${ERROR_LOG}" >&2 || true
  else
    log "没有找到错误日志：${ERROR_LOG}"
  fi

  if [ -x "${MYSQL_HOME}/bin/mysqld" ]; then
    log "检查 mysqld 是否缺少系统动态库："
    ldd "${MYSQL_HOME}/bin/mysqld" | awk '/not found/ {print}' >&2 || true

    log "校验 /etc/my.cnf 是否存在不兼容配置项："
    "${MYSQL_HOME}/bin/mysqld" \
      --defaults-file=/etc/my.cnf \
      --validate-config \
      --user="${MYSQL_USER}" \
      --basedir="${MYSQL_HOME}" \
      --datadir="${DATA_DIR}" >&2 || true
  fi

  die "MySQL 初始化没有完成。请先根据上面的错误处理后再重试。"
}

initialize_database() {
  if [ "${DB_INITIALIZED}" = "1" ]; then
    log "Skipping initialization because ${DATA_DIR} is already initialized"
    return
  fi

  log "Initializing MySQL datadir ${DATA_DIR}"
  set +e
  "${MYSQL_HOME}/bin/mysqld" \
    --defaults-file=/etc/my.cnf \
    --initialize \
    --user="${MYSQL_USER}" \
    --basedir="${MYSQL_HOME}" \
    --datadir="${DATA_DIR}" \
    --lower-case-table-names="${LOWER_CASE_TABLE_NAMES}"
  local init_status=$?
  set -e

  if [ "${init_status}" -ne 0 ]; then
    show_mysql_diagnostics "${init_status}"
  fi
}

write_systemd_unit() {
  if ! command -v systemctl >/dev/null 2>&1; then
    log "systemctl not found; falling back to mysql.server init script"
    cp "${MYSQL_HOME}/support-files/mysql.server" /etc/init.d/mysql
    chmod +x /etc/init.d/mysql
    if command -v chkconfig >/dev/null 2>&1; then
      chkconfig --add mysql
      chkconfig mysql on
    fi
    return
  fi

  log "Writing /etc/systemd/system/mysql.service"
  cat >/etc/systemd/system/mysql.service <<EOF
[Unit]
Description=MySQL ${MYSQL_VERSION} Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${MYSQL_USER}
Group=${MYSQL_GROUP}
LimitNOFILE=65535
ExecStart=${MYSQL_HOME}/bin/mysqld --defaults-file=/etc/my.cnf
Restart=on-failure
RestartSec=5
TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable mysql
}

start_mysql() {
  log "Starting MySQL"

  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart mysql
    systemctl --no-pager --full status mysql || true
  else
    /etc/init.d/mysql restart
  fi
}

wait_for_mysql() {
  log "Waiting for MySQL to accept local socket connections"

  for _ in $(seq 1 120); do
    if "${MYSQL_HOME}/bin/mysqladmin" --socket="${SOCKET_FILE}" --connect-timeout=2 ping >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done

  die "MySQL did not become ready. Check ${ERROR_LOG}."
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

cidr_to_mysql_netmask() {
  local cidr="$1"
  local ip="${cidr%/*}"
  local prefix="${cidr#*/}"

  if ! [[ "${prefix}" =~ ^[0-9]+$ ]] || [ "${prefix}" -lt 0 ] || [ "${prefix}" -gt 32 ]; then
    die "Invalid CIDR host '${cidr}'. Prefix must be 0-32."
  fi

  local mask
  mask=$((0xFFFFFFFF ^ ((1 << (32 - prefix)) - 1)))
  printf '%s/%d.%d.%d.%d\n' \
    "${ip}" \
    $(((mask >> 24) & 255)) \
    $(((mask >> 16) & 255)) \
    $(((mask >> 8) & 255)) \
    $((mask & 255))
}

normalize_mysql_host() {
  local host="$1"

  if [[ "${host}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    cidr_to_mysql_netmask "${host}"
  else
    printf '%s\n' "${host}"
  fi
}

mysql_account_hosts() {
  local raw_hosts="${APP_HOSTS}"
  local host
  local -a hosts

  IFS=',' read -r -a hosts <<<"${raw_hosts}"
  for host in "${hosts[@]}"; do
    host="$(trim "${host}")"
    [ -n "${host}" ] || continue
    normalize_mysql_host "${host}"
  done
}

ident_escape() {
  printf '%s' "$1" | sed 's/`/``/g'
}

temporary_root_password() {
  awk -F': ' '/temporary password/ {print $NF}' "${ERROR_LOG}" | tail -1
}

configure_fresh_root_and_app_user() {
  local temp_password=""

  if [ "${DB_INITIALIZED}" = "0" ]; then
    temp_password="$(temporary_root_password)"
    [ -n "${temp_password}" ] || die "Could not find temporary root password in ${ERROR_LOG}."
  elif [ "${CONFIGURE_EXISTING_DATADIR}" = "1" ]; then
    temp_password="${ROOT_PASSWORD}"
  else
    log "Skipping root/app-user configuration for existing datadir"
    return
  fi

  local root_pw app_pw app_user app_db
  root_pw="$(sql_escape "${ROOT_PASSWORD}")"
  app_pw="$(sql_escape "${APP_PASSWORD}")"
  app_user="$(sql_escape "${APP_USER}")"
  app_db="$(ident_escape "${APP_DB}")"

  local sql_file
  sql_file="$(mktemp)"
  chmod 600 "${sql_file}"

  cat >"${sql_file}" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${root_pw}';
CREATE DATABASE IF NOT EXISTS \`${app_db}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
SQL

  local app_host host_count=0
  while IFS= read -r app_host; do
    app_host="$(sql_escape "${app_host}")"
    cat >>"${sql_file}" <<SQL
CREATE USER IF NOT EXISTS '${app_user}'@'${app_host}' IDENTIFIED WITH mysql_native_password BY '${app_pw}';
ALTER USER '${app_user}'@'${app_host}' IDENTIFIED WITH mysql_native_password BY '${app_pw}';
GRANT ALL PRIVILEGES ON \`${app_db}\`.* TO '${app_user}'@'${app_host}' WITH GRANT OPTION;
SQL
    host_count=$((host_count + 1))
  done < <(mysql_account_hosts)

  [ "${host_count}" -gt 0 ] || die "APP_HOSTS must contain at least one host."
  echo "FLUSH PRIVILEGES;" >>"${sql_file}"

  log "Configuring root password, database ${APP_DB}, and user ${APP_USER} for hosts: $(mysql_account_hosts | paste -sd ',' -)"
  "${MYSQL_HOME}/bin/mysql" \
    --protocol=socket \
    --socket="${SOCKET_FILE}" \
    --connect-expired-password \
    -uroot \
    --password="${temp_password}" <"${sql_file}"

  rm -f "${sql_file}"
}

write_profile() {
  log "Writing /etc/profile.d/mysql.sh"
  cat >/etc/profile.d/mysql.sh <<EOF
export MYSQL_HOME=${MYSQL_HOME}
export PATH=\$PATH:${MYSQL_HOME}/bin
EOF
  chmod 0644 /etc/profile.d/mysql.sh
}

write_command_links() {
  log "Writing MySQL command links to /usr/local/bin"
  mkdir -p /usr/local/bin

  local command_name
  for command_name in mysql mysqladmin mysqldump mysqlbinlog; do
    if [ -x "${MYSQL_HOME}/bin/${command_name}" ]; then
      ln -sfn "${MYSQL_HOME}/bin/${command_name}" "/usr/local/bin/${command_name}"
    fi
  done
}

verify_install() {
  log "Verifying MySQL version and app user"

  "${MYSQL_HOME}/bin/mysql" \
    --protocol=socket \
    --socket="${SOCKET_FILE}" \
    -uroot \
    --password="${ROOT_PASSWORD}" \
    -e "SELECT VERSION() AS mysql_version; SHOW DATABASES LIKE '${APP_DB}';"

  log "MySQL installation completed"
  log "Root user: root@localhost"
  log "App user: ${APP_USER}"
  log "App hosts: $(mysql_account_hosts | paste -sd ',' -)"
  log "App database: ${APP_DB}"
  log "Config file: /etc/my.cnf"
  log "Data dir: ${DATA_DIR}"
  log "Error log: ${ERROR_LOG}"
}

main() {
  require_root
  install_dependencies
  create_mysql_user
  download_mysql
  install_mysql_files
  prepare_directories
  write_my_cnf
  initialize_database
  write_systemd_unit
  start_mysql
  wait_for_mysql
  configure_fresh_root_and_app_user
  write_profile
  write_command_links
  verify_install
}

main "$@"
