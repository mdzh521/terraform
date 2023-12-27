# 基础设施及代码--Terraform

## 基础命令展示
### terraform
基础设施建设

### 初始化仓库
terraform init

### 预览执行内容
terraform plan

### 执行计划
terraform apply

## Terraform 语法
<!-- https://registry.terraform.io/browse/providers 通过此链接可以查看官方验证的方法 -->
<summary>https://registry.terraform.io/browse/providers 通过此链接可以查看官方验证的方法</summary>


### 1. provider
terraform 是通过provider 来维护基础设施，使用provider来和云供应商提供的API进行交互

### 2. resource
Resource 资源来自 Provider，是 Terraform 中最重要的元素，每个资源块描述一个或多个基础对象，例如网络、计算实例或更高级别的组件，例如 DNS 记录。

