# TODO: dynmap s3 bucket

resource "aws_security_group" "allow_minecraft" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port        = 25565
    to_port          = 25565
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 25565
    to_port          = 25565
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
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
    Name = "Minecraft Server"
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

resource "aws_instance" "minecraft" {
  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  ami                    = data.aws_ami.arm.id
  instance_type          = "t4g.xlarge"
  vpc_security_group_ids = [aws_security_group.allow_vpc_ssh_egress.id, aws_security_group.allow_minecraft.id]
  subnet_id              = aws_subnet.subnet.id
  availability_zone      = "ap-southeast-2b"
  key_name               = aws_key_pair.local_ssh_key.key_name

  tags = {
    Name = "Minecraft"
  }

  user_data_replace_on_change = true
  user_data = templatefile("minecraft.yml.tpl", {
    minecraft_volume_id = aws_ebs_volume.minecraft.id
    domain_name         = "vanilla.lenqua.link"
    private_key         = tls_private_key.minecraft.private_key_pem
    public_key          = tls_private_key.minecraft.public_key_pem
  })
}
