```shell
# 1. 创建启动模板 && efs 等资源
terraform apply --auto-approve -target=module.network
terraform apply --auto-approve -target=module.launch_template
terraform apply --auto-approve -target=module.efs

# 在创建eks
terraform apply -auto-approve -target=module.eks

# 2. 清理时
terraform apply -auto-approve -target=module.eks
terraform apply -auto-approve
```