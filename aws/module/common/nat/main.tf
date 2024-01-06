resource "aws_eip" "nat" {
  domain = "vpc"
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.nat_subnet_id
  tags = {
    Name = "prod-nat-网关"
  }
}

############################## 变量 ############################

variable "nat_subnet_id" {
  description = "nat 分配子网"
}

############################## 输出信息 ########################

output "nat_id" {
    value = aws_nat_gateway.main.id
}

