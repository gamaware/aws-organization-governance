package test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/codebuild"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	s3types "github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/aws/aws-sdk-go-v2/service/scheduler"
	"github.com/aws/aws-sdk-go-v2/service/sfn"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// cleanupAccountID returns the CLEANUP_ACCOUNT_ID environment variable or fails the test.
func cleanupAccountID(t *testing.T) string {
	t.Helper()
	id := getTerraformWorkingDir(t, "CLEANUP_ACCOUNT_ID", "")
	require.NotEmpty(t, id, "CLEANUP_ACCOUNT_ID environment variable is required")
	return id
}

// TestCleanupLambda verifies the AI verification Lambda function configuration.
func TestCleanupLambda(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	cfg := getDevAccountConfig(t, region)
	client := lambda.NewFromConfig(cfg)

	workingDir := getTerraformWorkingDir(t, "TF_WORKING_DIR", "../terraform/cleanup")
	opts := newTerraformOptions(t, workingDir)
	functionName := terraform.Output(t, opts, "lambda_function")

	result, err := client.GetFunction(context.TODO(), &lambda.GetFunctionInput{
		FunctionName: &functionName,
	})
	require.NoError(t, err, "GetFunction failed for %s", functionName)

	cfg2 := result.Configuration
	require.NotNil(t, cfg2, "Lambda configuration should not be nil")
	assert.Equal(t, "python3.12", string(cfg2.Runtime), "Lambda runtime should be python3.12")
	require.NotNil(t, cfg2.Handler, "Lambda handler should not be nil")
	assert.Equal(t, "ai_verify.handler", *cfg2.Handler, "Lambda handler should be ai_verify.handler")
	require.NotNil(t, cfg2.Timeout, "Lambda timeout should not be nil")
	assert.Equal(t, int32(900), *cfg2.Timeout, "Lambda timeout should be 900 seconds")
	require.NotNil(t, cfg2.MemorySize, "Lambda memory size should not be nil")
	assert.Equal(t, int32(512), *cfg2.MemorySize, "Lambda memory should be 512 MB")
	require.NotNil(t, cfg2.TracingConfig, "Lambda tracing config should be set")
	assert.Equal(t, "Active", string(cfg2.TracingConfig.Mode), "Lambda tracing should be Active")
	require.NotNil(t, cfg2.KMSKeyArn, "Lambda KMS key ARN should not be nil")
	assert.NotEmpty(t, *cfg2.KMSKeyArn, "Lambda KMS key ARN should be set")

	// Verify environment variables
	require.NotNil(t, cfg2.Environment, "Lambda environment should be set")
	envVars := cfg2.Environment.Variables
	expectedKeys := []string{"REPORTS_BUCKET", "ACCOUNT_ID", "TEAM_TAGS", "SNS_TOPIC_ARN", "ACCEPTED_FINDINGS"}
	for _, key := range expectedKeys {
		_, ok := envVars[key]
		assert.Truef(t, ok, "Lambda environment should contain %s", key)
	}
}

// TestCleanupStepFunctions verifies the state machine definition and configuration.
func TestCleanupStepFunctions(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	accountID := cleanupAccountID(t)
	cfg := getDevAccountConfig(t, region)
	client := sfn.NewFromConfig(cfg)

	stateMachineARN := fmt.Sprintf("arn:aws:states:%s:%s:stateMachine:resource-cleanup", region, accountID)

	result, err := client.DescribeStateMachine(context.TODO(), &sfn.DescribeStateMachineInput{
		StateMachineArn: &stateMachineARN,
	})
	require.NoError(t, err, "DescribeStateMachine failed for %s", stateMachineARN)
	assert.Equal(t, "resource-cleanup", *result.Name, "State machine name mismatch")

	// Parse definition JSON
	var definition map[string]interface{}
	err = json.Unmarshal([]byte(*result.Definition), &definition)
	require.NoError(t, err, "Failed to parse state machine definition")

	assert.Equal(t, "Discovery", definition["StartAt"], "State machine should start at Discovery")

	states, ok := definition["States"].(map[string]interface{})
	require.True(t, ok, "States should be a map")

	expectedStates := []string{
		"Discovery", "NotifyDiscovery", "WaitForApproval",
		"ApprovalTimeout", "Cleanup", "AIVerify", "NotifyComplete",
	}
	for _, stateName := range expectedStates {
		_, exists := states[stateName]
		assert.Truef(t, exists, "State machine should contain state %s", stateName)
	}

	// Verify WaitForApproval timeout
	waitState, ok := states["WaitForApproval"].(map[string]interface{})
	require.True(t, ok, "WaitForApproval should be a map")
	timeoutSeconds, ok := waitState["TimeoutSeconds"].(float64)
	require.True(t, ok, "TimeoutSeconds should be a number")
	assert.Equal(t, float64(86400), timeoutSeconds, "WaitForApproval timeout should be 86400 seconds (24h)")
}

// TestCleanupS3Bucket verifies the reports bucket configuration.
func TestCleanupS3Bucket(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	accountID := cleanupAccountID(t)
	cfg := getDevAccountConfig(t, region)
	s3Client := s3.NewFromConfig(cfg)

	bucketName := fmt.Sprintf("dev-cleanup-reports-%s", accountID)

	t.Run("Versioning", func(t *testing.T) {
		t.Parallel()
		result, err := s3Client.GetBucketVersioning(context.TODO(), &s3.GetBucketVersioningInput{
			Bucket: &bucketName,
		})
		require.NoError(t, err, "GetBucketVersioning failed")
		assert.Equal(t, s3types.BucketVersioningStatusEnabled, result.Status, "Bucket versioning should be Enabled")
	})

	t.Run("Encryption", func(t *testing.T) {
		t.Parallel()
		result, err := s3Client.GetBucketEncryption(context.TODO(), &s3.GetBucketEncryptionInput{
			Bucket: &bucketName,
		})
		require.NoError(t, err, "GetBucketEncryption failed")
		require.NotNil(t, result.ServerSideEncryptionConfiguration, "ServerSideEncryptionConfiguration should not be nil")
		require.NotEmpty(t, result.ServerSideEncryptionConfiguration.Rules, "Encryption rules should exist")

		rule := result.ServerSideEncryptionConfiguration.Rules[0]
		require.NotNil(t, rule.ApplyServerSideEncryptionByDefault, "ApplyServerSideEncryptionByDefault should not be nil")
		assert.Equal(t, s3types.ServerSideEncryptionAwsKms, rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm,
			"SSE algorithm should be aws:kms")
		require.NotNil(t, rule.BucketKeyEnabled, "BucketKeyEnabled should not be nil")
		assert.True(t, *rule.BucketKeyEnabled, "Bucket key should be enabled")
	})

	t.Run("PublicAccessBlock", func(t *testing.T) {
		t.Parallel()
		result, err := s3Client.GetPublicAccessBlock(context.TODO(), &s3.GetPublicAccessBlockInput{
			Bucket: &bucketName,
		})
		require.NoError(t, err, "GetPublicAccessBlock failed")

		pab := result.PublicAccessBlockConfiguration
		require.NotNil(t, pab, "PublicAccessBlockConfiguration should not be nil")
		require.NotNil(t, pab.BlockPublicAcls, "BlockPublicAcls should not be nil")
		assert.True(t, *pab.BlockPublicAcls, "BlockPublicAcls should be true")
		require.NotNil(t, pab.BlockPublicPolicy, "BlockPublicPolicy should not be nil")
		assert.True(t, *pab.BlockPublicPolicy, "BlockPublicPolicy should be true")
		require.NotNil(t, pab.IgnorePublicAcls, "IgnorePublicAcls should not be nil")
		assert.True(t, *pab.IgnorePublicAcls, "IgnorePublicAcls should be true")
		require.NotNil(t, pab.RestrictPublicBuckets, "RestrictPublicBuckets should not be nil")
		assert.True(t, *pab.RestrictPublicBuckets, "RestrictPublicBuckets should be true")
	})
}

// TestCleanupKMS verifies the KMS key exists, is enabled, and has rotation enabled.
func TestCleanupKMS(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	cfg := getDevAccountConfig(t, region)
	kmsClient := kms.NewFromConfig(cfg)

	// Find the key by alias
	var keyID string
	paginator := kms.NewListAliasesPaginator(kmsClient, &kms.ListAliasesInput{})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(context.TODO())
		require.NoError(t, err, "ListAliases failed")
		for _, alias := range page.Aliases {
			if *alias.AliasName == "alias/cleanup" {
				keyID = *alias.TargetKeyId
				break
			}
		}
		if keyID != "" {
			break
		}
	}
	require.NotEmpty(t, keyID, "KMS alias/cleanup should exist")

	t.Run("KeyEnabled", func(t *testing.T) {
		t.Parallel()
		result, err := kmsClient.DescribeKey(context.TODO(), &kms.DescribeKeyInput{
			KeyId: &keyID,
		})
		require.NoError(t, err, "DescribeKey failed")
		assert.Equal(t, "Enabled", string(result.KeyMetadata.KeyState), "KMS key should be Enabled")
	})

	t.Run("KeyRotation", func(t *testing.T) {
		t.Parallel()
		result, err := kmsClient.GetKeyRotationStatus(context.TODO(), &kms.GetKeyRotationStatusInput{
			KeyId: &keyID,
		})
		require.NoError(t, err, "GetKeyRotationStatus failed")
		assert.True(t, result.KeyRotationEnabled, "KMS key rotation should be enabled")
	})
}

// TestCleanupSNS verifies the notification topic exists and uses KMS encryption.
func TestCleanupSNS(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	cfg := getDevAccountConfig(t, region)
	snsClient := sns.NewFromConfig(cfg)

	workingDir := getTerraformWorkingDir(t, "TF_WORKING_DIR", "../terraform/cleanup")
	opts := newTerraformOptions(t, workingDir)
	topicARN := terraform.Output(t, opts, "sns_topic_arn")

	result, err := snsClient.GetTopicAttributes(context.TODO(), &sns.GetTopicAttributesInput{
		TopicArn: &topicARN,
	})
	require.NoError(t, err, "GetTopicAttributes failed for %s", topicARN)

	kmsMasterKeyID, ok := result.Attributes["KmsMasterKeyId"]
	assert.True(t, ok, "SNS topic should have KmsMasterKeyId attribute")
	assert.NotEmpty(t, kmsMasterKeyID, "SNS topic KmsMasterKeyId should not be empty")
}

// TestCleanupCodeBuild verifies the CodeBuild project configuration.
func TestCleanupCodeBuild(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	cfg := getDevAccountConfig(t, region)
	cbClient := codebuild.NewFromConfig(cfg)

	workingDir := getTerraformWorkingDir(t, "TF_WORKING_DIR", "../terraform/cleanup")
	opts := newTerraformOptions(t, workingDir)
	projectName := terraform.Output(t, opts, "codebuild_project")

	result, err := cbClient.BatchGetProjects(context.TODO(), &codebuild.BatchGetProjectsInput{
		Names: []string{projectName},
	})
	require.NoError(t, err, "BatchGetProjects failed")
	require.Len(t, result.Projects, 1, "Expected exactly 1 project")

	project := result.Projects[0]
	require.NotNil(t, project.TimeoutInMinutes, "TimeoutInMinutes should not be nil")
	assert.Equal(t, int32(480), *project.TimeoutInMinutes, "Build timeout should be 480 minutes")
	require.NotNil(t, project.Environment, "Environment should not be nil")
	assert.Equal(t, "BUILD_GENERAL1_SMALL", string(project.Environment.ComputeType),
		"Compute type should be BUILD_GENERAL1_SMALL")
	require.NotNil(t, project.Environment.PrivilegedMode, "PrivilegedMode should not be nil")
	assert.False(t, *project.Environment.PrivilegedMode, "Privileged mode should be false")
	require.NotNil(t, project.EncryptionKey, "Encryption key should be set")
	assert.NotEmpty(t, *project.EncryptionKey, "Encryption key should not be empty")
}

// TestCleanupIAMRoles verifies all 4 cleanup IAM roles exist with correct trust policies.
func TestCleanupIAMRoles(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	cfg := getDevAccountConfig(t, region)
	iamClient := iam.NewFromConfig(cfg)

	roles := []struct {
		name             string
		trustedPrincipal string
	}{
		{name: "cleanup-codebuild-execution", trustedPrincipal: "codebuild.amazonaws.com"},
		{name: "cleanup-lambda-execution", trustedPrincipal: "lambda.amazonaws.com"},
		{name: "cleanup-stepfunctions-execution", trustedPrincipal: "states.amazonaws.com"},
		{name: "cleanup-scheduler-execution", trustedPrincipal: "scheduler.amazonaws.com"},
	}

	for _, role := range roles {
		role := role
		t.Run(role.name, func(t *testing.T) {
			t.Parallel()

			result, err := iamClient.GetRole(context.TODO(), &iam.GetRoleInput{
				RoleName: aws.String(role.name),
			})
			require.NoErrorf(t, err, "GetRole failed for %s", role.name)

			// Trust policy is URL-encoded in the API response
			trustPolicyDoc, err := url.QueryUnescape(*result.Role.AssumeRolePolicyDocument)
			require.NoError(t, err, "Failed to decode trust policy for %s", role.name)

			assert.Contains(t, trustPolicyDoc, role.trustedPrincipal,
				"Trust policy for %s should contain %s", role.name, role.trustedPrincipal)
		})
	}
}

// TestCleanupScheduler verifies the EventBridge schedule configuration.
func TestCleanupScheduler(t *testing.T) {
	t.Parallel()

	region := getRegion(t)
	accountID := cleanupAccountID(t)
	cfg := getDevAccountConfig(t, region)
	schedClient := scheduler.NewFromConfig(cfg)

	workingDir := getTerraformWorkingDir(t, "TF_WORKING_DIR", "../terraform/cleanup")
	opts := newTerraformOptions(t, workingDir)
	scheduleName := terraform.Output(t, opts, "scheduler_name")

	result, err := schedClient.GetSchedule(context.TODO(), &scheduler.GetScheduleInput{
		Name:      &scheduleName,
		GroupName: aws.String("default"),
	})
	require.NoError(t, err, "GetSchedule failed for %s", scheduleName)

	assert.Equal(t, "America/Chicago", *result.ScheduleExpressionTimezone,
		"Schedule timezone should be America/Chicago")

	expectedSMArn := fmt.Sprintf("arn:aws:states:%s:%s:stateMachine:resource-cleanup", region, accountID)
	assert.Equal(t, expectedSMArn, *result.Target.Arn,
		"Schedule target should point to resource-cleanup state machine")
}
