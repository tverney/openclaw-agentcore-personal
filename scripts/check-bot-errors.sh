#!/bin/bash
# Check Discord bot logs for errors

set -e

AWS_PROFILE="${AWS_PROFILE:-personal}"
AWS_REGION="${AWS_REGION:-us-east-2}"
INSTANCE_ID="${INSTANCE_ID:-i-05e0fc6bc5727259b}"

export AWS_PROFILE=$AWS_PROFILE

echo "🔍 Checking Discord Bot Errors"
echo "=============================="
echo ""
echo "Instance: $INSTANCE_ID"
echo "Region: $AWS_REGION"
echo ""

# Get recent error logs via journalctl (bot runs as systemd service)
COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["journalctl -u discord-bot --no-pager -n 100 | grep -A 5 -B 2 -i \"error\\|exception\\|failed\\|500\\|502\\|RuntimeClientError\" || echo \"No errors found in recent logs\""]' \
  --region $AWS_REGION \
  --query 'Command.CommandId' \
  --output text)

echo "⏳ Fetching logs..."
sleep 5

aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --region $AWS_REGION \
  --query 'StandardOutputContent' \
  --output text

echo ""
echo "✅ Done"
echo ""
echo "💡 Tip: To see all logs, run:"
echo "   aws ssm start-session --target $INSTANCE_ID --profile $AWS_PROFILE --region $AWS_REGION"
echo "   Then: journalctl -u discord-bot -f"
