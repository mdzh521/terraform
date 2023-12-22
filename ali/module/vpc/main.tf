## 专有网络 vpc
resource "alicloud_vpc" "vpc" {
  vpc_name    = var.vpc_name
  cidr_block  = var.vpc_cidr_block
  description = "vpc example"
}

##################################### 变量信息 #####################################
variable "vpc_cidr_block" {
  description = "vpc的CIDR块"
}

variable "vpc_name" {
  description = "vpc名称列表"
  default     = "prod"
}

#################################### 输出信息 #####################################

output "vpc_id" {
  value = alicloud_vpc.vpc.id
}