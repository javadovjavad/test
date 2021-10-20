
# VPC, Subnet

provider "aws" {}
data "aws_availability_zones" "working" {}
variable "az1" {
  default = "us-east-2a"
}
variable "az2" {
  default = "us-east-2c"
}
resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name    = "Main VPC"
    Project = "Dev1"
  }
}

/* Internet gateway for the public subnet */
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
   tags = {
    Name    = "Internet gateway"
    Project = "Dev1"
  }
}

resource "aws_eip" "my_eip" {
  vpc = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.igw]
tags = {
    Name        = "nat"
    Project     = "Dev1"
  }
}
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.working.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "Public Subnet 1"
    Project = "Dev1"
  }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.working.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name    = "Public Subnet 2"
    Project = "Dev1"
  }
}
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.11.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 1"
    Project = "Dev1"
  }
}
resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.12.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 2"
    Project = "Dev1"
  }
}

resource "aws_route_table" "public_route" {
  vpc_id     = aws_vpc.main_vpc.id
}
resource "aws_route_table" "private_route" {
  vpc_id     = aws_vpc.main_vpc.id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public_route.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}
resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private_route.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat.id}"
}

/* Route table associations */
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route.id
}
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route.id
}
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route.id
}


resource "aws_security_group" "default" {
  name        = "Dynamic security group"
  description = "Default security group to allow inbound/outbound from the VPC"

dynamic "ingress"{
  for_each = ["22","80","443"]
  content {
      description      = "ingress SSH from VPC"
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
  }
}

  egress = [
    {
      description      = "Allow egress from VPC"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]

  tags = {
    Name = "Dynamic security group"
    Project = "Dev1"
  }
}

#~~~~~~~~~~~~~~~~~~ Outputs ~~~~~~~~~~~~~~~~~~~~~
output "vpc" {
  value= aws_vpc.main_vpc.id
}
