#!/usr/bin/env python3
"""OpenClaw Discord Bot — threads, conversation history, and slash commands."""
import asyncio, json, os, re, sys, logging
import boto3
from botocore.config import Config
import discord
from discord import app_commands

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", stream=sys.stdout)
logger = logging.getLogger(__name__)

DISCORD_BOT_TOKEN = os.environ["DISCORD_BOT_TOKEN"]
AGENT_RUNTIME_ARN = os.environ["AGENTCORE_RUNTIME_ARN"]
AWS_REGION = os.environ.get("AWS_REGION", "us-east-2")

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)
tree = app_commands.CommandTree(client)
_processing = set()
_synced = False

bedrock_client = boto3.client(
    "bedrock-agentcore", region_name=AWS_REGION,
    config=Config(read_timeout=120, connect_timeout=10, retries={"max_attempts": 2}),
)

def invoke_runtime(message, channel="discord_general", history=None):
    payload = {"message": message, "channel": channel}
    if history:
        payload["history"] = history
    resp = bedrock_client.invoke_agent_runtime(
        agentRuntimeArn=AGENT_RUNTIME_ARN,
        payload=json.dumps(payload).encode("utf-8"),
        contentType="application/json",
    )
    stream = resp.get("response")
    if hasattr(stream, "read"):
        body = stream.read().decode("utf-8")
    else:
        body = str(stream)
    logger.info(f"Raw response length: {len(body)}")
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return body[:200]
    if data.get("choices"):
        return data["choices"][0].get("message", {}).get("content", "No response")
    if data.get("message"):
        return data["message"]
    return json.dumps(data, indent=2)

# ── Slash commands ──

async def _slash_handler(interaction: discord.Interaction, command: str):
    await interaction.response.defer()
    logger.info(f"Slash /{command} from {interaction.user}")
    try:
        text = await asyncio.wait_for(
            asyncio.to_thread(invoke_runtime, f"/{command}", "discord_general"), timeout=120)
        for i in range(0, len(text), 2000):
            await interaction.followup.send(text[i:i+2000])
    except asyncio.TimeoutError:
        await interaction.followup.send("The AI took too long to respond. Try again?")
    except Exception as e:
        logger.error(f"Slash error: {e}", exc_info=True)
        await interaction.followup.send("Something went wrong.")

@tree.command(name="status", description="Show OpenClaw model, tokens used, and cost")
async def cmd_status(interaction: discord.Interaction):
    await _slash_handler(interaction, "status")

@tree.command(name="new", description="Start a fresh conversation")
async def cmd_new(interaction: discord.Interaction):
    await _slash_handler(interaction, "new")

@tree.command(name="openclaw_help", description="List all OpenClaw commands")
async def cmd_help(interaction: discord.Interaction):
    await _slash_handler(interaction, "help")

@tree.command(name="think", description="Set reasoning mode")
@app_commands.describe(level="Reasoning level")
@app_commands.choices(level=[
    app_commands.Choice(name="high", value="high"),
    app_commands.Choice(name="medium", value="medium"),
    app_commands.Choice(name="low", value="low"),
    app_commands.Choice(name="off", value="off"),
])
async def cmd_think(interaction: discord.Interaction, level: app_commands.Choice[str]):
    await _slash_handler(interaction, f"think {level.value}")

@tree.command(name="ask", description="Ask OpenClaw anything")
@app_commands.describe(message="Your message")
async def cmd_ask(interaction: discord.Interaction, message: str):
    await interaction.response.defer()
    logger.info(f"Slash /ask from {interaction.user}: {message[:100]}")
    try:
        text = await asyncio.wait_for(
            asyncio.to_thread(invoke_runtime, message, "discord_general"), timeout=120)
        for i in range(0, len(text), 2000):
            await interaction.followup.send(text[i:i+2000])
    except asyncio.TimeoutError:
        await interaction.followup.send("The AI took too long to respond. Try again?")
    except Exception as e:
        logger.error(f"Slash error: {e}", exc_info=True)
        await interaction.followup.send("Something went wrong.")

# ── Events ──

@client.event
async def on_ready():
    global _synced
    logger.info(f"Logged in as {client.user} (id={client.user.id})")
    logger.info(f"Guilds: {[g.name for g in client.guilds]}")
    # Slash command sync disabled — requires Python 3.10+ investigation
    # See: https://github.com/tverney/openclaw-personal-agentcore/issues/X

@client.event
async def on_interaction(interaction: discord.Interaction):
    logger.info(f"Interaction received: type={interaction.type}, data={interaction.data}")
    await tree._call(interaction)

@client.event
async def on_message(message):
    if message.author.bot or message.author.id == client.user.id:
        return
    bot_id = str(client.user.id)
    is_mentioned = (
        client.user in message.mentions
        or f"<@{bot_id}>" in message.content
        or f"<@!{bot_id}>" in message.content
    )
    is_dm = isinstance(message.channel, discord.DMChannel)
    if not is_mentioned and not is_dm:
        return
    clean = message.content
    if is_mentioned:
        clean = re.sub(r"<@!?\d+>", "", clean).strip()
    if not clean:
        await message.channel.send("Hey! Send me a message and I'll respond.")
        return
    logger.info(f"Message from {message.author}: {clean[:100]}")
    chan_id = message.channel.id
    if chan_id in _processing:
        return
    _processing.add(chan_id)

    thread = None
    if isinstance(message.channel, discord.Thread):
        thread = message.channel
    elif not is_dm:
        try:
            thread = await message.create_thread(
                name=clean[:95] + "..." if len(clean) > 95 else clean,
                auto_archive_duration=60)
        except Exception as e:
            logger.warning(f"Could not create thread: {e}")
    reply_target = thread or message.channel

    history = []
    if thread:
        try:
            msgs = [m async for m in thread.history(limit=20, oldest_first=True)]
            for m in msgs:
                if m.id == message.id:
                    continue
                role = "assistant" if m.author.id == client.user.id else "user"
                content = re.sub(r"<@!?\d+>", "", m.content).strip()
                if content:
                    history.append({"role": role, "content": content})
        except Exception as e:
            logger.warning(f"Could not fetch history: {e}")

    try:
        async with reply_target.typing():
            ai_text = await asyncio.wait_for(
                asyncio.to_thread(invoke_runtime, clean, "discord_general", history or None),
                timeout=120)
        for i in range(0, len(ai_text), 2000):
            await reply_target.send(ai_text[i:i+2000])
        logger.info(f"Reply sent ({len(ai_text)} chars)")
    except asyncio.TimeoutError:
        await reply_target.send("The AI took too long to respond. Try again?")
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        await reply_target.send("Sorry, something went wrong.")
    finally:
        _processing.discard(chan_id)

client.run(DISCORD_BOT_TOKEN)
