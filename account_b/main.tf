provider "aws" {
  region = "ap-south-1"
}

variable "account_a_id" {
  default = "976193256461"  
}

resource "aws_s3_bucket" "billing_bucket" {
  bucket         = "accountbillingreports01"  
  force_destroy  = true
}

resource "aws_s3_bucket_policy" "allow_account_a" {
  bucket = aws_s3_bucket.billing_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowAccountAFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_a_id}:root"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.billing_bucket.arn}",
          "${aws_s3_bucket.billing_bucket.arn}/*"
        ]
      }
    ]
  })
}
