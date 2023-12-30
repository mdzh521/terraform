

module "network" {
  source    = "./modules/network"
  vpc_cidr  = "10.0.0.0/16"
  vpc_name  = "main-vpc"
}

module "subnet" {
  source             = "./modules/subnet"
  vpc_id             = module.network.aws_vpc.main.id
  availability_zones = ["your_az1", "your_az2"] // Add your availability zones
  internet_gateway_id = module.network.aws_internet_gateway.gw.id
}

module "nat_gateway" {
  source    = "./modules/nat_gateway"
  subnet_id = module.subnet.aws_subnet.example[0].id // Change this based on your configuration
}
