# Dev Account — Student Guide

## Overview

The Dev account is a shared AWS environment for final project
development. You have broad access to AWS services with guardrails
that prevent accidental cost overruns, data exposure, and resource
misuse.

This guide explains what you can and can't do, and how to work
within the restrictions.

## Required Tags

Every EC2 instance, RDS database, Lambda function, and S3 bucket
you create **must** have these two tags:

| Tag    | Value            | Example             |
|--------|------------------|---------------------|
| `Team` | Your team number | `team-3`            |
| `Name` | Your ITESO email | `al123456@iteso.mx` |

Valid team values: `team-1` through `team-7`

**If you forget either tag, the resource creation will be denied.**

### How to tag resources

**AWS Console:** Fill in the "Tags" section when creating any
resource.

**AWS CLI example (EC2):**

```bash
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.micro \
  --tag-specifications \
    'ResourceType=instance,Tags=[
      {Key=Team,Value=team-3},
      {Key=Name,Value=al123456@iteso.mx}]' \
    'ResourceType=volume,Tags=[
      {Key=Team,Value=team-3},
      {Key=Name,Value=al123456@iteso.mx}]'
```

**Terraform example:**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abcdef1234567890"
  instance_type = "t3.micro"

  tags = {
    Team = "team-3"
    Name = "al123456@iteso.mx"
  }
}
```

## What You Can Do

You have PowerUser access. This means you can use virtually
any AWS service. Here are the services relevant to your
final projects:

### Compute

- EC2 instances (t2, t3, t3a, t4g families)
- Lambda functions
- ECS (Fargate and EC2 launch type)
- Elastic Beanstalk

### Storage

- S3 buckets (with tags)
- EBS volumes (up to 100 GB)
- DynamoDB tables
- ElastiCache (Redis, Memcached)

### Databases

- RDS (MySQL, PostgreSQL, etc. — db.t2, db.t3, db.t4g)
- DynamoDB
- DocumentDB

### Networking

- VPCs, subnets, security groups
- Application Load Balancers
- API Gateway
- CloudFront distributions
- Route 53 (DNS)

### Application Services

- SQS (message queues)
- SNS (notifications)
- EventBridge
- Step Functions
- Cognito (authentication)
- CloudWatch (monitoring, logs)
- CloudFormation / Terraform

### Containers

- ECR (container registry)
- ECS (container orchestration)

## What You Cannot Do

### Blocked Instance Types

Only burstable instances are allowed:

- **EC2:** t2, t3, t3a, t4g families only
- **RDS:** db.t2, db.t3, db.t4g families only
- **GPU/Metal instances:** All blocked (p, g, inf, trn, dl,
  metal)

You cannot modify an RDS instance to an expensive class
after creation.

### Blocked Services

- Lightsail
- GameLift
- AWS Marketplace subscriptions (paid AMIs/SaaS)
- SageMaker (except ml.t2, ml.t3 instances)

### Storage Limits

- EBS volumes: 100 GB maximum per volume

### Security Restrictions

- Cannot make S3 buckets public (public access block
  cannot be removed)
- Cannot share RDS/EC2 snapshots publicly
- Cannot attach AdministratorAccess or IAMFullAccess
  policies
- Cannot use the root user
- Cannot delete or modify CloudTrail
- Cannot purchase Reserved Instances

### Account Restrictions

- Region: us-east-1 only
- Cannot leave the AWS Organization

## Project Compatibility

These restrictions are designed to support all final
project types:

| Project           | Key Services                 |
|-------------------|------------------------------|
| URL Shortener     | API GW, Lambda, DynamoDB     |
| Web Crawler       | SQS, Lambda, S3, DynamoDB    |
| YouTube Clone     | S3, CloudFront, EC2, RDS     |
| Proximity Service | RDS/DynamoDB, Lambda, API GW |
| Friend Finder     | RDS, ElastiCache, API GW     |
| Hotel Reservation | RDS, SQS, Lambda, API GW     |
| Chat System       | API GW WS, Lambda, DynamoDB  |

All of these projects work within the allowed services
and instance types. If you hit a restriction that blocks
a legitimate use case, contact your instructor.

## Common Errors and Fixes

### "Access Denied" on resource creation

You're probably missing tags. Add both `Team` and `Name`
tags to your resource.

### "You are not authorized to perform this operation"

Check if you're trying to:

- Use a region other than us-east-1
- Launch a non-burstable instance type
- Create an EBS volume larger than 100 GB
- Attach an admin policy

### "The instance type is not supported"

You're trying to use a non-allowed instance type. Stick
to t2, t3, t3a, or t4g families.

## Tips

- **Use t3.micro or t3.small** for most workloads — they're
  sufficient for development and testing
- **Use DynamoDB** instead of RDS when possible — it's
  serverless and scales automatically
- **Use Lambda** for event-driven workloads — no servers
  to manage
- **Tag everything** — it helps track costs per team and
  makes cleanup easier at end of semester
- **Use CloudFormation or Terraform** — infrastructure as
  code makes it easy to tear down and recreate your
  environment
