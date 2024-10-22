
resource "aws_s3_bucket" "vanilla_dynmap" {
  bucket = "lenqua-vanilla-dynmap"
}

resource "aws_s3_bucket_cors_configuration" "vanilla_dynmap" {
  bucket = aws_s3_bucket.vanilla_dynmap.id

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["Content-Type", "ETag"]
  }
}

resource "aws_s3_bucket_public_access_block" "vanilla_dynmap" {
  bucket              = aws_s3_bucket.vanilla_dynmap.id
  block_public_acls   = false
  block_public_policy = false
}

resource "aws_s3_bucket_policy" "vanilla_dynmap_public_read" {
  bucket = aws_s3_bucket.vanilla_dynmap.id
  policy = data.aws_iam_policy_document.vanilla_dynmap_public_read.json
}

data "aws_iam_policy_document" "vanilla_dynmap_public_read" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.vanilla_dynmap.arn}",
      "${aws_s3_bucket.vanilla_dynmap.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_website_configuration" "vanilla_dynmap" {
  bucket = aws_s3_bucket.vanilla_dynmap.id
  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "images/blank.png"
  }
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
  name = "minecraft_vanilla"
}

resource "aws_iam_user_policy" "dynmap_vanilla" {
  name   = "minecraft_vanilla"
  user   = aws_iam_user.dynmap_vanilla.name
  policy = data.aws_iam_policy_document.dynmap_vanilla.json
}

resource "aws_iam_access_key" "dynmap_vanilla_key" {
  user = aws_iam_user.dynmap_vanilla.name
}

output "vanilla_dynmap_key_id" {
  value = aws_iam_access_key.dynmap_vanilla_key.id
}

output "vanilla_dynmap_key_secret" {
  sensitive = true
  value     = aws_iam_access_key.dynmap_vanilla_key.secret
}

module "vanilla" {
  source = "./mcserver"

  name           = "vanilla"
  domains        = ["vanilla.lenqua.link", "minecraft.scarzone.online"]
  vpc_id         = aws_vpc.vpc.id
  private_ip     = "10.0.0.5"
  subnet_id      = aws_subnet.private.id
  ec2_iam_policy = data.aws_iam_policy_document.dynmap_vanilla.json
  ssh_key_name   = aws_key_pair.local_ssh_key.key_name
}
