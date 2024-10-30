#cloud-config

hostname: lenqua
fqdn: ${domain_name}

bootcmd:
  - while [ ! -e ${data_block_dev} ]; do sleep 1; done
  - while [ ! -e ${web_data_block_dev} ]; do sleep 1; done
fs_setup:
  - device: ${data_block_dev}
    filesystem: ext4
  - device: ${web_data_block_dev}
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

  - path: /etc/systemd/system/mnt-data.mount
    content: |
      [Unit]
      Description=Mount main storage
      [Install]
      WantedBy=multi-user.target
      [Mount]
      What=${data_block_dev}
      Where=/mnt/data
      Type=ext4
      TimeoutSec=1800

  - path: /etc/systemd/system/var-www-html.mount
    content: |
      [Unit]
      Description=Mount web storage
      [Install]
      WantedBy=multi-user.target
      [Mount]
      What=${web_data_block_dev}
      Where=/var/www/html

  - path: /etc/php-fpm.d/www.conf
    content: |
      [www]
      listen = /var/run/php-fpm/php-fpm.sock
      listen.owner = nginx
      listen.group = nginx
      pm = ondemand
      pm.max_children = 40
      user = ec2-user

  - path: /etc/letsencrypt/cli.ini
    content: |
      preconfigured-renewal = True
      max-log-backups = 0
      config-dir = /mnt/data/letsencrypt

  - path: /etc/systemd/system/postgresql.service.d/override.conf
    content: |
      [Unit]
      Requires=mnt-data.mount
      [Service]
      Environment=PGDATA=/mnt/data/postgres

packages:
  - nftables
  - certbot
  - python3-certbot-nginx
  - nginx
  - nfs-utils
  - php8.3-fpm
  - php8.3-pdo
  - php8.3-pgsql
  - postgresql16-server

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
  - mkdir -p /var/www/html/minecraft/vanilla
  - chown ec2-user:ec2-user /var/www/html/minecraft/vanilla
  - certbot --nginx -d vanilla.lenqua.link -d lenqua.link -d map.scarzone.online --non-interactive --agree-tos -m stewi1014@gmail.com
  - systemctl enable --now php-fpm
  - systemctl enable --now certbot-renew.timer
  - systemctl enable --now postgresql
