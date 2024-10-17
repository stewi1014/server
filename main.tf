terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket = "stewart-terraform"
    key    = "main.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_vpc" "vpc" {
  cidr_block                       = var.cidr_block
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "rta" {
  route_table_id = aws_route_table.rt.id
  subnet_id      = aws_subnet.subnet.id
}

resource "aws_ec2_instance_connect_endpoint" "endpoint" {
  subnet_id = aws_subnet.subnet.id
}

resource "aws_subnet" "subnet" {
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet(var.cidr_block, 8, 0)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, 0)
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = false
}

resource "aws_route53_zone" "lenqua_link" {
  name = "lenqua.link"
}

resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.lenqua_link.zone_id
  name    = "lenqua.link"
  type    = "A"
  ttl     = 300
  records = [aws_eip.public.public_ip]
}

resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.lenqua_link.zone_id
  name    = "*.lenqua.link"
  type    = "A"
  ttl     = 300
  records = [aws_eip.public.public_ip]
}

data "aws_iam_policy_document" "manage_ec2" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstanceStatus",
      "ec2:StartInstances",
      "ec2:StopInstances",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "manage_ec2" {
  name   = "manage_ec2"
  policy = data.aws_iam_policy_document.manage_ec2.json
}

resource "aws_iam_policy_attachment" "manage_ec2" {
  name       = "manage_ec2"
  roles      = [aws_iam_role.manage_ec2.name]
  policy_arn = aws_iam_policy.manage_ec2.arn
}

resource "aws_iam_role" "manage_ec2" {
  name               = "manage_ec2"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "main" {
  name = "manage_ec2"
  role = aws_iam_role.manage_ec2.name
}

# allow the vpc, ssh and all egress.
resource "aws_security_group" "allow_vpc_ssh_egress" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/1"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/1"]
  }
}

resource "aws_key_pair" "local_ssh_key" {
  key_name   = "ssh key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "tls_private_key" "static_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_eip" "public" {
  domain   = "vpc"
  instance = aws_instance.main.id
}

resource "aws_instance" "main" {
  instance_type = "t4g.nano"
  ami           = data.aws_ami.arm.id
  vpc_security_group_ids = [
    aws_security_group.allow_vpc_ssh_egress.id,
    aws_security_group.allow_minecraft.id
  ]
  subnet_id            = aws_subnet.subnet.id
  availability_zone    = "ap-southeast-2b"
  key_name             = aws_key_pair.local_ssh_key.key_name
  iam_instance_profile = aws_iam_instance_profile.main.name

  tags = {
    Name = "Main"
  }

  user_data_replace_on_change = true
  user_data = templatefile("main.yml.tpl", {
    domain_name = "lenqua.link"
    mcproxy_config = templatefile("mcproxy_config.json.tpl", {
      vanilla_dest_ip  = aws_instance.minecraft.private_ip
      vanilla_region   = aws_instance.minecraft.availability_zone
      vanilla_instance = aws_instance.minecraft.id
    })
    private_key = tls_private_key.static_key.private_key_pem
    public_key  = tls_private_key.static_key.public_key_pem
  })
}
