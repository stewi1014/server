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

variable "pre_start" {
  description = "Extra commands to run after configuration file is placed, but before service is started"
  type        = list(string)
  default     = []
}

variable "post_start" {
  description = "Extra commands to run after service is started"
  type        = list(string)
  default     = []
}

resource "terraform_data" "config" {
  triggers_replace = [var.config_contents, var.instance_id]
  input = {
    public_ip   = var.public_ip
    config_path = var.config_path
  }

  connection {
    host        = self.input.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "file" {
    content     = var.config_contents
    destination = "/tmp/${replace(self.input.config_path, "/", "_")}"
  }
  provisioner "remote-exec" {
    inline = flatten([
      "sudo cloud-init status --wait",
      "sudo mkdir -p $(dirname \"${self.input.config_path}\")",
      "sudo mv \"/tmp/${replace(self.input.config_path, "/", "_")}\" \"${self.input.config_path}\"",
      "sudo chown root:root \"${self.input.config_path}\"",
      var.pre_start,
      "sudo systemctl enable ${var.service_name}",
      "sudo systemctl restart ${var.service_name}",
      var.post_start
    ])
  }
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "sudo rm \"${self.input.config_path}\""
    ]
  }
}
