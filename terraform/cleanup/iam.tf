# CodeBuild execution role — runs aws-nuke
resource "aws_iam_role" "codebuild_execution" {
  name = "cleanup-codebuild-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codebuild.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_cleanup" {
  name = "ResourceCleanupPermissions"
  role = aws_iam_role.codebuild_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowResourceDeletion"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:TerminateInstances",
          "ec2:DeleteVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeregisterImage",
          "ec2:DeleteSecurityGroup",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteRoute",
          "ec2:DisassociateRouteTable",
          "ec2:ReleaseAddress",
          "ec2:DisassociateAddress",
          "ec2:DeleteNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:DeleteKeyPair",
          "ec2:DeleteVpcEndpoints",
          "rds:Describe*",
          "rds:DeleteDBInstance",
          "rds:DeleteDBCluster",
          "rds:DeleteDBSnapshot",
          "rds:DeleteDBClusterSnapshot",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketTagging",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket",
          "lambda:List*",
          "lambda:GetFunction",
          "lambda:DeleteFunction",
          "dynamodb:List*",
          "dynamodb:DescribeTable",
          "dynamodb:DeleteTable",
          "ecs:List*",
          "ecs:Describe*",
          "ecs:DeleteCluster",
          "ecs:DeleteService",
          "ecs:UpdateService",
          "ecs:DeregisterTaskDefinition",
          "ecr:Describe*",
          "ecr:DeleteRepository",
          "ecr:BatchDeleteImage",
          "ecr:ListTagsForResource",
          "elasticache:Describe*",
          "elasticache:DeleteCacheCluster",
          "elasticache:DeleteReplicationGroup",
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "apigateway:GET",
          "apigateway:DELETE",
          "sqs:List*",
          "sqs:GetQueueAttributes",
          "sqs:DeleteQueue",
          "sns:List*",
          "sns:GetTopicAttributes",
          "sns:DeleteTopic",
          "events:List*",
          "events:Describe*",
          "events:DeleteRule",
          "events:RemoveTargets",
          "cognito-idp:List*",
          "cognito-idp:Describe*",
          "cognito-idp:DeleteUserPool",
          "logs:Describe*",
          "logs:DeleteLogGroup",
          "cloudformation:List*",
          "cloudformation:Describe*",
          "cloudformation:DeleteStack",
          "route53:List*",
          "route53:GetHostedZone",
          "route53:DeleteHostedZone",
          "route53:ChangeResourceRecordSets",
          "cloudfront:List*",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:DeleteDistribution",
          "cloudfront:UpdateDistribution",
          "secretsmanager:List*",
          "secretsmanager:DescribeSecret",
          "secretsmanager:DeleteSecret",
          "states:List*",
          "states:DescribeStateMachine",
          "states:DeleteStateMachine",
          "tag:GetResources",
          "tag:GetTagKeys",
          "tag:GetTagValues"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3Reports"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        Resource = [
          "arn:aws:s3:::dev-cleanup-reports-${var.account_id}/*",
          "arn:aws:s3:::dev-cleanup-reports-${var.account_id}"
        ]
      },
      {
        Sid    = "AllowCodeBuildLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      },
      {
        Sid    = "AllowKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyIdentityAndAudit"
        Effect   = "Deny"
        Action   = ["iam:*", "organizations:*", "sso:*", "sso-admin:*", "cloudtrail:*"]
        Resource = "*"
      }
    ]
  })
}

# Lambda execution role — AI verification
resource "aws_iam_role" "lambda_execution" {
  name = "cleanup-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_verify" {
  name = "AIVerifyPermissions"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadInventory"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "rds:Describe*",
          "s3:ListAllMyBuckets",
          "s3:GetBucketTagging",
          "lambda:List*",
          "dynamodb:List*",
          "dynamodb:DescribeTable",
          "ecs:List*",
          "ecs:Describe*",
          "ecr:Describe*",
          "ecr:ListTagsForResource",
          "elasticache:Describe*",
          "elasticloadbalancing:Describe*",
          "apigateway:GET",
          "sqs:List*",
          "sqs:GetQueueAttributes",
          "sns:List*",
          "sns:GetTopicAttributes",
          "events:List*",
          "cognito-idp:List*",
          "logs:Describe*",
          "cloudformation:List*",
          "cloudformation:Describe*",
          "route53:List*",
          "cloudfront:List*",
          "secretsmanager:List*",
          "states:List*",
          "tag:GetResources"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowXRay"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowBedrock"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.*",
          "arn:aws:bedrock:*:*:inference-profile/us.anthropic.*"
        ]
      },
      {
        Sid      = "AllowS3Reports"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::dev-cleanup-reports-${var.account_id}/*"
      },
      {
        Sid      = "AllowSNS"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "*"
      },
      {
        Sid    = "AllowLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:*"
      }
    ]
  })
}

# Step Functions execution role
resource "aws_iam_role" "step_functions_execution" {
  name = "cleanup-stepfunctions-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "states.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_functions_orchestration" {
  name = "CleanupOrchestration"
  role = aws_iam_role.step_functions_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodeBuild"
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = "arn:aws:codebuild:${var.aws_region}:${var.account_id}:project/resource-cleanup"
      },
      {
        Sid      = "AllowLambda"
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:cleanup-ai-verify"
      },
      {
        Sid      = "AllowSNS"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = "*"
      },
      {
        Sid      = "AllowActivity"
        Effect   = "Allow"
        Action   = ["states:GetActivityTask"]
        Resource = "*"
      },
      {
        Sid      = "AllowEvents"
        Effect   = "Allow"
        Action   = "events:*"
        Resource = "*"
      },
    ]
  })
}

# EventBridge Scheduler execution role
resource "aws_iam_role" "scheduler_execution" {
  name = "cleanup-scheduler-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "scheduler.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "InvokeStepFunctions"
  role = aws_iam_role.scheduler_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = "arn:aws:states:${var.aws_region}:${var.account_id}:stateMachine:resource-cleanup"
      }
    ]
  })
}
