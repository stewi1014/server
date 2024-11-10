
module "vanilla" {
  source = "./mcserver"

  name         = "vanilla"
  volume_size  = 30
  vpc_id       = aws_vpc.vpc.id
  private_ip   = "10.0.0.5"
  subnet_id    = aws_subnet.private.id
  ssh_key_name = aws_key_pair.local_ssh_key.key_name
  known_hosts  = "git.lenqua.link ${tls_private_key.static_key.public_key_openssh}"
}

output "vanilla_public_ssh_key" {
  value = module.vanilla.public_ssh_key
}
