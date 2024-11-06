#cloud-config

hostname: minecraft

bootcmd:
  - while [ ! -e ${minecraft_block_dev} ]; do sleep 1; done
fs_setup:
  - device: ${minecraft_block_dev}
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
      After=network.target mnt-minecraft.mount mnt-backups.mount
      Requires=mnt-minecraft.mount mnt-backups.mount
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
      What=${minecraft_block_dev}
      Where=/mnt/minecraft

  - path: /etc/systemd/system/mnt-backups.mount
    content: |
      [Unit]
      Description=Mount backup storage
      [Mount]
      What=${data_nfs_ip}:/mnt/data/minecraft/${name}/backups
      Where=/mnt/backups
      Type=nfs
      Options=rw

runcmd:
  - systemctl daemon-reload
  - systemctl enable --now minecraft.service
