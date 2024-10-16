#cloud-config

hostname: minecraft
fqdn: ${domain_name}

swap:
  filename: swapfile
  size: auto
  max_size: 8000000000

bootcmd:
  - while [ ! -e ${block_dev} ]; do sleep 1; done

disk_setup:
  ${block_dev}:
    table_type: gpt
    layout: true

fs_setup:
  - label: minecraft
    device: ${block_dev}1
    filesystem: xfs

mounts:
  - [LABEL=minecraft, /opt/minecraft, "auto", "defaults,nofail", "0", "0"]

packages:
  - java

ssh_keys:
  rsa_private: |
    ${indent(4, private_key)}
  rsa_public: |
    ${indent(4, public_key)}

write_files:
  - path: /etc/systemd/system/minecraft.service
    content: |
      ${indent(6, minecraft_service)}

runcmd:
  - [systemctl, daemon-reload]
  - [systemctl, enable, minecraft.service]
  - [systemctl, start, minecraft.service]
