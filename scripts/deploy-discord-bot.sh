#!/bin/bash
set -e

# Discord Bot Deployment Script — pushes bot.py to EC2 via SSM
echo "🤖 Deploying Discord Bot to EC2"
echo "================================"
echo ""

# Configuration
AWS_PROFILE="${AWS_PROFILE:-personal}"
AWS_REGION="${AWS_REGION:-us-east-2}"
STACK_NAME="openclaw-personal"

export AWS_PROFILE=$AWS_PROFILE

# Get Instance ID from CloudFormation
echo "📋 Getting Discord bot instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=${STACK_NAME}-discord-bot" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
    echo "❌ Could not find running Discord bot instance"
    exit 1
fi
echo "✅ Instance: $INSTANCE_ID"

# Get Runtime ARN from CloudFormation
RUNTIME_ARN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`AgentCoreRuntimeId`].OutputValue' \
    --output text)
echo "✅ Runtime ARN: $RUNTIME_ARN"

# Load Discord token from Secrets Manager
echo ""
echo "🔑 Fetching Discord token from Secrets Manager..."
DISCORD_BOT_TOKEN=$(aws secretsmanager get-secret-value \
    --secret-id ${STACK_NAME}-secrets \
    --region $AWS_REGION \
    --query 'SecretString' --output text | python3 -c "import sys,json; print(json.load(sys.stdin).get('DISCORD_BOT_TOKEN',''))")

if [ -z "$DISCORD_BOT_TOKEN" ]; then
    echo "⚠️  Token not in Secrets Manager, trying .env..."
    if [ -f "agent-container/.env" ]; then
        export $(grep -v '^#' agent-container/.env | grep DISCORD_BOT_TOKEN | xargs)
    fi
fi

if [ -z "$DISCORD_BOT_TOKEN" ]; then
    echo "❌ DISCORD_BOT_TOKEN not found"
    exit 1
fi
echo "✅ Discord token loaded"

# Upload bot.py via SSM
echo ""
echo "📤 Uploading bot.py..."
BOT_PY_B64=$(base64 < discord-bot/bot.py)
REQ_B64=$(base64 < discord-bot/requirements.txt)

COMMAND_ID=$(aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[
        'mkdir -p /home/ec2-user/discord-bot',
        'echo \"$BOT_PY_B64\" | base64 -d > /home/ec2-user/discord-bot/bot.py',
        'echo \"$REQ_B64\" | base64 -d > /home/ec2-user/discord-bot/requirements.txt',
        'cat > /home/ec2-user/discord-bot/.env << ENVEOF
DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN
AGENTCORE_RUNTIME_ARN=$RUNTIME_ARN
AWS_REGION=$AWS_REGION
ENVEOF',
        'chmod 600 /home/ec2-user/discord-bot/.env',
        'chown -R ec2-user:ec2-user /home/ec2-user/discord-bot',
        'pip3 install -q -r /home/ec2-user/discord-bot/requirements.txt',
        'systemctl restart discord-bot',
        'sleep 3',
        'systemctl status discord-bot --no-pager -l'
    ]" \
    --region $AWS_REGION \
    --query 'Command.CommandId' \
    --output text)

echo "⏳ Deploying and restarting..."
sleep 15

# Get result
aws ssm get-command-invocation \
    --command-id $COMMAND_ID \
    --instance-id $INSTANCE_ID \
    --region $AWS_REGION \
    --query 'StandardOutputContent' \
    --output text 2>/dev/null || echo "(waiting for output...)"

echo ""
echo "✅ Discord bot deployed!"
echo ""
echo "📊 Check logs:"
echo "  aws ssm send-command --instance-ids $INSTANCE_ID --document-name AWS-RunShellScript --parameters 'commands=[\"journalctl -u discord-bot -n 30 --no-pager\"]' --region $AWS_REGION"
