
module "vanilla" {
  source = "./mcserver"

  name         = "vanilla"
  vpc_id       = aws_vpc.vpc.id
  private_ip   = "10.0.0.5"
  main_nfs_ip  = local.main_private_ip
  subnet_id    = aws_subnet.private.id
  ssh_key_name = aws_key_pair.local_ssh_key.key_name
}
