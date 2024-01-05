# // modules/nat_gateway/main.tf
# resource "aws_eip" "nat" {
#   instance = aws_nat_gateway.main.id
# }

# resource "aws_nat_gateway" "main" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = var.subnet_id
# }

# resource "aws_route_table" "private" {
#   vpc_id = var.vpc_id
# }

# resource "aws_route" "private_route" {
#   route_table_id         = aws_route_table.private.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.main.id
# }
