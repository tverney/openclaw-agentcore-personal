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

# 2. Export and upload refresh token for each authenticated account
for EMAIL in $(gog auth list 2>/dev/null | awk '{print $1}'); do
    TOKEN_PATH="/tmp/gog-token-${EMAIL}.json"
    gog auth tokens export "$EMAIL" --out "$TOKEN_PATH" --overwrite 2>/dev/null
    if [ -f "$TOKEN_PATH" ]; then
        aws s3 cp "$TOKEN_PATH" "s3://$BUCKET/gog-credentials/token-${EMAIL}.json" \
            --profile $AWS_PROFILE --region $AWS_REGION
        rm -f "$TOKEN_PATH"
        echo "  ✅ Uploaded refresh token for $EMAIL"
    fi
done

# Also upload default token.json for backward compatibility
gog auth tokens export "$GOG_EMAIL" --out "/tmp/gog-token-export.json" --overwrite 2>/dev/null
aws s3 cp "/tmp/gog-token-export.json" "s3://$BUCKET/gog-credentials/token.json" \
    --profile $AWS_PROFILE --region $AWS_REGION
rm -f "/tmp/gog-token-export.json"
echo "  ✅ Uploaded default refresh token ($GOG_EMAIL)"

echo ""
echo "🎉 Done! GOG credentials uploaded to S3."
echo "   Make sure GOG_ACCOUNT is set in your .env file:"
echo "     GOG_ACCOUNT=$GOG_EMAIL"
echo ""
echo "   Then redeploy: bash scripts/deploy.sh"
