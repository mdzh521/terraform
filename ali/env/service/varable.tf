variable "ali_access_key" {
  type = string
}

variable "ali_secret_key" {
  type = string
}

variable "ali_region" {
  type = string
}

#### 变量使用形式 ####

# export TF_VAR_ali_access_key=<access_key>
# export TF_VAR_ali_secret_key=<secret_key>
# export TF_VAR_ali_region=<region>