#!/usr/bin/env bash
# confluence-search.sh — Search Confluence via CQL using ~/.netrc auth.
#
# acli has no Confluence search subcommand, so this fills the gap: run a CQL
# query via the REST API and hand the resulting page IDs to
# `acli confluence page view --id <ID>` for structured reads.
#
# Usage:
#   confluence-search.sh <text>                    text search (wraps in CQL)
#   confluence-search.sh --cql '<cql>'             raw CQL
#   confluence-search.sh --space KEY <text>        scope to a space
#   confluence-search.sh --limit N <text>          cap results (default 10)
#   confluence-search.sh --json <text>             raw JSON instead of TSV
#
# Setup (one-time):
#   1. Create an API token at https://id.atlassian.com/manage-profile/security/api-tokens
#   2. Add an entry to ~/.netrc:
#        machine thescore.atlassian.net
#          login you@example.com
#          password <API-TOKEN>
#   3. chmod 600 ~/.netrc
#
# Overrides:
#   CONFLUENCE_HOST   default: thescore.atlassian.net
#
# Examples:
#   confluence-search.sh "BFF client integration"
#   confluence-search.sh --space SBBFF "pagination"
#   confluence-search.sh --cql 'label = "bff" AND type = page ORDER BY lastmodified DESC'

set -euo pipefail

HOST="${CONFLUENCE_HOST:-thescore.atlassian.net}"
LIMIT=10
CQL_MODE=false
SPACE=""
JSON_OUT=false
QUERY=""

usage() { sed -n '2,30p' "$0" | sed 's|^# \{0,1\}||'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cql)     CQL_MODE=true; shift ;;
    --space)   SPACE="${2:?--space requires a value}"; shift 2 ;;
    --limit)   LIMIT="${2:?--limit requires a value}"; shift 2 ;;
    --json)    JSON_OUT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --)        shift; QUERY="$*"; break ;;
    -*)        echo "error: unknown flag: $1" >&2; exit 2 ;;
    *)         QUERY="$1"; shift ;;
  esac
done

[[ -z "$QUERY" ]] && { echo "error: missing query" >&2; usage >&2; exit 2; }

if ! grep -q "^[[:space:]]*machine[[:space:]]\+$HOST" "$HOME/.netrc" 2>/dev/null; then
  echo "error: no entry for $HOST in ~/.netrc (see $0 --help)" >&2
  exit 1
fi

if $CQL_MODE; then
  CQL="$QUERY"
else
  esc=${QUERY//\\/\\\\}
  esc=${esc//\"/\\\"}
  CQL="text ~ \"$esc\" AND type = \"page\""
  [[ -n "$SPACE" ]] && CQL="$CQL AND space = \"$SPACE\""
fi

RESPONSE=$(curl -sf -n \
  -G "https://$HOST/wiki/rest/api/content/search" \
  --data-urlencode "cql=$CQL" \
  --data-urlencode "limit=$LIMIT") || {
  echo "error: Confluence search failed (check token, .netrc perms, or CQL syntax)" >&2
  exit 1
}

if $JSON_OUT; then
  echo "$RESPONSE"
else
  echo "$RESPONSE" | jq -r --arg host "https://$HOST" \
    '.results[] | [.id, .title, ($host + "/wiki" + ._links.webui)] | @tsv'
fi
