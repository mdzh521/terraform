# 一键部署 ACK / EKS

统一入口脚本：

```bash
./terraform/script/k8s/deploy-managed-cluster.sh eks
./terraform/script/k8s/deploy-managed-cluster.sh ack
```

## EKS

最低必填环境变量：

```bash
export TF_VAR_aws_access_key="<aws_access_key>"
export TF_VAR_aws_secret_key="<aws_secret_key>"
```

可选变量：

```bash
export TF_VAR_cluster_name="quickstart-eks"
export TF_VAR_aws_region="ap-east-1"
export TF_VAR_eks_admin_principal_arns='["arn:aws:iam::123456789012:role/admin"]'
```

部署完成后，脚本会输出 `kubeconfig` 文件路径。该 kubeconfig 基于集群内自动创建的 `cluster-admin` ServiceAccount 生成，可直接给 `kubectl` 使用。

## ACK

最低必填环境变量：

```bash
export TF_VAR_ali_access_key="<ali_access_key>"
export TF_VAR_ali_secret_key="<ali_secret_key>"
export TF_VAR_node_login_password="<node_password>"
```

可选变量：

```bash
export TF_VAR_cluster_name="quickstart-ack"
export TF_VAR_ali_region="cn-hongkong"
export TF_VAR_ack_admin_uid="<ram_user_or_role_id>"
export TF_VAR_ack_admin_is_ram_role=false
```

ACK 部署流程会自动：

- 激活 ACK 服务
- 创建默认 ACK 服务角色并绑定系统策略
- 创建托管集群和默认节点池
- 生成临时 bootstrap kubeconfig
- 在集群内创建 `cluster-admin` ServiceAccount，并导出最终 kubeconfig

输出文件默认在对应环境目录下的 `output/kubeconfig`。

如果账号里已经存在 ACK 默认服务角色，可以设置：

```bash
export TF_VAR_create_ack_service_roles=false
```
