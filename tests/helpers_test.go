package test

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials/stscreds"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// getAWSConfig returns an AWS config for the given region using ambient credentials.
func getAWSConfig(t *testing.T, region string) aws.Config {
	t.Helper()
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(region))
	if err != nil {
		t.Fatalf("Unable to load AWS config: %v", err)
	}
	return cfg
}

// getDevAccountConfig returns an AWS config with assumed role into the Dev account.
func getDevAccountConfig(t *testing.T, region string) aws.Config {
	t.Helper()
	accountID := os.Getenv("CLEANUP_ACCOUNT_ID")
	if accountID == "" {
		t.Fatal("CLEANUP_ACCOUNT_ID environment variable is required")
	}

	baseCfg := getAWSConfig(t, region)
	stsClient := sts.NewFromConfig(baseCfg)

	roleARN := fmt.Sprintf("arn:aws:iam::%s:role/OrganizationAccountAccessRole", accountID)
	creds := stscreds.NewAssumeRoleProvider(stsClient, roleARN)

	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(region),
		config.WithCredentialsProvider(aws.NewCredentialsCache(creds)),
	)
	if err != nil {
		t.Fatalf("Unable to assume role: %v", err)
	}
	return cfg
}

// getRegion returns the AWS region from environment or defaults to us-east-1.
func getRegion(t *testing.T) string {
	t.Helper()
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}
	return region
}

// getTerraformWorkingDir returns the Terraform working directory from environment.
func getTerraformWorkingDir(t *testing.T, envVar string, defaultDir string) string {
	t.Helper()
	dir := os.Getenv(envVar)
	if dir == "" {
		dir = defaultDir
	}
	return dir
}

// newTerraformOptions creates Terraform options for reading outputs from deployed state.
func newTerraformOptions(t *testing.T, workingDir string) *terraform.Options {
	t.Helper()
	return &terraform.Options{
		TerraformDir: workingDir,
		NoColor:      true,
	}
}
