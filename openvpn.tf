locals {
    openvpn_clients = [
        "ekho",
        "snider"
    ]
}

module "openvpn_config" {
  source          = "./service_config"
  service_name    = "openvpn@lenqua.conf"
  instance_id     = aws_instance.main.id
  public_ip       = aws_instance.main.public_ip
  config_path     = "/etc/openvpn/server/lenqua.conf"
  config_contents = <<EOF

port 1194
proto udp
dev tap

<ca>
${}
</ca>

<cert>

</cert>

<key>

</key>

EOF
}
