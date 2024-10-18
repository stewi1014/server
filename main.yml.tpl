#cloud-config

hostname: lenqua
fqdn: ${domain_name}

write_files:
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

  - path: /etc/sysctl.d/90-ip-forward.conf
    content: |
      net.ipv4.ip_forward = 1

  - path: /etc/sysconfig/nftables.conf
    content: |
      table ip nat {
        chain postrouting {
          type nat hook postrouting priority 100; policy accept;
          ip saddr 10.0.0.0/16 oifname ens5 masquerade;
        }
      }

packages:
  - nftables

ssh_keys:
  rsa_private: |
    ${indent(4, private_key)}
  rsa_public: |
    ${indent(4, public_key)}

runcmd:
  - sysctl -w net.ipv4.ip_forward=1
  - mkdir -m 777 /opt/mcproxy
  - wget https://github.com/stewi1014/mcproxy/releases/download/v1.1/mcproxy_arm64 -O /opt/mcproxy/mcproxy
  - chmod +x /opt/mcproxy/mcproxy
  - systemctl daemon-reload
  - systemctl start nftables
  - systemctl enable nftables
  - systemctl enable mcproxy
