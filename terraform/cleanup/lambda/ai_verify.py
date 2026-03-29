"""AI verification Lambda for post-cleanup account scan.

Runs two independent scans:
1. Tag-based: queries Resource Groups Tagging API for remaining team tags
2. Full inventory: calls 16 AWS APIs to get all resources

Sends both to Bedrock Opus 4.6 for CLEAN/NOT CLEAN verdict.
"""

import json
import os
from datetime import datetime, timezone

import boto3

REPORTS_BUCKET = os.environ["REPORTS_BUCKET"]
ACCOUNT_ID = os.environ["ACCOUNT_ID"]
TEAM_TAGS = json.loads(os.environ["TEAM_TAGS"])
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")
sns = boto3.client("sns")
tagging = boto3.client("resourcegroupstaggingapi")


def get_tagged_resources():
    """Scan 1: find all resources with team tags."""
    resources = []
    for team in TEAM_TAGS:
        paginator = tagging.get_paginator("get_resources")
        for page in paginator.paginate(
            TagFilters=[{"Key": "Team", "Values": [team]}]
        ):
            for r in page["ResourceTagMappingList"]:
                resources.append(
                    {"arn": r["ResourceARN"], "tags": {t["Key"]: t["Value"] for t in r["Tags"]}}
                )
    return resources


def get_full_inventory():
    """Scan 2: full account resource inventory via describe/list APIs."""
    inventory = {}

    clients = {
        "ec2": boto3.client("ec2"),
        "rds": boto3.client("rds"),
        "s3": boto3.client("s3"),
        "lambda": boto3.client("lambda"),
        "dynamodb": boto3.client("dynamodb"),
        "ecs": boto3.client("ecs"),
        "ecr": boto3.client("ecr"),
        "elbv2": boto3.client("elbv2"),
        "sqs": boto3.client("sqs"),
        "sns_client": boto3.client("sns"),
        "events": boto3.client("events"),
        "logs": boto3.client("logs"),
        "secretsmanager": boto3.client("secretsmanager"),
    }

    try:
        r = clients["ec2"].describe_instances(
            Filters=[{"Name": "instance-state-name", "Values": ["running", "stopped"]}]
        )
        inventory["ec2_instances"] = [
            i["InstanceId"]
            for res in r["Reservations"]
            for i in res["Instances"]
        ]
    except Exception:
        inventory["ec2_instances"] = []

    try:
        r = clients["ec2"].describe_volumes()
        inventory["ebs_volumes"] = [
            v["VolumeId"] for v in r["Volumes"]
        ]
    except Exception:
        inventory["ebs_volumes"] = []

    try:
        r = clients["ec2"].describe_vpcs(
            Filters=[{"Name": "isDefault", "Values": ["false"]}]
        )
        inventory["vpcs"] = [v["VpcId"] for v in r["Vpcs"]]
    except Exception:
        inventory["vpcs"] = []

    try:
        r = clients["ec2"].describe_security_groups()
        inventory["security_groups"] = [
            sg["GroupId"]
            for sg in r["SecurityGroups"]
            if sg["GroupName"] != "default"
        ]
    except Exception:
        inventory["security_groups"] = []

    try:
        r = clients["rds"].describe_db_instances()
        inventory["rds_instances"] = [
            db["DBInstanceIdentifier"] for db in r["DBInstances"]
        ]
    except Exception:
        inventory["rds_instances"] = []

    try:
        r = clients["s3"].list_buckets()
        inventory["s3_buckets"] = [
            b["Name"]
            for b in r["Buckets"]
            if "cleanup-reports" not in b["Name"]
            and "terraform-state" not in b["Name"]
        ]
    except Exception:
        inventory["s3_buckets"] = []

    try:
        r = clients["lambda"].list_functions()
        inventory["lambda_functions"] = [
            f["FunctionName"]
            for f in r["Functions"]
            if "cleanup-" not in f["FunctionName"]
        ]
    except Exception:
        inventory["lambda_functions"] = []

    try:
        r = clients["dynamodb"].list_tables()
        inventory["dynamodb_tables"] = r["TableNames"]
    except Exception:
        inventory["dynamodb_tables"] = []

    try:
        r = clients["ecs"].list_clusters()
        inventory["ecs_clusters"] = r["clusterArns"]
    except Exception:
        inventory["ecs_clusters"] = []

    try:
        r = clients["ecr"].describe_repositories()
        inventory["ecr_repositories"] = [
            repo["repositoryName"] for repo in r["repositories"]
        ]
    except Exception:
        inventory["ecr_repositories"] = []

    try:
        r = clients["elbv2"].describe_load_balancers()
        inventory["load_balancers"] = [
            lb["LoadBalancerName"] for lb in r["LoadBalancers"]
        ]
    except Exception:
        inventory["load_balancers"] = []

    try:
        r = clients["sqs"].list_queues()
        inventory["sqs_queues"] = r.get("QueueUrls", [])
    except Exception:
        inventory["sqs_queues"] = []

    try:
        r = clients["sns_client"].list_topics()
        inventory["sns_topics"] = [
            t["TopicArn"]
            for t in r["Topics"]
            if "cleanup-notifications" not in t["TopicArn"]
        ]
    except Exception:
        inventory["sns_topics"] = []

    try:
        r = clients["events"].list_rules()
        inventory["eventbridge_rules"] = [
            rule["Name"]
            for rule in r["Rules"]
            if "StepFunctions" not in rule["Name"]
        ]
    except Exception:
        inventory["eventbridge_rules"] = []

    try:
        r = clients["logs"].describe_log_groups()
        inventory["log_groups"] = [
            lg["logGroupName"]
            for lg in r["logGroups"]
            if "/aws/codebuild/resource-cleanup" not in lg["logGroupName"]
            and "/aws/lambda/cleanup-" not in lg["logGroupName"]
        ]
    except Exception:
        inventory["log_groups"] = []

    try:
        r = clients["secretsmanager"].list_secrets()
        inventory["secrets"] = [s["Name"] for s in r["SecretList"]]
    except Exception:
        inventory["secrets"] = []

    return inventory


def invoke_bedrock(tagged_resources, inventory):
    """Send both scans to Bedrock Opus 4.6 for analysis."""
    accepted_findings = ""
    try:
        import base64
        accepted_findings = base64.b64decode(
            os.environ.get("ACCEPTED_FINDINGS", "")
        ).decode("utf-8")
    except Exception:
        pass

    prompt = f"""You are auditing an AWS account after a resource cleanup operation.

## Context
- Account ID: {ACCOUNT_ID}
- Team tags targeted for deletion: {', '.join(TEAM_TAGS)}
- Infrastructure resources (cleanup infra, Terraform state, CloudTrail) should NOT be deleted

## Scan 1: Tagged Resources Still Present
These resources still have team tags after cleanup. If any exist, cleanup FAILED.

{json.dumps(tagged_resources, indent=2)}

## Scan 2: Full Account Inventory
All resources currently in the account (infrastructure excluded where possible):

{json.dumps(inventory, indent=2)}

## Previously Accepted Findings (skip these)
{accepted_findings}

## Your Task
1. Check Scan 1: are there ANY remaining tagged resources? If yes, cleanup failed.
2. Check Scan 2: are there resources that look student-created but lack tags?
3. Cross-reference both scans.

Respond with:
- **Verdict**: CLEAN or NOT CLEAN
- **Remaining resources**: list each with its ARN/ID and why it should be deleted
- **Remediation**: exact `aws` CLI commands to delete each remaining resource
- Skip any resources that are infrastructure (cleanup Lambda, CodeBuild, S3 state
  bucket, CloudTrail, IAM roles, etc.)
"""

    response = bedrock.invoke_model(
        modelId="us.anthropic.claude-opus-4-6-v1",
        contentType="application/json",
        accept="application/json",
        body=json.dumps(
            {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 8192,
                "messages": [{"role": "user", "content": prompt}],
            }
        ),
    )

    result = json.loads(response["body"].read())
    return result["content"][0]["text"]


def handler(event, context):
    """Lambda handler — runs both scans and invokes Bedrock."""
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    execution_id = event.get("execution_id", "manual")

    tagged = get_tagged_resources()
    inventory = get_full_inventory()
    analysis = invoke_bedrock(tagged, inventory)

    verdict = "CLEAN" if "CLEAN" in analysis.split("\n")[0].upper() and "NOT" not in analysis.split("\n")[0].upper() else "NOT CLEAN"

    report = {
        "timestamp": timestamp,
        "execution_id": execution_id,
        "verdict": verdict,
        "tagged_resources_remaining": len(tagged),
        "inventory_summary": {k: len(v) for k, v in inventory.items()},
        "ai_analysis": analysis,
    }

    s3.put_object(
        Bucket=REPORTS_BUCKET,
        Key=f"reports/{timestamp}/ai-analysis.json",
        Body=json.dumps(report, indent=2),
        ContentType="application/json",
    )

    return {"verdict": verdict, "tagged_remaining": len(tagged), "report_key": f"reports/{timestamp}/ai-analysis.json"}
