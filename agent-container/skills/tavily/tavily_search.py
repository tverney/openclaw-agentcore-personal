#!/usr/bin/env python3
"""Tavily AI Search - Web search optimized for AI agents."""
import argparse
import json
import os
import sys

try:
    from tavily import TavilyClient
except ImportError:
    print("Error: tavily-python package not installed", file=sys.stderr)
    print("To install: pip install tavily-python", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Tavily AI Web Search")
    parser.add_argument("query", help="Search query")
    parser.add_argument("--max-results", type=int, default=5, help="Max results (default: 5)")
    parser.add_argument("--depth", choices=["basic", "advanced"], default="basic",
                        help="Search depth: basic (fast) or advanced (thorough)")
    parser.add_argument("--topic", choices=["general", "news"], default="general",
                        help="Topic filter: general or news")
    parser.add_argument("--include-domains", type=str, default=None,
                        help="Comma-separated domains to include")
    parser.add_argument("--exclude-domains", type=str, default=None,
                        help="Comma-separated domains to exclude")
    parser.add_argument("--no-answer", action="store_true",
                        help="Skip AI answer generation")
    parser.add_argument("--api-key", type=str, default=None,
                        help="Tavily API key (default: TAVILY_API_KEY env var)")
    args = parser.parse_args()

    api_key = args.api_key or os.environ.get("TAVILY_API_KEY")
    if not api_key:
        print("Error: Tavily API key required", file=sys.stderr)
        print("Set TAVILY_API_KEY environment variable or pass --api-key", file=sys.stderr)
        sys.exit(1)

    client = TavilyClient(api_key=api_key)

    kwargs = {
        "query": args.query,
        "max_results": args.max_results,
        "search_depth": args.depth,
        "topic": args.topic,
        "include_answer": not args.no_answer,
    }
    if args.include_domains:
        kwargs["include_domains"] = [d.strip() for d in args.include_domains.split(",")]
    if args.exclude_domains:
        kwargs["exclude_domains"] = [d.strip() for d in args.exclude_domains.split(",")]

    try:
        response = client.search(**kwargs)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

    output = {"query": args.query, "success": True}
    if response.get("answer"):
        output["answer"] = response["answer"]
    output["results"] = [
        {"title": r.get("title", ""), "url": r.get("url", ""), "content": r.get("content", ""),
         "score": r.get("score", 0)}
        for r in response.get("results", [])
    ]
    print(json.dumps(output, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
