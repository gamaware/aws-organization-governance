# Reference existing AWS Organization (read-only)
# Prerequisite: Enable SCPs first (see docs/prerequisites.md)
data "aws_organizations_organization" "org" {}
