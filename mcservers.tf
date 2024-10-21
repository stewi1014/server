
resource "aws_s3_bucket" "vanilla_dynmap" {
  bucket = "lenqua-vanilla-dynmap"
}

resource "aws_s3_bucket_website_configuration" "vanilla_dynmap" {
  bucket = aws_s3_bucket.vanilla_dynmap.id
}

resource "aws_acm_certificate" "vanilla" {
  domain_name       = "vanilla.lenqua.link"
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }
}

data "aws_iam_policy_document" "dynmap_vanilla" {
  statement {
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user" "dynmap_vanilla" {
  name = "minecraft vanilla"
}

resource "aws_iam_user_policy" "dynmap_vanilla" {
  name   = "minecraft vanilla"
  user   = aws_iam_user.dynmap_vanilla.name
  policy = data.aws_iam_policy_document.vanilla.json
}

resource "aws_iam_access_key" "dynmap_vanilla_key" {
  user = aws_iam_user.dynmap_vanilla.name
}

output "vanilla_dynmap_key_id" {
  value = aws_iam_access_key.dynmap_vanilla_key.id
}

output "vanilla_dynmap_key_secret" {
  value = aws_iam_access_key.dynmap_vanilla_key.secret
}

resource "aws_route53_record" "vanilla" {
  for_each = {
    for dvo in aws_acm_certificate.vanilla.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.lenqua_link.zone_id
}

module "vanilla" {
  source = "./mcserver"

  name           = "vanilla"
  domains        = ["vanilla.lenqua.link", "minecraft.scarzone.online"]
  vpc_id         = aws_vpc.vpc.id
  private_ip     = "10.0.0.5"
  subnet_id      = aws_subnet.private.id
  ec2_iam_policy = data.aws_iam_policy_document.vanilla.json
}
