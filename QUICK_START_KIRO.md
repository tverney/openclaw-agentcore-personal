# Quick Start with Kiro AI

Deploy OpenClaw on AWS AgentCore by chatting with Kiro — no commands to remember.

## Prerequisites

- AWS account with credentials configured (`aws configure`)
- [Kiro](https://kiro.dev) installed
- Docker running locally
- [Bedrock models enabled](https://console.aws.amazon.com/bedrock/home#/modelaccess) in your target region

## How to Use

### Step 1: Clone and Open

```bash
git clone https://github.com/tverney/openclaw-personal-agentcore.git
```

Open the `openclaw-personal` folder as a workspace in Kiro (File → Open Folder).

### Step 2: Start Chatting

In the Kiro chat panel, say:

> "Help me deploy my personal OpenClaw"

### Step 3: Answer a Few Questions

Kiro asks about:

1. **AWS Region** (default: us-east-2)
2. **AI Model** (default: Claude Haiku 4.5)
3. **Discord Bot Token** (optional — skip if not using Discord)
4. **Admin Email** (for budget alerts)
5. **Monthly Budget Limit** (default: $15)

Say "default" to skip questions and deploy with recommended settings.

### Step 4: Wait ~10 Minutes

Kiro will:

1. Copy `.env.example` to `.env` with your settings
2. Build the Docker container image
3. Push to ECR
4. Deploy the CloudFormation stack
5. Deploy the Discord bot (if configured)
6. Verify the runtime is healthy

### Step 5: Connect

- **Discord**: Mention your bot — `@YourBot hello!`
- **WhatsApp/Telegram/Slack**: Kiro walks you through connecting via the OpenClaw Web UI

## Example Conversation

```
You: "Help me deploy my personal OpenClaw"

Kiro: "Which AWS region? (default: us-east-2)"
You: "default"

Kiro: "Which AI model? (default: Claude Haiku 4.5)"
You: "default"

Kiro: "Discord bot token? (paste token or 'skip')"
You: "skip"

Kiro: "Email for budget alerts?"
You: "me@example.com"

Kiro: "Configuration:
       Region: us-east-2
       Model: Claude Haiku 4.5
       Discord: disabled
       Budget: $15/month
       Estimated infra cost: ~$1-2/month (no Discord EC2)
       Proceed?"
You: "yes"

Kiro: "🚀 Building container... pushing to ECR... deploying stack...
       ✅ Complete! Runtime ARN: arn:aws:bedrock-agentcore:...
       Want to connect a messaging platform?"
You: "yes, WhatsApp"

Kiro: "📱 Open the Web UI via SSM port forwarding, go to
       Channels → Add → WhatsApp → Scan QR from your phone."
```

## Without Kiro

### Option 1: One-Click CloudFormation

Click "Launch Stack" in the [main README](README.md) — then build and push the container with `bash scripts/deploy.sh`.

### Option 2: CLI

```bash
cp agent-container/.env.example agent-container/.env
# Edit .env with your settings
bash scripts/deploy.sh
```

## Troubleshooting

**Kiro doesn't respond to "deploy OpenClaw":**
- Make sure you opened the folder as a workspace (File → Open Folder)
- Try: "Kiro, I need help deploying OpenClaw on AWS"

**Docker not running:**
- Kiro will detect this and remind you to start Docker Desktop

**Deployment failed:**
- Kiro checks CloudFormation events, explains the error, and offers to retry

## Learn More

- [Kiro](https://kiro.dev) · [Kiro Docs](https://kiro.dev/docs)
- [OpenClaw Docs](https://docs.openclaw.ai)
- [Full Deployment Guide](docs/DEPLOYMENT.md) · [Troubleshooting](docs/TROUBLESHOOTING.md)
