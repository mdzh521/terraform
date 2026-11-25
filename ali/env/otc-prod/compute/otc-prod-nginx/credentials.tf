variable "ali_access_key" {
  type        = string
  description = "Alibaba Cloud access key for the target account"
  sensitive   = true
}

variable "ali_secret_key" {
  type        = string
  description = "Alibaba Cloud secret key for the target account"
  sensitive   = true
}

variable "ali_region" {
  type        = string
  description = "Alibaba Cloud region for service resources"
  default     = "cn-hongkong"
}

#### 变量使用形式 ####

# export TF_VAR_ali_access_key=<access_key>
# export TF_VAR_ali_secret_key=<secret_key>
# export TF_VAR_ali_region=<region>
