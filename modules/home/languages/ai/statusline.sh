# Claude Code status line. Reads session JSON on stdin, prints one line.
# Segments carry a priority; when the line is wider than $COLUMNS the least
# important segments are dropped first, so narrow panes keep the essentials.

export LC_ALL=en_US.UTF-8

input=$(cat)
now=$(date +%s)

IFS=$'\x1f' read -r cwd model effort fast agent pr_num pr_url pr_state \
  ctx_pct ctx_size ctx_used cost dur_ms rl5 rl7 \
  c_warm c_ttl c_exp c_hit c_miss_at c_miss_cause <<<"$(
    jq -r '[
      (.workspace.current_dir // .cwd // ""),
      (.model.display_name // ""),
      (.effort.level // ""),
      (.fast_mode // false),
      (.agent.name // ""),
      (.pr.number // ""),
      (.pr.url // ""),
      (.pr.review_state // ""),
      (.context_window.used_percentage // 0 | floor),
      (.context_window.context_window_size // 0),
      ((.context_window.used_percentage // 0) * (.context_window.context_window_size // 0) / 100 | floor),
      (.cost.total_cost_usd // 0),
      (.cost.total_duration_ms // 0),
      (.rate_limits.five_hour.used_percentage // "" | if . == "" then . else floor end),
      (.rate_limits.seven_day.used_percentage // "" | if . == "" then . else floor end),
      (if .prompt_cache then (.prompt_cache.warm // false) else "" end),
      (.prompt_cache.ttl // ""),
      (.prompt_cache.expires_at // ""),
      (.prompt_cache.hit_ratio // "" | if . == "" then . else (. * 100 | floor) end),
      (.prompt_cache.last_miss_at // ""),
      (.prompt_cache.last_miss_cause.causes // [] | join(","))
    ] | map(tostring) | join("\u001f")' <<<"$input"
  )"

esc=$'\e'
reset="${esc}[0m"
dim="${esc}[2m"
red="${esc}[31m"
green="${esc}[32m"
yellow="${esc}[33m"
blue="${esc}[34m"
magenta="${esc}[35m"
cyan="${esc}[36m"

# Pick green / yellow / red for a 0-100 "used" value.
level_color() {
  if (($1 >= $3)); then printf '%s' "$red"
  elif (($1 >= $2)); then printf '%s' "$yellow"
  else printf '%s' "$green"; fi
}

human_tokens() {
  if (($1 >= 1000000)); then printf '%sM' "$(($1 / 1000000))"
  elif (($1 >= 1000)); then printf '%sk' "$(($1 / 1000))"
  else printf '%s' "$1"; fi
}

human_secs() {
  local s=$1
  if ((s >= 3600)); then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif ((s >= 60)); then printf '%dm' $((s / 60))
  else printf '<1m'; fi
}

# Git branch and dirty flag, cached for a few seconds so large repos stay fast.
git_info() {
  local dir=$1 key cache branch dirty
  [[ -n $dir && -d $dir ]] || return 0
  key=$(printf '%s' "$dir" | cksum | cut -d' ' -f1)
  cache="${TMPDIR:-/tmp}/claude-statusline-git-$key"
  if [[ -f $cache ]] && (($(date +%s) - $(stat -c %Y "$cache") < 5)); then
    cat "$cache"
    return 0
  fi
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    : >"$cache"
    return 0
  fi
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  [[ -n $branch ]] || branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  dirty=""
  if [[ -n $(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -n1) ]]; then
    dirty="*"
  fi
  printf '%s%s' "$branch" "$dirty" | tee "$cache"
}

# Segment storage for the line being built: text, visible width, priority.
seg_text=()
seg_width=()
seg_prio=()

add() { # add <priority> <plain text> <colored text>
  [[ -n $2 ]] || return 0
  seg_prio+=("$1")
  seg_width+=("${#2}")
  seg_text+=("$3")
}

# Drop the highest priority number until the line fits, then print it.
emit() {
  local cols=${COLUMNS:-200} sep=2 total i worst
  # Claude Code pads the status line; keep a margin so it never wraps.
  cols=$((cols - 4))
  while :; do
    total=0
    for i in "${!seg_text[@]}"; do total=$((total + seg_width[i] + sep)); done
    total=$((total - sep))
    ((total <= cols || ${#seg_text[@]} <= 1)) && break
    worst=""
    for i in "${!seg_text[@]}"; do
      if [[ -z $worst ]] || ((seg_prio[i] > seg_prio[worst])); then worst=$i; fi
    done
    unset 'seg_text[worst]' 'seg_width[worst]' 'seg_prio[worst]'
  done
  local out="" first=1
  for i in "${!seg_text[@]}"; do
    ((first)) || out+="  "
    out+="${seg_text[i]}"
    first=0
  done
  [[ -n $out ]] && printf '%s%s\n' "$out" "$reset"
  seg_text=() seg_width=() seg_prio=()
}

dir_name=${cwd##*/}
add 1 "$dir_name" "${blue}${dir_name}${reset}"

branch=$(git_info "$cwd")
if [[ -n $branch ]]; then
  add 2 "⎇ $branch" "${magenta}⎇ ${branch}${reset}"
fi

if [[ -n $pr_num ]]; then
  pr_plain="PR #$pr_num${pr_state:+ $pr_state}"
  case $pr_state in
    approved) pr_color=$green ;;
    changes_requested) pr_color=$red ;;
    draft) pr_color=$dim ;;
    *) pr_color=$yellow ;;
  esac
  pr_colored="${pr_color}${pr_plain}${reset}"
  if [[ -n $pr_url ]]; then
    pr_colored="${esc}]8;;${pr_url}${esc}\\${pr_colored}${esc}]8;;${esc}\\"
  fi
  add 5 "$pr_plain" "$pr_colored"
fi

model_plain="$model${effort:+ · $effort}"
[[ $fast == true ]] && model_plain+=" ⚡"
add 3 "$model_plain" "${cyan}${model_plain}${reset}"

if [[ -n $agent ]]; then
  add 6 "@$agent" "${dim}@${agent}${reset}"
fi

# Measure against the auto-compact point when it is below the model's window.
acw=${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}
if [[ $acw =~ ^[0-9]+$ ]] && ((acw > 0 && (ctx_size == 0 || acw < ctx_size))); then
  ctx_size=$acw
  ctx_pct=$((ctx_used * 100 / acw))
fi

bar_len=10
filled=$((ctx_pct * bar_len / 100))
((filled > bar_len)) && filled=$bar_len
printf -v bar_on '%*s' "$filled" ''
printf -v bar_off '%*s' "$((bar_len - filled))" ''
bar_on=${bar_on// /▓}
bar_off=${bar_off// /░}
ctx_color=$(level_color "$ctx_pct" 50 75)
add 7 "$bar_on$bar_off" "${ctx_color}${bar_on}${dim}${bar_off}${reset}"
ctx_plain="${ctx_pct}%"
((ctx_size > 0)) && ctx_plain+=" of $(human_tokens "$ctx_size")"
add 1 "$ctx_plain" "${ctx_color}${ctx_plain}${reset}"

if [[ -n $c_warm ]]; then
  if [[ $c_warm == true && -n $c_exp ]] && ((c_exp > now)); then
    left=$((c_exp - now))
    case $c_ttl in
      5m) ttl_secs=300 ;;
      *) ttl_secs=3600 ;;
    esac
    left_pct=$((left * 100 / ttl_secs))
    if ((left_pct <= 10)); then cache_color=$red
    elif ((left_pct <= 25)); then cache_color=$yellow
    else cache_color=$green; fi
    cache_plain="cache $(human_secs "$left")"
  else
    cache_color=$red
    cache_plain="cache cold"
  fi
  add 2 "$cache_plain" "${cache_color}${cache_plain}${reset}"
  if [[ -n $c_hit ]]; then
    add 6 "${c_hit}% hit" "${dim}${c_hit}% hit${reset}"
  fi
  # Show the last miss cause for 15 minutes after it happens.
  if [[ -n $c_miss_cause && -n $c_miss_at ]] && ((now - c_miss_at < 900)); then
    add 8 "miss: $c_miss_cause" "${yellow}miss: ${c_miss_cause}${reset}"
  fi
fi

printf -v cost_plain '$%.2f' "$cost"
add 4 "$cost_plain" "${cost_plain}"
dur_plain=$(human_secs $((dur_ms / 1000)))
add 7 "$dur_plain" "${dim}${dur_plain}${reset}"

if [[ -n $rl5 || -n $rl7 ]]; then
  rl_plain="" rl_colored=""
  if [[ -n $rl5 ]]; then
    rl_plain+="5h ${rl5}%"
    rl_colored+="${dim}5h${reset} $(level_color "$rl5" 60 85)${rl5}%${reset}"
  fi
  if [[ -n $rl7 ]]; then
    [[ -n $rl_plain ]] && rl_plain+=" · " && rl_colored+=" · "
    rl_plain+="7d ${rl7}%"
    rl_colored+="${dim}7d${reset} $(level_color "$rl7" 60 85)${rl7}%${reset}"
  fi
  add 4 "$rl_plain" "$rl_colored"
fi
emit
