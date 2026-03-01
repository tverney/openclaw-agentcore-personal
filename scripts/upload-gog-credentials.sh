#!/bin/bash
set -e

# Upload GOG (Google Workspace CLI) credentials to S3
# Run this once after 'gog auth add' to make credentials available to the container.
#
# Usage: ./scripts/upload-gog-credentials.sh

AWS_PROFILE="${AWS_PROFILE:-personal}"
AWS_REGION="${AWS_REGION:-us-east-2}"
STACK_NAME="openclaw-personal"
GOG_EMAIL="${1:-lobinhaclowdia@gmail.com}"

echo "📤 Uploading GOG credentials for ${GOG_EMAIL}"
echo ""

# Get S3 bucket name from CloudFormation
BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`SessionBackupBucketName`].OutputValue' \
    --output text)

if [ -z "$BUCKET" ] || [ "$BUCKET" = "None" ]; then
    echo "❌ Could not find S3 bucket. Is the stack deployed?"
    exit 1
fi

echo "  S3 Bucket: $BUCKET"

# 1. Upload client credentials
CREDS_PATH="$HOME/Library/Application Support/gogcli/credentials.json"
if [ -f "$CREDS_PATH" ]; then
    aws s3 cp "$CREDS_PATH" "s3://$BUCKET/gog-credentials/credentials.json" \
        --profile $AWS_PROFILE --region $AWS_REGION
    echo "  ✅ Uploaded credentials.json"
else
    echo "  ❌ credentials.json not found at $CREDS_PATH"
    echo "     Run: gog auth credentials /path/to/client_secret.json"
    exit 1
fi

# 2. Export and upload refresh token
TOKEN_PATH="/tmp/gog-token-export.json"
gog auth tokens export "$GOG_EMAIL" --out "$TOKEN_PATH" --overwrite
aws s3 cp "$TOKEN_PATH" "s3://$BUCKET/gog-credentials/token.json" \
    --profile $AWS_PROFILE --region $AWS_REGION
rm -f "$TOKEN_PATH"
echo "  ✅ Uploaded refresh token"

echo ""
echo "🎉 Done! Add GOG_ACCOUNT to your deployment:"
echo "   python3 scripts/openclaw-config.py set-key google-workspace $GOG_EMAIL"
echo "   python3 scripts/openclaw-config.py apply"
echo ""
echo "   Or manually add to openclaw-simplified.yaml EnvironmentVariables:"
echo "     GOG_ACCOUNT: \"$GOG_EMAIL\""
