#cloud-config

hostname: lenqua
fqdn: ${domain_name}

bootcmd:
  - while [ ! -e /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(main_volume_id, "vol-")} ]; do sleep 1; done
fs_setup:
  - device: /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(main_volume_id, "vol-")}
    filesystem: ext4

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

  - path: /etc/systemd/system/mnt-main.mount
    content: |
      [Unit]
      Description=Mount main storage
      [Install]
      WantedBy=multi-user.target
      [Mount]
      What=/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(main_volume_id, "vol-")}
      Where=/mnt/main
      Options=defaults,noatime

  - path: /etc/exports.d/main_storage.exports
    content: |
      /mnt/main ${vpc_cidr}(rw,sync,no_subtree_check)

  ${indent(2, nginx_configs)}

packages:
  - nftables
  - certbot 
  - python3-certbot-nginx
  - nginx
  - nfs-utils

ssh_keys:
  rsa_private: |
    ${indent(4, private_key)}
  rsa_public: |
    ${indent(4, public_key)}

runcmd:
  - sysctl -w net.ipv4.ip_forward=1
  - mkdir -m 777 /opt/mcproxy
  - wget https://github.com/stewi1014/mcproxy/releases/download/v1.3/mcproxy_arm64 -O /opt/mcproxy/mcproxy
  - chmod +x /opt/mcproxy/mcproxy
  - systemctl daemon-reload
  - systemctl enable --now nfs-server
  - systemctl enable --now nftables
  - certbot --nginx -d vanilla.lenqua.link -d map.scarzone.online --non-interactive --agree-tos -m stewi1014@gmail.com
  - systemctl enable --now nginx
  - systemctl enable --now certbot-renew.timer
