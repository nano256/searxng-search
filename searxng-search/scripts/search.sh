#!/usr/bin/env bash
# SearXNG search — thin wrapper around curl + jq
set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found." >&2; exit 1
fi
if [[ -z "${SEARXNG_URL:-}" ]]; then
  echo "Error: SEARXNG_URL is not set." >&2
  echo "  export SEARXNG_URL=https://your-instance.example.com" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: search.sh QUERY [-c CATEGORY] [-t TIME_RANGE] [-p PAGE]

Options:
  -c  Category: general|news|images|videos|science|it|files|music|map (default: general)
  -t  Time range: day|month|year
  -p  Page number (default: 1)
  -h  Show this help

Output: JSON array of {title, url, content} (max 10 per page)
EOF
}

# --- Parse args ---
QUERY="" CATEGORY="general" TIME_RANGE="" PAGE="1"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h) usage; exit 0 ;;
    -c) CATEGORY="$2"; shift 2 ;;
    -t) TIME_RANGE="$2"; shift 2 ;;
    -p) PAGE="$2"; shift 2 ;;
    -*) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
    *)  QUERY="$1"; shift ;;
  esac
done
if [[ -z "$QUERY" ]]; then echo "Error: No query provided." >&2; usage >&2; exit 1; fi

# --- Build request ---
CURL_ARGS=(-s -X POST "${SEARXNG_URL}/search"
  --data-urlencode "q=${QUERY}"
  -d "format=json" -d "categories=${CATEGORY}" -d "pageno=${PAGE}")
[[ -n "$TIME_RANGE" ]] && CURL_ARGS+=(-d "time_range=${TIME_RANGE}")

# --- Execute and filter ---
RESP=$(curl "${CURL_ARGS[@]}" 2>/dev/null) || {
  echo "Error: Cannot reach ${SEARXNG_URL}" >&2; exit 2
}
if ! echo "$RESP" | jq empty 2>/dev/null; then
  echo "Error: Non-JSON response. Is format=json enabled on this instance?" >&2; exit 2
fi

COUNT=$(echo "$RESP" | jq '.results | length')
if [[ "$COUNT" -eq 0 ]]; then
  SUGG=$(echo "$RESP" | jq -r '.suggestions // [] | join(", ")')
  echo "No results." >&2
  [[ -n "$SUGG" ]] && echo "Suggestions: ${SUGG}" >&2
  exit 3
fi

echo "$RESP" | jq '[.results[:10][] | {title, url, content}]'
