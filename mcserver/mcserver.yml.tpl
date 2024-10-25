#cloud-config

hostname: minecraft

bootcmd:
  - while [ ! -e /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(minecraft_volume_id, "vol-")} ]; do sleep 1; done
fs_setup:
  - device: /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(minecraft_volume_id, "vol-")}
    filesystem: ext4

swap:
  filename: /swapfile
  size: 2000000000

packages:
  - java
  - git
  - git-lfs
  - libwebp-tools
  - nfs-utils

ssh_keys:
  rsa_private: |
    ${indent(4, host_private_key)}
  rsa_public: |
    ${indent(4, host_public_key)}

write_files:
  - path: /etc/systemd/system/minecraft.service
    content: |
      [Unit]
      Description=Minecraft Server
      After=network.target mnt-minecraft.mount mnt-main.mount
      Requires=mnt-minecraft.mount mnt-main.mount
      [Install]
      WantedBy=multi-user.target
      [Service]
      User=ec2-user
      Group=ec2-user
      Restart=always
      WorkingDirectory=/mnt/minecraft/server
      ExecStart=/usr/bin/screen -DmS minecraft /mnt/minecraft/server/start.sh
      ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'
      ExecStop=/bin/bash -c "while ps -p $MAINPID > /dev/null; do /bin/sleep 1; done"

  - path: /etc/systemd/system/mnt-minecraft.mount
    content: |
      [Unit]
      Description=Mount minecraft partition
      [Mount]
      What=/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(minecraft_volume_id, "vol-")}
      Where=/mnt/minecraft
      Owner=ec2-user
      Options=defaults,noatime

  - path: /etc/systemd/system/mnt-main.mount
    content: |
      [Unit]
      Description=Mount website directory for dynmap
      [Mount]
      What=${main_nfs_ip}:/mnt/main
      Where=/mnt/main
      Type=nfs
      Options=rw

runcmd:
  - systemctl daemon-reload
  - systemctl enable --now minecraft.service
