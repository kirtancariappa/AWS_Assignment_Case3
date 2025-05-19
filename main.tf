provider "aws" {
  region  = "ap-south-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "cloudtrail-logs-iam-monitoring"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck",
        Effect    = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "iam_trail" {
  name                          = "iam-activity-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}

resource "aws_sns_topic" "iam_alerts" {
  name = "iam-activity-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.iam_alerts.arn
  protocol  = "email"
  endpoint  = "kscariappa25@gmail.com"
}

resource "aws_cloudwatch_log_group" "iam_logs" {
  name              = "/aws/cloudtrail/iam-logs"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_metric_filter" "unauthorized" {
  name           = "UnauthorizedAPICalls"
  log_group_name = aws_cloudwatch_log_group.iam_logs.name
  pattern        = "{($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")}" 

  metric_transformation {
    name      = "UnauthorizedCalls"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_alarm" {
  alarm_name          = "UnauthorizedAPICallsAlarm"
  metric_name         = aws_cloudwatch_log_metric_filter.unauthorized.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.unauthorized.metric_transformation[0].namespace
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.iam_alerts.arn]
}
