// modules/subnet/main.tf
resource "aws_subnet" "example" {
  count             = length(var.availability_zones)
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }
}
