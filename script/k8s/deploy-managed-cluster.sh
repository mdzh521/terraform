#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./terraform/script/k8s/deploy-managed-cluster.sh <eks|ack>

Required environment variables:
  EKS: TF_VAR_aws_access_key, TF_VAR_aws_secret_key
  ACK: TF_VAR_ali_access_key, TF_VAR_ali_secret_key, TF_VAR_node_login_password

Optional:
  TERRAFORM_BIN=terraform
EOF
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "missing required environment variable: ${name}" >&2
    exit 1
  fi
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

platform="$1"
terraform_bin="${TERRAFORM_BIN:-terraform}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$platform" in
  eks)
    tf_dir="${repo_root}/aws/env/quickstart-eks"
    require_env "TF_VAR_aws_access_key"
    require_env "TF_VAR_aws_secret_key"
    ;;
  ack)
    tf_dir="${repo_root}/ali/env/ack"
    require_env "TF_VAR_ali_access_key"
    require_env "TF_VAR_ali_secret_key"
    require_env "TF_VAR_node_login_password"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if ! command -v "${terraform_bin}" >/dev/null 2>&1; then
  echo "terraform binary not found: ${terraform_bin}" >&2
  exit 1
fi

mkdir -p "${tf_dir}/output"

echo "==> terraform init (${platform})"
"${terraform_bin}" -chdir="${tf_dir}" init

echo "==> terraform apply (${platform})"
"${terraform_bin}" -chdir="${tf_dir}" apply -auto-approve

kubeconfig_path="$("${terraform_bin}" -chdir="${tf_dir}" output -raw kubeconfig_path)"
cluster_name="$("${terraform_bin}" -chdir="${tf_dir}" output -raw cluster_name)"

echo
echo "cluster=${cluster_name}"
echo "kubeconfig=${kubeconfig_path}"
echo "export KUBECONFIG=${kubeconfig_path}"
