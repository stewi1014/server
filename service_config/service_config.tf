variable "service_name" {
  type = string
}

variable "aws_instance" {
  type = aws_instance
}


variable "config_path" {
  type = string
}

variable "config_contents" {
  type = string
}

resource "terraform_data" "mcproxyconfig" {
  triggers_replace = var.config_contents
  lifecycle { replace_triggered_by = [var.aws_instance.main] }

  connection {
    host        = var.aws_instance.main.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.config_path}"]
  }
  provisioner "file" {
    content     = var.config_contents
    destination = var.config_path
  }
  provisioner "remote-exec" {
    inline = ["sudo systemctl restart ${var.service_name}"]
  }
}
