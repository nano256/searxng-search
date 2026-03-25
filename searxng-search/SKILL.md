---
name: searxng-search
description: >
  Search the web via a self-hosted SearXNG instance. Provides privacy-respecting
  metasearch with category filtering, time range, engine selection, pagination,
  and structured JSON output. Use this skill whenever the user wants to search
  with SearXNG, wants private/self-hosted search, needs multi-engine aggregation,
  or asks to search with specific engine or category control. Also use when the
  user mentions SearXNG by name or references their local search instance.
license: MIT
compatibility: Requires curl and jq. Network access to a SearXNG instance.
metadata:
  author: nano256
  version: "1.0.0"
---

# SearXNG Search

Query a SearXNG instance via its JSON API. Use `scripts/search.sh` for standard
searches. Fall back to direct `curl` for advanced parameters (engines, language,
safesearch).

## Configuration

`$SEARXNG_URL` must be set. If unset, tell the user to export it. Do NOT fall
back to `localhost:8080` silently.

## Standard usage — scripts/search.sh

Handles request construction, encoding, JSON validation, and result filtering.
Returns a JSON array of `{title, url, content}` (max 10 per page).

```bash
bash scripts/search.sh "query"                        # general search
bash scripts/search.sh "query" -c news                # category
bash scripts/search.sh "query" -c news -t day          # category + recent only
bash scripts/search.sh "query" -t month                # time filter, any category
bash scripts/search.sh "query" -p 2                    # page 2
bash scripts/search.sh "query" -c science -t year -p 3  # all options
```

**Flags:** `-c CATEGORY`, `-t TIME_RANGE` (day|month|year), `-p PAGE` (default: 1).

**Exit codes:** 0 success, 1 bad input/config, 2 HTTP/network error, 3 no results.
On exit 3, suggestions (if any) are printed to stderr.

## Advanced usage — direct curl

For parameters the script doesn't cover (engines, language, safesearch), use
curl directly. Always POST with `--data-urlencode` for the query:

```bash
curl -s -X POST "${SEARXNG_URL}/search" \
  --data-urlencode "q=search terms" \
  -d "format=json" \
  -d "engines=wikipedia,google" \
  -d "language=de" \
  -d "safesearch=1" \
  | jq '[.results[:10][] | {title, url, content}]'
```

For self-signed certs, add `-k` after confirming with the user.

## Full API parameters

| Parameter | Values | Default | Notes |
|-----------|--------|---------|-------|
| `q` | string | *required* | Supports engine syntax (e.g. `site:github.com`) |
| `format` | `json`, `csv`, `rss` | none | Must be enabled on instance. Always use `json`. |
| `categories` | `general`, `images`, `news`, `videos`, `music`, `files`, `it`, `science`, `map` | `general` | Comma-separated |
| `engines` | engine names | all enabled | Comma-separated. E.g. `google,wikipedia` |
| `language` | language code | instance default | `en`, `de`, `fr`, `all`, etc. |
| `pageno` | integer >= 1 | `1` | Increment for more results |
| `time_range` | `day`, `month`, `year` | none | **No `week` value.** |
| `safesearch` | `0`, `1`, `2` | instance default | 0=off, 1=moderate, 2=strict |

## Response schema

The script returns `[{title, url, content}, ...]`. Direct curl returns the full
response. Top-level fields: `query`, `number_of_results`, `results`, `answers`,
`corrections`, `infoboxes`, `suggestions`.

Each `.results[]` object:

```
title, url, content  — always present (content may be empty)
engines              — string[], which engines returned this
score                — float, aggregated relevance
publishedDate        — string, ISO date (if available)
thumbnail            — string, thumbnail URL (images/videos)
```

## Workflow guidance

1. Use the script for standard searches. Use direct curl only when you need
   engines, language, or safesearch.
2. Start broad, then narrow. Refine the query before paginating.
3. For news or recent information, use `-t day` or `-t month`.
4. If results are empty (exit 3), check stderr for suggestions.
5. When using direct curl, check `.infoboxes` for direct answers and
   `.suggestions` for alternative queries.

## Error handling

| Symptom | Cause | Action |
|---------|-------|--------|
| Exit 1 / connection refused | Instance down or wrong URL | Verify `$SEARXNG_URL` |
| Exit 2 / non-JSON response | `format=json` disabled | Tell user to enable in SearXNG's `settings.yml` → `search.formats` or fix it yourself if you have access to the SearXNG instance |
| Exit 3 | No results | Check suggestions, try broader terms |

## Gotchas

- **No `week` time range.** Only `day`, `month`, `year`.
- **`format=json` must be enabled server-side.** A non-JSON response likely means this.
- **Engine availability varies by instance.** Don't assume any engine exists.
- **`number_of_results` is unreliable.** Don't use it for pagination logic.
- **No result caching.** Every request (including pagination) hits upstream engines again. SearXNG does not cache results by design (privacy).
