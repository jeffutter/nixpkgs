# voice-mode: per-session spoken replies for Claude Code.
#   voice-mode set SESSION on [kokoro|breeze|higgs|say] | off | status
#   voice-mode inject   UserPromptSubmit hook: adds listening rules, silences old audio
#   voice-mode speak    Stop hook: reads the reply aloud
# State lives in /tmp/claude-<uid>/voice-mode/<session>.on (content = engine).
# VOICE_TTS is set by the Nix wrapper to the tts-speech skill's `tts` binary.

dir="/tmp/claude-$(id -u)/voice-mode"
mkdir -p "$dir"

valid_session() {
  [[ $1 =~ ^[A-Za-z0-9-]+$ ]] || {
    echo "voice-mode: bad session id" >&2
    exit 1
  }
}

stop_playback() {
  local pidfile="$dir/$1.pid"
  if [[ -f $pidfile ]]; then
    local pid
    pid=$(<"$pidfile")
    /usr/bin/pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
    rm -f "$pidfile"
  fi
}

cmd=${1:-}
case $cmd in
set)
  sid=${2:-}
  valid_session "$sid"
  action=${3:-on}
  engine=${4:-kokoro}
  case $action in
  on)
    case $engine in
    kokoro | breeze | higgs | say) ;;
    *)
      echo "voice-mode: engine must be kokoro, breeze, higgs or say" >&2
      exit 1
      ;;
    esac
    printf '%s\n' "$engine" >"$dir/$sid.on"
    echo "voice mode on ($engine). It starts with your next prompt."
    ;;
  off)
    rm -f "$dir/$sid.on"
    stop_playback "$sid"
    echo "voice mode off"
    ;;
  status)
    if [[ -f $dir/$sid.on ]]; then
      echo "voice mode on ($(<"$dir/$sid.on"))"
    else
      echo "voice mode off"
    fi
    ;;
  *)
    echo "voice-mode: use on [engine], off or status" >&2
    exit 1
    ;;
  esac
  ;;

inject)
  sid=$(jq -r '.session_id // empty')
  [[ -n $sid ]] || exit 0
  valid_session "$sid"
  [[ -f $dir/$sid.on ]] || exit 0
  stop_playback "$sid"
  cat <<'EOF'
VOICE MODE is on. Your reply is read aloud to the user, who is listening and
talking, not reading.
- Talk like a person in a conversation. Short sentences. Plain prose.
- No tables, bullet lists, headings, code, file paths or URLs in the spoken part.
- Keep the spoken part under about 120 words. Lead with the answer.
- Spell out symbols and numbers the way you would say them.
- End with one short question or a clear next step when the topic is open.
- Put anything that must be seen (code, paths, links, tables, long lists) after
  a line that holds only [screen]. Text after that line is not spoken.
- Do the work as usual. Use skills and tools as needed. Only the final reply is spoken.
EOF
  ;;

speak)
  input=$(cat)
  sid=$(jq -r '.session_id // empty' <<<"$input")
  [[ -n $sid ]] || exit 0
  valid_session "$sid"
  [[ -f $dir/$sid.on ]] || exit 0
  engine=$(<"$dir/$sid.on")

  text=$(jq -r '.last_assistant_message // empty' <<<"$input")
  if [[ -z $text ]]; then
    transcript=$(jq -r '.transcript_path // empty' <<<"$input")
    if [[ -f $transcript ]]; then
      text=$(jq -rs '[.[] | select(.type == "assistant")] | last
        | [.message.content[]? | select(.type == "text") | .text] | join("\n")' "$transcript")
    fi
  fi
  [[ -n $text ]] || exit 0

  # shellcheck disable=SC2016
  # Drop everything after [screen], fenced code, links, URLs and markdown marks.
  text=$(
    printf '%s\n' "$text" |
      awk '/^\[screen\][[:space:]]*$/ { exit } { print }' |
      awk '/^```/ { skip = !skip; next } !skip' |
      sed -E 's/`([^`]*)`/\1/g; s/\[([^]]*)\]\([^)]*\)/\1/g; s#https?://[^ ]+##g; s/^[#>*[:space:]-]+//; s/[*|]//g'
  )
  text=${text:0:1800}
  [[ -n ${text//[[:space:]]/} ]] || exit 0

  stop_playback "$sid"
  out="$dir/$sid.mp3"
  args=(say "$text" --model "$engine" --out "$out")
  # tts defaults to voice jeff, which only breeze and higgs have.
  case $engine in
  kokoro) args+=(--voice af_heart) ;;
  breeze)
    args+=(--voice jeff
      --option "instruct=Speak in a relaxed, friendly, conversational tone, like explaining something interesting to a colleague."
      --option guidance_scale=2)
    ;;
  esac

  (
    if [[ $engine != say ]] && "$VOICE_TTS" "${args[@]}" >/dev/null 2>"$dir/$sid.log"; then
      /usr/bin/afplay "$out"
    else
      /usr/bin/say "$text"
    fi
  ) </dev/null >/dev/null 2>&1 &
  echo $! >"$dir/$sid.pid"
  ;;

*)
  echo "usage: voice-mode set|inject|speak" >&2
  exit 1
  ;;
esac
