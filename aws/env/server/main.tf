provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

# data "terraform_remote_state" "common" {
#   backend = "local"
#   config = {
#     path = "../network/terraform.tfstate"
#   }
# }

# locals {
#   ## vpc ID
#   vpc_id = data.terraform_remote_state.common.outputs.vpc_id

#   ## 子网信息
#   subnet_nginx = data.terraform_remote_state.common.outputs.subnet_nginx
#   subnet_public = data.terraform_remote_state.common.outputs.subnet_public
  
#   ## 安全组
#   common_security_group = data.terraform_remote_state.common.outputs.common_security_group

#   # 使用的KEY
#   key = "key 的名称，可以手动创建"

#   ## 镜像ID，根据需求选择镜像
#   image_ami = "ami-XXXXX"
# }

