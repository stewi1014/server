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

locals {
  main_private_ip = "10.0.0.4"
}

resource "aws_network_interface" "public" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.main.id]
  private_ips     = ["10.0.128.4"]
}

resource "aws_network_interface" "private" {
  subnet_id         = aws_subnet.private.id
  security_groups   = [aws_security_group.main.id]
  private_ips       = [local.main_private_ip]
  source_dest_check = false
}

resource "aws_ebs_volume" "data" {
  availability_zone = "ap-southeast-2b"
  size              = 150
  final_snapshot    = true
  type              = "sc1"

  tags = {
    Name = "data storage"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/xvdb"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.main.id
}

resource "aws_ebs_volume" "web_data" {
  availability_zone = "ap-southeast-2b"
  size              = 2
  final_snapshot    = true
  type              = "gp3"

  tags = {
    Name = "web data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "web_data" {
  device_name = "/dev/xvdc"
  volume_id   = aws_ebs_volume.web_data.id
  instance_id = aws_instance.main.id
}

resource "aws_ebs_volume" "database" {
  availability_zone = "ap-southeast-2b"
  size              = 30
  final_snapshot    = true
  type              = "gp3"

  tags = {
    Name = "database"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "database" {
  device_name = "/dev/xvdd"
  volume_id   = aws_ebs_volume.database.id
  instance_id = aws_instance.main.id
}

resource "aws_instance" "main" {
  lifecycle {
    ignore_changes = [ami]
  }

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
    domain_name        = "lenqua.link"
    data_block_dev     = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(aws_ebs_volume.data.id, "vol-")}"
    web_data_block_dev = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(aws_ebs_volume.web_data.id, "vol-")}"
    database_block_dev = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(aws_ebs_volume.database.id, "vol-")}"
    data_volume_id     = aws_ebs_volume.data.id
    private_cidr       = aws_subnet.private.cidr_block
    private_key        = tls_private_key.static_key.private_key_pem
    public_key         = tls_private_key.static_key.public_key_pem
    vpc_cidr           = aws_vpc.vpc.cidr_block
  })
}

module "nginx_config" {
  source     = "./service_config"
  depends_on = [aws_volume_attachment.data, aws_volume_attachment.web_data]
  for_each   = fileset("nginx", "*.conf")

  service_name    = "nginx"
  public_ip       = aws_instance.main.public_ip
  instance_id     = aws_instance.main.id
  config_path     = "/etc/nginx/conf.d/${each.value}"
  config_contents = file("nginx/${each.value}")
  post_start      = ["flock /var/tmp/terraform-certbot.lock sudo certbot --nginx -d ${trimsuffix(each.value, ".conf")} --non-interactive --agree-tos -m stewi1014@gmail.com"]
}

module "nfs_config" {
  source     = "./service_config"
  depends_on = [aws_volume_attachment.data, aws_volume_attachment.web_data]

  service_name    = "nfs-server"
  config_path     = "/etc/exports.d/data.exports"
  public_ip       = aws_instance.main.public_ip
  instance_id     = aws_instance.main.id
  config_contents = <<EOF
    /mnt/data/minecraft/vanilla/backups ${aws_vpc.vpc.cidr_block}(rw,sync)
  EOF
}

module "nftables_config" {
  source     = "./service_config"
  depends_on = [aws_volume_attachment.data, aws_volume_attachment.web_data]

  service_name    = "nftables"
  config_path     = "/etc/sysconfig/nftables.conf"
  public_ip       = aws_instance.main.public_ip
  instance_id     = aws_instance.main.id
  config_contents = <<EOF
    table ip nat {
      chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        ip saddr 10.0.0.0/16 oifname ens5 masquerade;
      }
    }
  EOF
}

module "mcproxy_config" {
  source     = "./service_config"
  depends_on = [aws_volume_attachment.data, aws_volume_attachment.web_data]

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
      shutdown_timeout     = 300
      ec2_server = {
        region      = "ap-southeast-2"
        instance_id = module.vanilla.instance_id
        hibernate   = false
      }
    }]
  })
}
