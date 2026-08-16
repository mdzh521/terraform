# AWS EKS 集群环境

这个目录用于创建和维护 AWS EKS 集群层，当前环境依赖同级 `../network`
环境已经创建好的 VPC、子网、安全组和子网标签。

## 当前环境

- 区域：`ap-east-1`
- 集群名称：`otc-new`
- Kubernetes 版本：`1.34`
- EKS API：开启公网和私网 endpoint
- 公网 API 允许来源：`43.198.69.17/32`
- kubeconfig 输出：`output/kubeconfig`

`output/kubeconfig` 包含集群访问凭据，不能提交或对外共享。

## 目录文件

- `terraform.tfvars.example`：提交到仓库的参数模板，包含注释说明。
- `terraform.tfvars`：本地真实参数文件，Terraform 会自动读取，默认不提交。
- `eks.tf`：EKS、EFS、Add-ons、Karpenter 和 Kubernetes 资源编排。
- `variables.tf`：输入变量定义和默认值。
- `outputs.tf`：集群、节点组、EFS、Karpenter 等输出。
- `output/kubeconfig`：Terraform 生成的 kubeconfig 文件。

## 前置依赖

先完成 `../network` 环境。EKS 当前读取的 network state 需要输出：

- `subnet_ids_by_group`
- `subnet_cidrs_by_group`
- `vpc_id`
- `common_security_group`

当前使用的子网分组：

- `k8s`：EKS control plane、managed node group、Karpenter 节点使用。
- `lb`：AWS Load Balancer Controller 发现公网负载均衡子网使用。

网络环境需要提前维护好 Kubernetes 子网发现标签。常用标签包括：

- `kubernetes.io/cluster/<cluster_name>`
- `kubernetes.io/role/elb`
- `kubernetes.io/role/internal-elb`

## 主要资源

当前 `terraform.tfvars` 中定义了两个 EKS managed node group：

- `otc-backend`：`m7i.2xlarge`，最小 `8`，期望 `8`，最大 `15`。
- `heavy-load`：`m7i.2xlarge`，最小 `3`，期望 `3`，最大 `10`，带
  `dedicated=heavy-load:NoSchedule` taint。

节点默认配置：

- AMI 类型：`AL2023_x86_64_STANDARD`
- 根盘：`gp3`，`200Gi`
- IMDSv2：required
- EC2 详细监控：开启
- API termination protection：开启
- SSH key：`my-eks-key`

## Add-ons

EKS managed add-ons 当前版本：

- `vpc-cni`：`v1.23.0-eksbuild.1`
- `coredns`：`v1.13.2-eksbuild.11`
- `kube-proxy`：`v1.34.6-eksbuild.18`
- `aws-ebs-csi-driver`：`v1.63.1-eksbuild.1`

其他集群组件：

- AWS Load Balancer Controller
- AWS EFS CSI Driver
- Metrics Server
- Karpenter

如果调整 `kubernetes_version`，需要同步核对这些 add-on 版本，避免版本和
控制面不匹配。

## 存储

当前会创建 EFS 文件系统，并在集群内创建 StorageClass：

- `efs`
- `gp3`，默认 StorageClass

默认的 `gp2` StorageClass 会取消默认标记。

## Karpenter

当前配置包含：

- EC2NodeClass：`al2023`
- AMI alias：`al2023@v20250915`
- NodePool：`karpenter-132`
- 实例类型：`m7i.xlarge`
- capacity type：`on-demand`
- CPU limit：`20`
- Memory limit：`64Gi`
- expire after：`Never`
- consolidation policy：`WhenEmpty`

调整节点规格或扩容数量前，先确认 `ap-east-1` 的 EC2 vCPU 配额是否足够。

## 凭据

AWS access key 不建议写入 `terraform.tfvars`。本地运行时使用环境变量：

```shell
export TF_VAR_aws_access_key="..."
export TF_VAR_aws_secret_key="..."
```

也可以使用本机已经配置好的 AWS profile，但要保证 Terraform provider 能拿到
对应账号和区域的权限。

## 首次创建

首次从零创建时，先跑 network，再创建 EKS 和 EFS，最后安装依赖 Kubernetes
API 的 add-ons 和集群内资源：

```shell
terraform -chdir=../network apply

cd /Users/alex/ops/terraform/aws/env/eks-cluster
terraform init

terraform apply \
  -target=module.eks \
  -target=module.efs

terraform apply
```

`-target` 只用于首次 bootstrap 或错误恢复。日常变更不要长期依赖 `-target`，
否则 plan 可能漏掉其他需要同步的资源。

## 日常变更

普通变更使用完整 plan 和 apply：

```shell
cd /Users/alex/ops/terraform/aws/env/eks-cluster
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

apply 完成后可以删除本地 `tfplan` 文件。仓库已忽略 `tfplan*`。

## 验证命令

```shell
terraform plan

kubectl --kubeconfig output/kubeconfig get nodes
kubectl --kubeconfig output/kubeconfig -n kube-system get pods
kubectl --kubeconfig output/kubeconfig get nodepool,ec2nodeclass -A
kubectl --kubeconfig output/kubeconfig get storageclass
```

如果 `terraform validate` 或 `terraform plan` 看到
`data.aws_region.current.name` deprecated 警告，这是上游
`eks_blueprints_addons` 模块内部用法导致的 deprecation warning，不是当前配置
本身的阻断错误。

## 清理和提交

不要提交下面这些本地文件：

- `.terraform/`
- `terraform.tfvars`
- `terraform.tfstate`
- `terraform.tfstate.backup`
- `tfplan*`
- `output/`

这些文件包含本地状态、计划文件或敏感集群访问内容，只保留在运行机器上。
