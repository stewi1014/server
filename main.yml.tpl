#cloud-config

hostname: lenqua
fqdn: ${domain_name}

write_files:
  - path: /opt/mcproxy/config.json
    content: |
      ${indent(6, mcproxy_config)}

  - path: /etc/systemd/system/mcproxy.service
    content: |
      [Unit]
      Description=MCproxy
      After=network.target

      [Install]
      WantedBy=multi-user.target

      [Service]
      ExecStart=/opt/mcproxy/mcproxy
      WorkingDirectory=/opt/mcproxy

ssh_keys:
  rsa_private: |
    ${indent(4, private_key)}
  rsa_public: |
    ${indent(4, public_key)}

runcmd:
  - wget https://github.com/stewi1014/mcproxy/releases/download/v0.0/mcproxy_arm64 -O /opt/mcproxy/mcproxy
  - chmod +x /opt/mcproxy/mcproxy
  - systemctl daemon-reload
  - systemctl enable mcproxy.service
  - systemctl start mcproxy.service
