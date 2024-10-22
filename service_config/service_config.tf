variable "service_name" {
  type = string
}

variable "instance_id" {
  type = string
}

variable "public_ip" {
  type = string
}

variable "config_path" {
  type = string
}

variable "config_contents" {
  type = string
}

resource "terraform_data" "mcproxyconfig" {
  triggers_replace = [var.config_contents, var.instance_id]

  connection {
    host        = var.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "sudo mkdir -p $(dirname ${var.config_path})"
    ]
  }
  provisioner "file" {
    content     = var.config_contents
    destination = var.config_path
  }
  provisioner "remote-exec" {
    inline = ["sudo systemctl restart ${var.service_name}"]
  }
}
