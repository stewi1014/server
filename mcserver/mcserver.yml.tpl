#cloud-config

hostname: minecraft

bootcmd:
  - while [ ! -e /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(minecraft_volume_id, "vol-")} ]; do sleep 1; done
fs_setup:
  - device: /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(minecraft_volume_id, "vol-")}
    filesystem: ext4

packages:
  - java
  - git
  - git-lfs
  - libwebp-tools

ssh_keys:
  rsa_private: |
    ${indent(4, private_key)}
  rsa_public: |
    ${indent(4, public_key)}

write_files:
  - path: /etc/systemd/system/minecraft.service
    content: |
      [Unit]
      Description=Minecraft Server
      After=network.target opt-minecraft.mount
      [Install]
      WantedBy=multi-user.target
      [Service]
      Restart=always
      WorkingDirectory=/opt/minecraft
      ExecStart=/usr/bin/screen -DmS minecraft /opt/minecraft/start.sh
      ExecStop=/usr/bin/screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'
      ExecStop=/bin/bash -c "while ps -p $MAINPID > /dev/null; do /bin/sleep 1; done"

  - path: /etc/systemd/system/opt-minecraft.mount
    content: |
      [Unit]
      Description=Mount minecraft partition
      [Mount]
      What=/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${trimprefix(minecraft_volume_id, "vol-")}
      Where=/opt/minecraft
      Options=defaults,noatime

runcmd:
  - systemctl daemon-reload
  - systemctl enable --now minecraft.service
