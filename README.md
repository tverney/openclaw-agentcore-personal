# AgentCore OpenClaw Personal Bot — Serverless AI Assistant on AWS

> Cost-optimized [OpenClaw](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock) deployment using AWS Bedrock AgentCore Runtime. Connect via Discord, WhatsApp, Telegram, or Slack. ~$9-15/month infrastructure.

[![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=openclaw-personal&templateURL=https://raw.githubusercontent.com/tverney/openclaw-personal-agentcore/main/openclaw-simplified.yaml)

## What Is This?

A single-user, serverless deployment of OpenClaw on AWS. Instead of running an EC2 instance 24/7, the AI runs on-demand via AgentCore Runtime — the container freezes between invocations, so you only pay when you use it.

All messaging plugins (WhatsApp, Telegram, Discord, Slack) are pre-installed in OpenClaw. This template includes a Discord bot by default, but you can connect any platform directly through the OpenClaw Web UI.

## Architecture

```
You (Discord / WhatsApp / Telegram / Slack)
  │
  ▼
┌──────────────────────────────────────────────────────────┐
│  AWS Cloud                                               │
│                                                          │
│  EC2 t4g.nano ──invoke──▶  AgentCore Runtime             │
│  (Discord bot)             (OpenClaw container)          │
│                                │                         │
│                            IAM Role                      │
│                                │                         │
│                            Bedrock                       │
│                          (Haiku/Sonnet/Nova)             │
│                                                          │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌───────────┐ │
│  │ KMS     │  │ Secrets  │  │ S3      │  │EventBridge│ │
│  │(encrypt)│  │ Manager  │  │(sessions│  │(cron jobs) │ │
│  └─────────┘  └──────────┘  │ memory) │  └───────────┘ │
│                              └─────────┘                 │
│  CloudWatch ─── SNS ─── Budget Alerts                    │
└──────────────────────────────────────────────────────────┘
  │
  ▼
You (receive response)
```

- **AgentCore Runtime**: Runs OpenClaw in a managed container that freezes when idle
- **EC2 nano**: Lightweight Discord bot relay (~512MB RAM, only needed for Discord)
- **Bedrock**: Model inference via IAM — no API keys to manage
- **EventBridge → Lambda**: External cron scheduler (container freezes make in-container cron unreliable)

## Cost Comparison

| | Original EC2 Deployment | Lightsail Deployment | This AgentCore Deployment |
|---|---|---|---|
| Compute | EC2 running 24/7 (~$35/mo) | Lightsail 4GB plan ($24/mo) | Serverless, pay-per-use |
| Complexity | Multi-tenant, VPC required | Pre-configured, simple | Single-user, minimal infra |
| Scaling | Manual | Fixed instance | Auto-freezes when idle |
| Typical cost | ~$80/month | ~$24/month* | ~$9-15/month** |

*\*Lightsail cost excludes model tokens (Bedrock usage billed separately).*
*\*\*~$4 EC2 nano (Discord bot) + \~$3.60 public IPv4 + \~$1 KMS + pennies for ECR/S3/Secrets Manager/CloudWatch. Model token costs are additional and vary by usage.*

> **Note**: If you use WhatsApp or Telegram (webhook-based) instead of Discord, you can eliminate the EC2 instance entirely — reducing infra to ~$1-2/month.

## Models

Switch models with one parameter in `.env` — no code changes:

| Model | Input / Output per 1M tokens | Best for |
|---|---|---|
| Claude Haiku 4.5 (default) | $1.00 / $5.00 | Fast, efficient, great for daily tasks |
| Claude Sonnet 4 | $3.00 / $15.00 | Complex reasoning, coding |
| Nova Lite | $0.06 / $0.24 | Budget-friendly, simple tasks |
| Nova Pro | $0.80 / $3.20 | Balanced performance, multimodal |
| DeepSeek R1 | $0.55 / $2.19 | Open-source reasoning |

Uses cross-region inference profiles (`us.` prefix) — requests auto-route to optimal locations for higher throughput.

## What Can OpenClaw Do?

Once connected, just message it:

```
You: What's the weather in Austin?
You: Summarize this PDF [attach file]
You: Remind me every Sunday at 9am to check the weather forecast
You: Search the web for AWS Bedrock pricing
You: Add eggs and milk to my shopping list
You: What are my Google Calendar events today?
```

OpenClaw comes with 30+ bundled skills. This template adds custom skills for weather, notes/reminders, stock tracking, soccer scores, and more via the `community-skills.json` system.

## Security

| Layer | What it does |
|---|---|
| KMS (CMK) | Encrypts S3 data, Secrets Manager values, and SNS topics |
| Secrets Manager | Stores all sensitive values (API keys, tokens) — no plaintext in CloudFormation |
| IAM Roles | Least-privilege per component (AgentCore, Discord bot, Lambda, Scheduler) |
| S3 Bucket Policy | Restricts session/memory access to the execution role only |
| No public ports | Discord bot calls out only — nothing listens for inbound connections |
| AgentCore isolation | Container runs in AWS-managed environment, not a raw EC2 |
| Budget alerts | SNS notifications at 80% and 100% of configurable monthly limit |
| CloudWatch | Monitoring and alarming on spend |

## Prerequisites

- AWS CLI configured with your account (`aws configure`)
- Docker running locally (used to build the AgentCore container image)
- Go 1.21+ (for cross-compiling the Alexa CLI and GOG CLI binaries)
- [Bedrock model access](https://console.aws.amazon.com/bedrock/home#/modelaccess) enabled for your chosen model
- A Discord bot token (optional — only if using the Discord integration)

## Quick Start

### 1. Configure

```bash
cp agent-container/.env.example agent-container/.env
# Edit .env with your settings (model ID, Discord token, etc.)
```

### 2. Deploy

```bash
bash scripts/deploy.sh
```

This single command handles everything: validates the template, builds the Docker image, pushes to ECR, deploys/updates the CloudFormation stack, and deploys the Discord bot.

### 3. Chat

In Discord: `@YourBot hello!`

Or open the OpenClaw Web UI via SSM port forwarding to connect WhatsApp, Telegram, or Slack.

### 🎯 Deploy with Kiro AI

Prefer a guided experience? [Kiro](https://kiro.dev) walks you through deployment conversationally — just open this repo as a workspace and say "help me deploy my personal OpenClaw".

→ [Kiro Deployment Guide](QUICK_START_KIRO.md)

## After Deployment

```bash
# Check stack status
aws cloudformation describe-stacks --stack-name openclaw-personal --region us-east-2

# Test the runtime directly
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn "YOUR_RUNTIME_ARN" \
  --payload "$(echo -n '{"message":"hello"}' | base64)" \
  /tmp/output.json --region us-east-2

# View Discord bot logs (via SSM)
aws ssm send-command --instance-ids YOUR_INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["journalctl -u discord-bot -n 30"]' \
  --region us-east-2
```

## Project Structure

```
├── openclaw-simplified.yaml    # CloudFormation template (entire stack)
├── agent-container/            # Docker container for AgentCore
│   ├── server.py               # HTTP server wrapping OpenClaw
│   ├── openclaw.json           # OpenClaw configuration
│   ├── skills/                 # Custom skills (weather, notes, stocks, etc.)
│   ├── community-skills.json   # ClawHub skills to auto-install at build time
│   ├── Dockerfile
│   └── requirements.txt
├── discord-bot/                # Python Discord bot (runs on EC2)
│   ├── bot.py                  # Bot using boto3 invoke-agent-runtime
│   └── requirements.txt
├── scripts/                    # Deployment & utility scripts
│   ├── deploy.sh               # Full deployment (build + push + CFN)
│   ├── quick-redeploy.sh       # Rebuild & push container only
│   ├── deploy-discord-bot.sh   # Update bot on EC2 via SSM
│   ├── install-community-skills.sh  # Auto-install ClawHub skills
│   └── ...
└── docs/                       # Documentation
```

## Key Features

- **Serverless AI**: AgentCore Runtime — container freezes when idle, no idle costs
- **Session persistence**: Conversations, memory, and workspace backed up to S3
- **EventBridge cron**: Scheduled tasks via EventBridge → Lambda → AgentCore (survives container freezes)
- **Multi-platform**: Discord bot included, WhatsApp/Telegram/Slack via OpenClaw plugins
- **Custom skills**: Weather, notes/reminders, stock watcher, soccer scores, personal assistant
- **Community skills**: Auto-install from ClawHub via `community-skills.json` at build time
- **Budget protection**: Tag-based budget tracking with SNS alerts
- **Model flexibility**: Switch models by changing one line in `.env`

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md)
- [Discord Setup](docs/DISCORD-SETUP.md)
- [Configuration](docs/CONFIGURATION.md)
- [Session Persistence](docs/SESSION-PERSISTENCE.md)
- [Cost Optimization](docs/COST-OPTIMIZATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Inference Profiles](docs/INFERENCE-PROFILES.md)
- [Security](docs/SECURITY.md)

## Resources

- [OpenClaw Docs](https://docs.openclaw.ai) · [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Amazon Bedrock Docs](https://docs.aws.amazon.com/bedrock/) · [AgentCore Runtime](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-get-started.html)
- [OpenClaw on Lightsail](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-quick-start-guide-openclaw.html) (official AWS guide)
- [Original AWS Sample](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock) (forked from)

## License

See [LICENSE](LICENSE) for details.
