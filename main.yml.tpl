#cloud-config

hostname: lenqua
fqdn: ${domain_name}

ssh_keys:
  rsa_private: |
    ${indent(4, private_key)}
  rsa_public: |
    ${indent(4, public_key)}
