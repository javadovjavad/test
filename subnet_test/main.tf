provider "aws" {}

data "aws_vpc" "vpc" {
  filter {
    name = "tag:Project"
    values = ["Dev1"]
  }
}
data "aws_subnet_ids" "subnets_private" {
  vpc_id = data.aws_vpc.vpc.id

  filter {
    name = "tag:Name"
    values = ["Public*"]
  }
}


data "aws_subnet" "example" {
  for_each = data.aws_subnet_ids.subnets_private.ids
  id       = each.value
}

output "subnet_ids" {
  value = [for s in data.aws_subnet.example : s.id]
}