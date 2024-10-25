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
  cidr_block                       = "10.0.0.0/16"
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
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

resource "aws_key_pair" "local_ssh_key" {
  key_name   = "ssh key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "tls_private_key" "static_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port        = 25565
    to_port          = 25565
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/1"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/1"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/1"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/1"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/1"]
  }
}

resource "aws_eip" "public" {
  domain            = "vpc"
  network_interface = aws_network_interface.public.id
}

resource "aws_network_interface" "public" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.main.id]
  private_ips     = ["10.0.128.4"]
}

resource "aws_network_interface" "private" {
  subnet_id         = aws_subnet.private.id
  security_groups   = [aws_security_group.main.id]
  private_ips       = ["10.0.0.4"]
  source_dest_check = false
}

resource "aws_instance" "main" {
  instance_type        = "t4g.nano"
  ami                  = data.aws_ami.arm.id
  availability_zone    = "ap-southeast-2b"
  key_name             = aws_key_pair.local_ssh_key.key_name
  iam_instance_profile = aws_iam_instance_profile.main.name

  tags = {
    Name = "Main"
  }

  network_interface {
    network_interface_id = aws_network_interface.public.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.private.id
    device_index         = 1
  }

  user_data_replace_on_change = true
  user_data = templatefile("main.yml.tpl", {
    domain_name  = "lenqua.link"
    private_cidr = aws_subnet.private.cidr_block
    private_key  = tls_private_key.static_key.private_key_pem
    public_key   = tls_private_key.static_key.public_key_pem
    nginx_configs = yamlencode([for file in fileset("nginx", "*.conf") : {
      path    = "/etc/nginx/conf.d/${file}"
      content = templatefile("nginx/${file}", {})
    }])
  })
}

module "mcproxy_config" {
  source = "./service_config"

  service_name = "mcproxy"
  instance_id  = aws_instance.main.id
  public_ip    = aws_instance.main.public_ip
  config_path  = "/opt/mcproxy/config.json"
  config_contents = jsonencode({
    listen = {
      address           = ":25565"
      fallback_version  = "1.21.1"
      fallback_protocol = 767
    }
    proxies = [{
      domains              = ["vanilla.lenqua.link", "minecraft.scarzone.online"]
      destination_ip       = module.vanilla.private_ip
      destination_port     = 25565
      destination_version  = "1.21.1"
      destination_protocol = 767
      shutdown_timeout     = 900
      ec2_server = {
        region      = "ap-southeast-2"
        instance_id = module.vanilla.instance_id
        hibernate   = false
      }
    }]
  })
}
