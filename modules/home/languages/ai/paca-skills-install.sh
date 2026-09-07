# Installs Paca's bundled + plugin-contributed skills into
# ~/.claude/skills/<name>/SKILL.md, verbatim (frontmatter intact), from a
# running Paca instance's API. Reduced, Claude-only port of
# Paca-AI/paca's scripts/install-paca-skills.sh — see that script for the
# full multi-platform version this was ported from, and paca.nix's own
# comment for why this runs at home-manager activation time instead of
# Nix build time.
#
# Best-effort throughout: a network problem here should not fail a whole
# `home-manager switch` over a skills refresh, so every failure path warns
# and returns rather than exiting nonzero.

set -uo pipefail

PACA_API_URL="https://paca.home.jeffutter.com"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"

warn() { echo "[paca-skills] $*" >&2; }

mkdir -p "${CLAUDE_SKILLS_DIR}"

# install_skill NAME RAW_SKILL_MD_FILE
install_skill() {
  local name="$1" raw="$2"
  mkdir -p "${CLAUDE_SKILLS_DIR}/${name}"
  cp "${raw}" "${CLAUDE_SKILLS_DIR}/${name}/SKILL.md"
}

# ── Bundled skills ───────────────────────────────────────────────────────────

skills_json="$(mktemp)"
trap 'rm -f "${skills_json}"' RETURN
if ! curl -fsSL --max-time 30 "${PACA_API_URL}/api/v1/skills" -o "${skills_json}"; then
  warn "could not reach ${PACA_API_URL}/api/v1/skills — skipping skill install this run."
  exit 0
fi

bundled_count=0
while IFS= read -r skill_obj; do
  name="$(jq -r '.name' <<<"${skill_obj}")"
  [[ -z "${name}" || "${name}" == "null" ]] && continue
  raw="$(mktemp)"
  jq -j '.content' <<<"${skill_obj}" >"${raw}"
  install_skill "${name}" "${raw}"
  rm -f "${raw}"
  bundled_count=$((bundled_count + 1))
done < <(jq -c '.data.skills[]' "${skills_json}")
rm -f "${skills_json}"

if [[ "${bundled_count}" -eq 0 ]]; then
  warn "${PACA_API_URL} returned no bundled skills — leaving whatever was already installed."
  exit 0
fi

# ── Plugin-contributed skills ────────────────────────────────────────────────
#
# Mirrors upstream's plugin_baseurl_allowed SSRF guard: a plugin manifest
# is admin-installed but still untrusted content, and what its baseUrl
# points at gets installed verbatim as a local skill file. https:// is
# rejected for loopback/private/link-local hosts; http:// is allowed only
# for localhost/loopback or PACA_API_URL's own host. This is a static
# hostname-string check (no DNS resolution) — it won't catch a hostname
# that merely *resolves* to a private IP (which is our own case here:
# paca.home.jeffutter.com does exactly that), only a baseUrl that's
# literally written as one. Kept anyway for the case it does catch: a
# plugin declaring some other, genuinely external host.
api_host="${PACA_API_URL#*://}"
api_host="${api_host%%/*}"
api_host="${api_host%%:*}"
api_host="$(printf '%s' "${api_host}" | tr '[:upper:]' '[:lower:]')"

baseurl_allowed() {
  local url="$1" scheme host
  scheme="${url%%://*}"
  host="${url#*://}"
  host="${host#*@}"
  host="${host%%/*}"
  host="${host%%:*}"
  host="$(printf '%s' "${host}" | tr '[:upper:]' '[:lower:]')"
  case "${scheme}" in
    https)
      case "${host}" in
        localhost | 127.* | 10.* | 169.254.* | 0.0.0.0 | ::1 | \[::1\]) return 1 ;;
        172.1[6-9].* | 172.2[0-9].* | 172.3[01].*) return 1 ;;
        192.168.*) return 1 ;;
      esac
      return 0
      ;;
    http)
      [[ "${host}" == "localhost" || "${host}" == "127.0.0.1" || "${host}" == "${api_host}" ]]
      ;;
    *) return 1 ;;
  esac
}

plugins_json="$(mktemp)"
if curl -fsSL --max-time 30 "${PACA_API_URL}/api/v1/plugins" -o "${plugins_json}"; then
  while IFS=$'\t' read -r plugin_name base_url skill_name; do
    [[ -z "${skill_name}" ]] && continue
    case "${base_url}" in
      http://* | https://*)
        if ! baseurl_allowed "${base_url}"; then
          warn "plugin '${plugin_name}' declares skills baseUrl '${base_url}', which resolves to a disallowed host — skipping its skills"
          continue
        fi
        resolved_base="${base_url}"
        ;;
      *) resolved_base="${PACA_API_URL}${base_url}" ;;
    esac
    skill_raw="$(mktemp)"
    if curl -fsSL --max-time 30 "${resolved_base%/}/${skill_name}/SKILL.md" -o "${skill_raw}"; then
      install_skill "${skill_name}" "${skill_raw}"
    else
      warn "failed to fetch skill '${skill_name}' from plugin '${plugin_name}' — skipping it."
    fi
    rm -f "${skill_raw}"
  done < <(jq -r '
    (.data.plugins // [])[]
    | select(.enabled == true)
    | select(.manifest.skills != null)
    | .name as $p
    | (.manifest.skills.baseUrl // "") as $b
    | (.manifest.skills.names // [])[]
    | [$p, $b, .] | @tsv
  ' "${plugins_json}")
else
  warn "could not reach ${PACA_API_URL}/api/v1/plugins — bundled skills were still installed, plugin skills were not."
fi
rm -f "${plugins_json}"

echo "[paca-skills] installed ${bundled_count} bundled skill(s) (+ any plugin-contributed) to ${CLAUDE_SKILLS_DIR}"
