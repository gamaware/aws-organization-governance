# Enable Service Control Policies in the organization
resource "aws_organizations_organization" "org" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY"
  ]
}

# Dev OU Service Control Policy
resource "aws_organizations_policy" "dev_scp" {
  name        = "DevEnvironmentRestrictions"
  description = "Cost controls and security guardrails for Dev OU"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyAllOutsideUSEast1"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = "us-east-1"
          }
        }
      },
      {
        Sid    = "DenyCostlyEC2Instances"
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "ec2:StartInstances"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotLike = {
            "ec2:InstanceType" = [
              "t2.*",
              "t3.*",
              "t3a.*",
              "t4g.*"
            ]
          }
        }
      },
      {
        Sid    = "DenyCostlyRDSInstances"
        Effect = "Deny"
        Action = [
          "rds:CreateDBInstance",
          "rds:CreateDBCluster"
        ]
        Resource = "*"
        Condition = {
          StringNotLike = {
            "rds:DatabaseClass" = [
              "db.t2.*",
              "db.t3.*",
              "db.t4g.*"
            ]
          }
        }
      },
      {
        Sid      = "DenyLeavingOrganization"
        Effect   = "Deny"
        Action   = "organizations:LeaveOrganization"
        Resource = "*"
      },
      {
        Sid      = "DenyRootUserActions"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      },
      {
        Sid    = "DenyCloudTrailDeletion"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyReservedInstancePurchase"
        Effect = "Deny"
        Action = [
          "ec2:PurchaseReservedInstancesOffering",
          "rds:PurchaseReservedDBInstancesOffering",
          "elasticache:PurchaseReservedCacheNodesOffering",
          "redshift:PurchaseReservedNodeOffering",
          "dynamodb:PurchaseReservedCapacityOfferings"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "dev_scp_attachment" {
  policy_id = aws_organizations_policy.dev_scp.id
  target_id = "ou-srmc-f52jl8so"
}
