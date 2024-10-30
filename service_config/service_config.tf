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

resource "terraform_data" "config" {
  triggers_replace = [var.config_contents, var.instance_id]


  connection {
    host        = var.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "file" {
    content     = var.config_contents
    destination = "/tmp/${replace(var.config_path, "/", "_")}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "sudo mkdir -p $(dirname \"${var.config_path}\")",
      "sudo mv \"/tmp/${replace(var.config_path, "/", "_")}\" \"${var.config_path}\"",
      "sudo chown root:root \"${var.config_path}\"",
      "sudo systemctl enable ${var.service_name}",
      "sudo systemctl restart ${var.service_name}"
    ]
  }
}
