regions:
  - us-east-1
  - global

account-blocklist:
  - "557690606827"
  - "567209320893"
  - "626635444569"
  - "571600856221"
  - "222634394903"

# NOTE: aws-nuke deletes everything NOT matching a filter. The filters below
# protect infrastructure resources. All other resources (including student
# resources with team tags) are deleted. This means untagged non-infrastructure
# resources are also deleted. The AI verification step catches false positives.
accounts:
  "${account_id}":
    filters:
      IAMRole:
        - type: contains
          value: "AWSReservedSSO"
        - type: contains
          value: "AWSServiceRole"
        - type: contains
          value: "GitHubActions"
        - type: contains
          value: "OrganizationAccountAccessRole"
        - type: contains
          value: "cleanup-"
      IAMRolePolicy:
        - type: glob
          value: "*"
      IAMRolePolicyAttachment:
        - type: glob
          value: "*"
      IAMPolicy:
        - type: contains
          value: "aws-service-role"
      IAMInstanceProfile:
        - type: glob
          value: "*"
      IAMOpenIDConnectProvider:
        - type: glob
          value: "*"
      IAMSAMLProvider:
        - type: glob
          value: "*"
      CloudTrailTrail:
        - type: glob
          value: "*"
      EC2DefaultSecurityGroupRule:
        - type: glob
          value: "*"
      EC2DHCPOption:
        - type: glob
          value: "*"
      EC2VPC:
        - property: IsDefault
          value: "true"
      EC2Subnet:
        - property: DefaultForAz
          value: "true"
      EC2InternetGateway:
        - property: tag:ManagedBy
          value: "Terraform"
      SFNStateMachine:
        - type: contains
          value: "resource-cleanup"
      CodeBuildProject:
        - type: contains
          value: "resource-cleanup"
      LambdaFunction:
        - type: contains
          value: "cleanup-"
      S3Bucket:
        - type: contains
          value: "dev-cleanup-reports"
        - type: contains
          value: "terraform-state"
      SNSTopic:
        - type: contains
          value: "cleanup-notifications"
      SchedulerSchedule:
        - type: contains
          value: "resource-cleanup"
      CloudWatchLogsLogGroup:
        - type: contains
          value: "/aws/codebuild/resource-cleanup"
        - type: contains
          value: "/aws/lambda/cleanup-"
      ConfigServiceConfigRule:
        - type: glob
          value: "*"
      ConfigServiceConfigurationRecorder:
        - type: glob
          value: "*"
      ConfigServiceDeliveryChannel:
        - type: glob
          value: "*"
