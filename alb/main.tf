
# ALB, listener, target group

provider "aws" {}

variable "allowed_cidr_blocks" {
  type = list
  default = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  default = "arn:aws:acm:us-east-2:558850831704:certificate/1b1b8b4d-58df-446b-996f-601a89981235"
}




data "aws_vpc" "vpc" {
  filter {
    name = "tag:Project"
    values = ["Dev1"]
  }
}

data "aws_subnet" "publicc1" {
  filter {
    name   = "tag:Name"
    values = ["Public Subnet 1"]
  }
}
data "aws_subnet" "publicc2" {
  filter {
    name   = "tag:Name"
    values = ["Public Subnet 2"]
  }
}
resource "aws_security_group" "alb" {
  name        = "terraform_alb_security_group"
  description = "Terraform load balancer security group"
  vpc_id      = "${data.aws_vpc.vpc.id}"

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



resource "aws_alb" "alb" {
  name            = "terraform-example-alb"
  security_groups = ["${aws_security_group.alb.id}"]
  subnet_mapping {
    subnet_id            = data.aws_subnet.publicc1.id
    private_ipv4_address = "10.0.1.15"
  }

  subnet_mapping {
    subnet_id            = data.aws_subnet.publicc2.id
    private_ipv4_address = "10.0.2.15"
  }
}

resource "aws_alb_target_group" "group" {
  name     = "terraform-example-alb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/login"
    port = 80
  }
}



resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}


data "aws_route53_zone" "zone" {
  name = "darvaza.az."
}


resource "aws_alb_listener" "listener_https" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.certificate_arn}"
  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}

resource "aws_route53_record" "terraform" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "www.${data.aws_route53_zone.zone.name}"
  type    = "A"
  alias {
    name                   = "${aws_alb.alb.dns_name}"
    zone_id                = "${aws_alb.alb.zone_id}"
    evaluate_target_health = true
  }
}
