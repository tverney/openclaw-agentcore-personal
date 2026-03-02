---
name: tavily
description: "AI-optimized web search using Tavily API. Use when you need web search, current events, news, fact-checking, or research. Returns clean structured results optimized for AI. No browser needed."
metadata: { "openclaw": { "emoji": "🔍", "requires": { "bins": ["python3"] } } }
---

# Tavily Web Search

AI-optimized web search via the Tavily API. Returns concise, structured results.

## When to Use

✅ **USE this skill when:**

- User asks to search the web
- Need current information or news
- Fact-checking or research
- "What is...", "Search for...", "Find information about..."
- Need recent events or developments

## When NOT to Use

❌ **DON'T use this skill when:**

- User provides a specific URL (use `curl` or `web_fetch` instead)
- Offline/cached information is sufficient

## Commands

### Basic search
```bash
python3 /app/skills/tavily/tavily_search.py "your search query"
```

### More results
```bash
python3 /app/skills/tavily/tavily_search.py "query" --max-results 10
```

### Deep research mode (slower but more comprehensive)
```bash
python3 /app/skills/tavily/tavily_search.py "complex topic" --depth advanced
```

### News only (recent events)
```bash
python3 /app/skills/tavily/tavily_search.py "latest news topic" --topic news
```

### Filter by domain
```bash
python3 /app/skills/tavily/tavily_search.py "query" --include-domains "python.org,docs.python.org"
```

## Environment

- Requires `TAVILY_API_KEY` environment variable (already configured)

## Output Format

Returns JSON with:
- `answer`: AI-generated summary from search results
- `results`: Array of `{title, url, content, score}`

## Examples

```bash
# Quick fact check
python3 /app/skills/tavily/tavily_search.py "population of Brazil 2026"

# Tech research
python3 /app/skills/tavily/tavily_search.py "Python 3.13 new features" --depth advanced

# Recent news
python3 /app/skills/tavily/tavily_search.py "AI news this week" --topic news --max-results 5
```
