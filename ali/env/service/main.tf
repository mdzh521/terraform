provider "alicloud" {
  access_key = var.ali_access_key
  secret_key = var.ali_secret_key
  region     = var.ali_region # 香港区域
}


data "terraform_remote_state" "common" {
  backend  = "local"
  config = {
    path = "../network/terraform.tfstate"
  }
}

locals {
  # vpc ID 
  vpc_id = data.terraform_remote_state.common.outputs.vpc_id
  # nginx 子网ID
  vsw_subnet_nginx = data.terraform_remote_state.common.outputs.vsw_subnet_nginx
  # 公共安全组 ID
  security_id = data.terraform_remote_state.common.outputs.security_id

  # 公共镜像 centos
  centos_image = "centos_7_9_uefi_x64_20G_alibase_20230816.vhd"

}

