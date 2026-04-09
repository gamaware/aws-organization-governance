package test

import (
	"context"
	"regexp"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/organizations"
	orgtypes "github.com/aws/aws-sdk-go-v2/service/organizations/types"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// scpInfo holds the output key names and expected AWS policy name for a single SCP.
type scpInfo struct {
	idOutput   string
	arnOutput  string
	policyName string
}

// allSCPs returns the list of SCPs with their Terraform output keys and expected AWS names.
func allSCPs() []scpInfo {
	return []scpInfo{
		{idOutput: "dev_scp_id", arnOutput: "dev_scp_arn", policyName: "DevEnvironmentRestrictions"},
		{idOutput: "sso_protection_scp_id", arnOutput: "sso_protection_scp_arn", policyName: "ProtectSSOTrustedAccess"},
		{idOutput: "dev_tagging_scp_id", arnOutput: "dev_tagging_scp_arn", policyName: "DevTaggingEnforcement"},
		{idOutput: "dev_abuse_scp_id", arnOutput: "dev_abuse_scp_arn", policyName: "DevAbusePrevention"},
		{idOutput: "security_defaults_scp_id", arnOutput: "security_defaults_scp_arn", policyName: "SecurityDefaults"},
		{idOutput: "region_restriction_scp_id", arnOutput: "region_restriction_scp_arn", policyName: "RegionRestriction"},
	}
}

// TestSCPsOutputFormat validates that Terraform outputs match expected ARN and ID patterns.
func TestSCPsOutputFormat(t *testing.T) {
	t.Parallel()

	workingDir := getTerraformWorkingDir(t, "TF_WORKING_DIR", "../terraform/scps")
	opts := newTerraformOptions(t, workingDir)

	policyIDPattern := regexp.MustCompile(`^p-[a-z0-9]+$`)
	policyARNPattern := regexp.MustCompile(`^arn:aws:organizations::\d+:policy/o-[a-z0-9]+/service_control_policy/p-[a-z0-9]+$`)
	orgIDPattern := regexp.MustCompile(`^o-[a-z0-9]+$`)
	rootIDPattern := regexp.MustCompile(`^r-[a-z0-9]+$`)

	// Validate org-level outputs
	orgID := terraform.Output(t, opts, "organization_id")
	assert.Regexp(t, orgIDPattern, orgID, "organization_id should match o-[a-z0-9]+ pattern")

	rootID := terraform.Output(t, opts, "root_id")
	assert.Regexp(t, rootIDPattern, rootID, "root_id should match r-[a-z0-9]+ pattern")

	// Validate each SCP's ID and ARN format
	for _, scp := range allSCPs() {
		scp := scp
		t.Run(scp.policyName, func(t *testing.T) {
			t.Parallel()

			scpID := terraform.Output(t, opts, scp.idOutput)
			assert.Regexp(t, policyIDPattern, scpID, "%s should match p-[a-z0-9]+ pattern", scp.idOutput)

			scpARN := terraform.Output(t, opts, scp.arnOutput)
			assert.Regexp(t, policyARNPattern, scpARN, "%s should match SCP ARN pattern", scp.arnOutput)
		})
	}
}

// TestSCPsExist verifies that all 5 SCPs exist in AWS Organizations and have the correct type and name.
func TestSCPsExist(t *testing.T) {
	t.Parallel()

	workingDir := getTerraformWorkingDir(t, "TF_WORKING_DIR", "../terraform/scps")
	opts := newTerraformOptions(t, workingDir)
	region := getRegion(t)
	cfg := getAWSConfig(t, region)
	client := organizations.NewFromConfig(cfg)

	for _, scp := range allSCPs() {
		scp := scp
		t.Run(scp.policyName, func(t *testing.T) {
			t.Parallel()

			scpID := terraform.Output(t, opts, scp.idOutput)
			result, err := client.DescribePolicy(context.TODO(), &organizations.DescribePolicyInput{
				PolicyId: &scpID,
			})
			require.NoErrorf(t, err, "DescribePolicy failed for %s (%s)", scp.policyName, scpID)
			require.NotNil(t, result.Policy, "Policy should not be nil for %s", scp.policyName)
			require.NotNil(t, result.Policy.PolicySummary, "PolicySummary should not be nil for %s", scp.policyName)

			assert.Equal(t, orgtypes.PolicyTypeServiceControlPolicy, result.Policy.PolicySummary.Type,
				"SCP %s should be SERVICE_CONTROL_POLICY", scp.policyName)
			require.NotNil(t, result.Policy.PolicySummary.Name, "PolicySummary.Name should not be nil for %s", scp.policyName)
			assert.Equal(t, scp.policyName, *result.Policy.PolicySummary.Name,
				"SCP name mismatch for %s", scp.idOutput)
		})
	}
}

// TestSCPsAttachedCorrectly verifies that SCPs are attached to the correct organizational targets.
// Dev OU SCPs: dev_scp, dev_tagging, security_defaults
// Root SCPs: protect_sso, region_restriction
func TestSCPsAttachedCorrectly(t *testing.T) {
	t.Parallel()

	workingDir := getTerraformWorkingDir(t, "TF_WORKING_DIR", "../terraform/scps")
	opts := newTerraformOptions(t, workingDir)
	region := getRegion(t)
	cfg := getAWSConfig(t, region)
	client := organizations.NewFromConfig(cfg)

	rootID := terraform.Output(t, opts, "root_id")

	// Dev OU ID comes from a Terraform variable, read from environment
	devOUID := getTerraformWorkingDir(t, "TF_VAR_dev_ou_id", "")
	require.NotEmpty(t, devOUID, "TF_VAR_dev_ou_id environment variable is required")

	// Helper: list all SCP IDs attached to a target
	listAttachedSCPIDs := func(t *testing.T, targetID string) []string {
		t.Helper()
		var ids []string
		paginator := organizations.NewListPoliciesForTargetPaginator(client, &organizations.ListPoliciesForTargetInput{
			TargetId: &targetID,
			Filter:   orgtypes.PolicyTypeServiceControlPolicy,
		})
		for paginator.HasMorePages() {
			page, err := paginator.NextPage(context.TODO())
			require.NoError(t, err, "ListPoliciesForTarget failed for %s", targetID)
			for _, p := range page.Policies {
				ids = append(ids, *p.Id)
			}
		}
		return ids
	}

	t.Run("DevOU", func(t *testing.T) {
		t.Parallel()
		attachedIDs := listAttachedSCPIDs(t, devOUID)

		devSCPID := terraform.Output(t, opts, "dev_scp_id")
		assert.Contains(t, attachedIDs, devSCPID, "dev_scp should be attached to Dev OU")

		devTaggingID := terraform.Output(t, opts, "dev_tagging_scp_id")
		assert.Contains(t, attachedIDs, devTaggingID, "dev_tagging should be attached to Dev OU")

		secDefaultsID := terraform.Output(t, opts, "security_defaults_scp_id")
		assert.Contains(t, attachedIDs, secDefaultsID, "security_defaults should be attached to Dev OU")
	})

	t.Run("Root", func(t *testing.T) {
		t.Parallel()
		attachedIDs := listAttachedSCPIDs(t, rootID)

		ssoID := terraform.Output(t, opts, "sso_protection_scp_id")
		assert.Contains(t, attachedIDs, ssoID, "protect_sso should be attached to root")

		regionID := terraform.Output(t, opts, "region_restriction_scp_id")
		assert.Contains(t, attachedIDs, regionID, "region_restriction should be attached to root")
	})
}
