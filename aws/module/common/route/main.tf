# data "aws_route_table" "table" {
#   vpc_id = aws_vpc.main.id
# }

# resource "aws_internet_gateway" "gw" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "tf-demo-ec2-gw"
#   }
# }

# resource "aws_route" "r" {
#   route_table_id         = data.aws_route_table.table.id
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id             = aws_internet_gateway.gw.id
# }