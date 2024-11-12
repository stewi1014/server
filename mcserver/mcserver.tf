# TODO: dynmap s3 bucket

variable "name" {
  type = string
}

variable "volume_size" {
  type = number
}

variable "vpc_id" {
  type = string
}

variable "private_ip" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "ssh_key_name" {
  type = string
}

variable "known_hosts" {
  type = string
}

resource "aws_ebs_volume" "minecraft" {
  availability_zone = "ap-southeast-2b"
  size              = var.volume_size
  final_snapshot    = true
  type              = "gp3"

  tags = {
    Name = var.name
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "minecraft" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.minecraft.id
  instance_id = aws_instance.minecraft.id
}

resource "aws_security_group" "minecraft" {
  vpc_id = var.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
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

data "aws_ami" "minecraft" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "tls_private_key" "host_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "user_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_instance" "minecraft" {
  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  ami                    = data.aws_ami.minecraft.id
  instance_type          = "c7g.medium"
  vpc_security_group_ids = [aws_security_group.minecraft.id]
  subnet_id              = var.subnet_id
  private_ip             = var.private_ip
  key_name               = var.ssh_key_name

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name = "Minecraft ${var.name}"
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/mcserver.yml.tpl", {
    name                = var.name
    minecraft_block_dev = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(aws_ebs_volume.minecraft.id, "vol-")}"
    known_hosts         = var.known_hosts
    host_private_key    = tls_private_key.host_key.private_key_pem
    host_public_key     = tls_private_key.host_key.public_key_pem
    user_private_key    = tls_private_key.user_key.private_key_pem
    user_public_key     = tls_private_key.user_key.public_key_pem
  })
}

output "instance_id" {
  value = aws_instance.minecraft.id
}

output "private_ip" {
  value = aws_instance.minecraft.private_ip
}

output "public_ssh_key" {
  value = tls_private_key.user_key.public_key_openssh
}
