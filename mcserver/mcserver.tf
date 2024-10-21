# TODO: dynmap s3 bucket

variable "name" {
  type = string
}

variable "domains" {
  type = list(string)
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

variable "ec2_iam_policy" {
  type = string
}

resource "tls_private_key" "minecraft" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_ebs_volume" "minecraft" {
  availability_zone = "ap-southeast-2b"
  size              = 20
  final_snapshot    = true

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

data "aws_ami" "arm" {
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

resource "aws_iam_policy" "minecraft" {
  name   = "minecraft_${var.name}"
  policy = var.ec2_iam_policy
}

resource "aws_iam_policy_attachment" "minecraft" {
  name       = "minecraft_${var.name}"
  roles      = [aws_iam_role.minecraft.name]
  policy_arn = aws_iam_policy.minecraft.arn
}

resource "aws_iam_role" "minecraft" {
  name               = "minecraft_${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "minecraft" {
  name = "minecraft_${var.name}"
  role = aws_iam_role.minecraft.name
}

resource "aws_instance" "minecraft" {
  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  ami                    = data.aws_ami.arm.id
  instance_type          = "t4g.large"
  vpc_security_group_ids = [aws_security_group.minecraft.id]
  subnet_id              = var.subnet_id
  private_ip             = var.private_ip
  iam_instance_profile   = aws_iam_instance_profile.minecraft.name

  tags = {
    Name = "Minecraft ${var.name}"
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/mcserver.yml.tpl", {
    minecraft_volume_id = aws_ebs_volume.minecraft.id
    private_key         = tls_private_key.minecraft.private_key_pem
    public_key          = tls_private_key.minecraft.public_key_pem
  })
}

output "instance_id" {
  value = aws_instance.minecraft.id
}

output "domains" {
  value = var.domains
}

output "private_ip" {
  value = aws_instance.minecraft.private_ip
}
