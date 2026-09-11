# Terraform 从入门到精通

## 前言

Terraform 是 HashiCorp 开发的基础设施即代码（Infrastructure as Code，IaC）工具。它让网络、虚拟机、数据库、Kubernetes、DNS 和监控等基础设施变成可以评审、版本控制、测试、复用和自动发布的代码。

这篇文档是一份独立的技术教程，不依赖某个云厂商或某一个仓库。示例主要使用 AWS provider，但其中的 Terraform 语言、模块设计、state、依赖图、测试和工程实践同样适用于 Azure、阿里云、Google Cloud、Kubernetes、Docker 等 provider。

---

## 1. Terraform 到底解决什么问题

手工创建基础设施有四个典型问题：步骤不可重复、变更缺乏审核、环境容易漂移、资源之间的依赖难以维护。Terraform 用声明式配置描述“最终状态”，而不是描述一串 API 调用。

```text
Terraform 配置 + Provider + State + 远端真实环境
                         │
                    terraform plan
                         │
                    terraform apply
```

Terraform 的核心闭环是：配置表达意图，provider 翻译为平台 API，state 保存管理关系，plan 计算差异，apply 执行差异。

Terraform 不是配置管理工具。它擅长创建和编排基础设施，不适合代替 Ansible、Salt、Chef 去持续修改操作系统内部文件。通常的边界是：Terraform 创建服务器和网络，镜像或 cloud-init 完成最小启动，配置管理工具负责长期软件配置。

---

## 2. 安装、目录和第一个资源

安装 Terraform 后，建立一个目录。一个 Terraform root module 就是一个目录中的所有 `.tf` 文件集合；Terraform 会读取目录内的所有 `.tf` 文件，不要求只有一个 `main.tf`。

```text
hello-terraform/
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── terraform.tfvars.example
```

最小 AWS 示例：

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

resource "aws_s3_bucket" "example" {
  bucket = "unique-example-name"
}

output "bucket_name" {
  value = aws_s3_bucket.example.id
}
```

执行流程：

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
terraform destroy
```

`init` 下载 provider 和模块；`fmt` 统一格式；`validate` 检查语法和类型；`plan` 显示将发生的变化；`apply` 执行变化；`destroy` 删除当前 state 管理的资源。

---

## 3. Terraform 配置语言 HCL

### 3.1 resource

resource 表示 Terraform 管理的对象。地址由类型和名称组成，例如 `aws_s3_bucket.example`。

```hcl
resource "aws_security_group" "web" {
  name   = "web"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}
```

### 3.2 data

data 只查询已有对象，不创建对象：

```hcl
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}
```

### 3.3 variable

变量是模块的输入 API。生产代码应尽量使用严格类型：

```hcl
variable "environment" {
  type        = string
  description = "部署环境"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment 必须是 dev、staging 或 prod。"
  }
}
```

敏感变量应标记 `sensitive = true`，但要记住：sensitive 不会自动从 state 中删除秘密。

### 3.4 locals

locals 用于保存派生值和避免重复表达式：

```hcl
locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

### 3.5 output

output 是 root module 的结果，也是子模块之间的接口：

```hcl
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}
```

### 3.6 注释和命名

资源名使用稳定、具有业务含义的名字；不要把随机时间戳拼进资源名，除非资源确实需要唯一名称。注释应解释“为什么”，而不是重复“是什么”。

---

## 4. 类型、表达式和集合处理

Terraform 支持 `string`、`number`、`bool`、`list`、`set`、`map`、`object` 和 `tuple`。集合类型的选择会影响 diff：list 有顺序，set 无顺序且自动去重，map 用 key 识别元素。

```hcl
variable "subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
    tier = optional(string, "private")
  }))
}
```

常见表达式：

```hcl
# 条件
var.environment == "prod" ? 3 : 1

# for
[for subnet in var.subnets : subnet.cidr]

# map for
{ for subnet in var.subnets : subnet.name => subnet.cidr }

# 合并 map
merge(local.common_tags, var.extra_tags)

# 安全读取可选字段
try(var.config.timeout, 30)

# 取第一个非 null/非空值
coalesce(var.name, "default")
```

`flatten` 适合把嵌套列表转换为扁平列表，`zipmap` 适合把两个同长度列表组成 map，`toset` 适合为 `for_each` 去重。

调试复杂表达式：

```bash
terraform console
> local.common_tags
> [for x in var.subnets : x.name]
```

---

## 5. Provider、版本和锁文件

provider 是 Terraform 与外部平台之间的适配器。`required_providers` 至少应声明 source 和版本约束：

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}
```

初始化后会生成 `.terraform.lock.hcl`，其中保存 provider 校验和。锁文件通常应该提交；`.terraform/` 目录不应该提交。

版本约束的含义：`~> 2.30` 允许兼容的 2.x 小版本升级，`>= 2.30, < 3.0` 表达更明确的上限。升级 provider 前先阅读 changelog，在测试环境执行完整 plan。

---

## 6. 模块：从复制代码到设计接口

模块就是一个可复用的 Terraform 目录。推荐结构：

```text
modules/vpc/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── README.md
```

调用模块：

```hcl
module "vpc" {
  source = "./modules/vpc"

  name       = local.name
  cidr_block = var.vpc_cidr
  tags       = local.common_tags
}
```

模块设计原则：输入有严格类型，关键值有 validation，输出稳定，默认值安全，不硬编码账号、区域和秘密，不创建调用者没有明确请求的附属资源。

root module 负责环境和组合，子模块负责资源实现。不要创建一个包含 VPC、数据库、EKS、监控和所有应用的“万能模块”；这会让任何小改动都影响整个生命周期。

---

## 7. 依赖图、for_each、count 和 moved

Terraform 会从表达式引用推导依赖：

```hcl
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id
}
```

只有 Terraform 无法通过引用推导、但真实系统存在先后关系时才使用 `depends_on`。过度依赖 `depends_on` 会扩大 plan 范围，降低并行度。

稳定命名的资源适合 `for_each`：

```hcl
resource "aws_subnet" "this" {
  for_each = var.subnets
  vpc_id   = var.vpc_id
  cidr_block = each.value.cidr
}
```

如果 `for_each` 的 key 从 `app` 改成 `web`，Terraform 会认为旧资源消失、新资源出现。无损重命名使用：

```hcl
moved {
  from = aws_subnet.this["app"]
  to   = aws_subnet.this["web"]
}
```

`count` 适合只关心数量的资源；对有业务名称的集合优先使用 `for_each`。

---

## 8. State、Backend 和协作

state 保存 Terraform 资源地址、真实 ID、属性和依赖，是 Terraform 的管理记忆。它不是普通缓存，也不是可以随意删除的临时文件。

本地 backend 适合学习和个人实验；团队生产应使用远程 backend，例如 S3 配合版本控制、加密、锁和最小 IAM。每个环境应有独立的 state key，避免开发环境覆盖生产环境。

```hcl
terraform {
  backend "s3" {
    bucket       = "company-terraform-state"
    key          = "prod/network/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

常用 state 命令：

```bash
terraform state list
terraform state show ADDRESS
terraform state mv OLD NEW
terraform state rm ADDRESS
terraform import ADDRESS ID
```

`state rm` 不删除真实资源；`import` 只建立映射，不会替你写出完整配置。任何 state 操作前都要备份并审核地址。

---

## 9. Plan、Apply 和生命周期

生产发布建议固定流程：

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
# 审核后
terraform apply tfplan
```

生命周期 meta-argument：

```hcl
lifecycle {
  prevent_destroy       = true
  create_before_destroy = true
  ignore_changes        = [tags]
}
```

`prevent_destroy` 适合数据库、日志桶等关键资源；`create_before_destroy` 适合支持并行替换的资源；`ignore_changes` 只应用于明确由外部系统管理的字段，不要用它掩盖漂移。

---

## 10. 网络、数据库和 Kubernetes 的通用建模

网络通常从 VPC、子网、路由、网关、安全组开始。数据库应通过独立子网组和最小安全组访问；不要把数据库直接放在公网子网。Kubernetes 集群应明确控制面、节点、负载均衡器、Pod 网络和出站路径。

Terraform 负责声明 EKS cluster、node group、IAM、EFS、StorageClass 等对象；Kubernetes controller 负责根据这些对象运行工作负载。Terraform、Helm、kubectl 不应同时管理同一个字段，否则会产生所有权争用和反复 diff。

---

## 11. 安全实践

1. 不把 access key、secret、数据库密码提交到 Git。
2. 不把 state、tfvars、kubeconfig、plan 放进公开 artifact。
3. 使用 SSO、短期角色或 CI OIDC，避免长期凭据。
4. 生产 EKS API 使用 private endpoint 或严格的公网 CIDR allowlist。
5. 节点使用 SSM Session Manager，减少 SSH key 和 22 端口。
6. 所有 EBS、RDS、EFS 和 state backend 使用加密与备份。
7. 在 CI 中使用 Trivy、Checkov、tfsec/tflint 等静态检查。
8. 对资源增加 `precondition`，把安全要求变成代码规则。

```hcl
resource "aws_eks_cluster" "this" {
  # ...

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.public_endpoint == false
      error_message = "生产环境不能默认开启公网 Kubernetes API。"
    }
  }
}
```

---

## 12. 测试和质量门禁

Terraform 测试可以分层：

- 格式：`terraform fmt -check -recursive`
- 语法和类型：`terraform validate`
- 静态安全：Checkov、Trivy、TFLint
- 计划测试：检查没有公开数据库、未加密磁盘和意外 destroy
- 模块测试：`terraform test`
- 集成测试：在临时账号或隔离 VPC apply
- 恢复测试：验证备份、重建和回滚

CI 不应直接对生产执行任意配置。推荐 PR 生成 plan，审批后只 apply 已保存的 plan，并记录 commit SHA、操作者、角色、时间和输出。

---

## 13. Drift、导入和升级

控制台手工修改会造成 drift。`terraform plan -refresh-only` 可用于识别远端变化；确认后通过代码修复，而不是长期依赖控制台。

引入现有资源的正确流程是：确定资源所有权和生命周期，执行 `terraform import`，补齐配置，运行 plan 消除差异，再纳入日常发布。

升级流程是：固定 provider/module 版本，阅读 changelog，在分支中执行 `init -upgrade`，运行 validate 和 plan，先在测试环境 apply，验证后再进入生产窗口。

---

## 14. 常见错误和排查方式

### provider 初始化失败

检查 provider source、版本锁、网络、AWS profile、区域和凭据权限。不要为了绕过鉴权错误把秘密硬编码进代码。

### state lock

先确认是否有另一个 apply 正在运行，再检查锁信息。不要在不了解后果时强制解锁。

### 计划意外替换

重点检查资源地址、for_each key、AZ/CIDR 顺序、provider/module 版本、不可变字段和 `moved` block。

### remote state 读取失败

检查上游环境是否已 apply、backend 路径是否正确、output 名称是否改变、执行身份是否有读取权限。

### Kubernetes 资源反复变化

检查 Helm、kubectl、Terraform 的 ownership，确认 YAML 的 map 顺序、默认字段、server-side apply 和 controller 是否在回写资源。

---

## 15. 从熟练到精通

真正精通 Terraform，不是背下更多 resource 名称，而是能够：

- 根据输入预测依赖图和 plan 结果；
- 设计清晰的 root module、子模块和 state 边界；
- 处理 for_each 重命名、import、漂移和 provider 升级；
- 把安全、成本、备份和权限要求写成变量验证和 policy；
- 设计可审计的 CI/CD plan/apply 流程；
- 解释一次变更的替换风险、停机风险、回滚路径和数据恢复方案；
- 在资源规模扩大后仍能保持代码可读、差异稳定、发布可重复。

Terraform 的终点不是“成功 apply 一次”，而是让基础设施像软件一样拥有类型、版本、测试、评审、发布、回滚和长期维护能力。
