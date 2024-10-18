module "vanilla" {
  source = "./mcserver"

  name       = "vanilla"
  domains    = ["vanilla.lenqua.link", "minecraft.scarzone.online"]
  vpc_id     = aws_vpc.vpc.id
  private_ip = "10.0.0.5"
  subnet_id  = aws_subnet.private.id
}
