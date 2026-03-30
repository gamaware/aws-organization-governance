regions:
  - us-east-1
  - global

blocklist:
  - "557690606827"
  - "567209320893"
  - "626635444569"
  - "571600856221"
  - "222634394903"

resource-types:
  excludes:
    # Exclude all IAM — too many AWS-managed roles with unique names that
    # cannot be pattern-filtered safely. The AI verification scan catches
    # any student-created IAM resources as a second pass.
    - IAMGroup
    - IAMGroupPolicy
    - IAMGroupPolicyAttachment
    - IAMInstanceProfile
    - IAMInstanceProfileRole
    - IAMLoginProfile
    - IAMOpenIDConnectProvider
    - IAMPolicy
    - IAMRole
    - IAMRolePermissionsBoundary
    - IAMRolePolicy
    - IAMRolePolicyAttachment
    - IAMSAMLProvider
    - IAMServerCertificate
    - IAMServiceSpecificCredential
    - IAMSigningCertificate
    - IAMUser
    - IAMUserAccessKey
    - IAMUserGroupAttachment
    - IAMUserMFADevice
    - IAMUserPolicy
    - IAMUserPolicyAttachment
    - IAMUserSSHPublicKey
    - IAMVirtualMFADevice
    # Never touch org/SSO resources
    - OpsWorksUserProfile
    # Never touch audit and config resources
    - CloudTrailTrail
    - ConfigServiceConfigRule
    - ConfigServiceConfigurationRecorder
    - ConfigServiceDeliveryChannel
    # Never touch the cleanup infrastructure itself
    - SFNStateMachine
    - SFNActivity
    - CodeBuildProject
    - SchedulerSchedule
    - SchedulerScheduleGroup

# aws-nuke scans all non-excluded resource types.
# Filters below KEEP (protect) matching resources from deletion.
# Everything not matching a filter or exclusion gets deleted.
accounts:
  "${account_id}":
    filters:
      # Protect cleanup infrastructure
      LambdaFunction:
        - type: contains
          value: "cleanup-"
        - type: contains
          value: "quicksuite"
      LambdaLayer:
        - type: contains
          value: "quicksuite"
      S3Bucket:
        - type: contains
          value: "dev-cleanup-reports"
        - type: contains
          value: "terraform-state"
        - type: contains
          value: "cdk-"
      S3Object:
        - type: glob
          value: "*"
      SNSTopic:
        - type: contains
          value: "cleanup-notifications"
      SNSSubscription:
        - type: glob
          value: "*"
      KMSKey:
        - type: glob
          value: "*"
      KMSAlias:
        - type: glob
          value: "*"

      # Protect CloudWatch resources for cleanup and AWS-managed
      CloudWatchLogsLogGroup:
        - type: contains
          value: "/aws/codebuild/resource-cleanup"
        - type: contains
          value: "/aws/lambda/cleanup-"
        - type: contains
          value: "/aws/lambda/quicksuite"

      # Protect default VPC resources
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
        - property: DefaultVPC
          value: "true"
      EC2InternetGatewayAttachment:
        - property: DefaultVPC
          value: "true"
      EC2SecurityGroup:
        - property: Name
          value: "default"

      # Protect CloudFormation stacks (AWS-managed)
      CloudFormationStack:
        - type: contains
          value: "quicksuite"
        - type: contains
          value: "CDKToolkit"

      # Protect EventBridge rules (AWS-managed and Step Functions)
      CloudWatchEventsRule:
        - type: contains
          value: "StepFunctions"
        - type: contains
          value: "AutoScaling"
        - type: contains
          value: "EKSCompute"
        - type: contains
          value: "DO-NOT-DELETE"
        - type: contains
          value: "quicksuite"
      CloudWatchEventsTarget:
        - type: contains
          value: "StepFunctions"
        - type: contains
          value: "AutoScaling"
        - type: contains
          value: "EKSCompute"
        - type: contains
          value: "DO-NOT-DELETE"
        - type: contains
          value: "quicksuite"

      # Protect ECS default resources
      ECSCapacityProvider:
        - type: glob
          value: "*"
      ECSTaskDefinition:
        - property: Status
          value: "INACTIVE"

      # Protect ElastiCache defaults
      ElasticacheCacheParameterGroup:
        - type: contains
          value: "default."
      ElasticacheSubnetGroup:
        - type: contains
          value: "default"
      ElasticacheUser:
        - property: UserName
          value: "default"

      # Protect RDS defaults
      RDSDBParameterGroup:
        - type: contains
          value: "default."
      RDSOptionGroup:
        - type: contains
          value: "default:"
      RDSDBSubnetGroup:
        - type: contains
          value: "default-"

      # Protect DocumentDB defaults
      DocDBSubnetGroup:
        - type: contains
          value: "default-"

      # Protect EC2 network ACLs (default)
      EC2NetworkACL:
        - type: glob
          value: "*"

      # Protect Resource Explorer
      ResourceExplorer2Index:
        - type: glob
          value: "*"

      # Protect ECR repos used by CDK
      ECRRepository:
        - type: contains
          value: "cdk-"
