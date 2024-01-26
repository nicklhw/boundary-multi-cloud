#data "aws_iam_policy_document" "trust_policy" {
#  statement {
#    sid     = "HCPLogStreaming"
#    effect  = "Allow"
#    actions = ["sts:AssumeRole"]
#    principals {
#      identifiers = ["711430482607"]
#      type        = "AWS"
#    }
#    condition {
#      test     = "StringEquals"
#      variable = "sts:ExternalId"
#      values = [
#        "f6c3914e7225434d8cc45e3cb41602e2c63dbf8a6c1c42b1b35acb4a05e352c5"
#      ]
#    }
#  }
#}
#
#resource "aws_iam_role" "role" {
#  name                = "hcp-log-streaming"
#  description         = "iam role that allows hcp to send logs to cloudwatch logs"
#  assume_role_policy  = data.aws_iam_policy_document.trust_policy.json
#  managed_policy_arns = [data.aws_iam_policy.demo_user_permissions_boundary.arn]
#}