resource "aws_subnet" "subnet" {
  count                   = length(var.azs)
  vpc_id                  = var.vpc_id
  cidr_block              = var.subnet_cidr_blocks[count.index]
  availability_zone       = element(var.azs, count.index % length(var.azs))
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name = "${var.subnet_names[count.index]}-${var.azs[count.index % length(var.azs)]}"
  }
}

##################### 变量 ###################
variable "azs" {
  description = "可用区选择"
}

variable "vpc_id" {
  description = "vpc ID 选择"
}

variable "subnet_cidr_blocks" {
  description = "子网网段选择"
}

variable "subnet_names" {
  description = "子网名称"
}

variable "map_public_ip_on_launch" {
  description = "子网类型是否开启公网IP"
}

###################### 输出信息 ######################
output "subnet_ids" {
  value = aws_subnet.subnet[*].id
}
