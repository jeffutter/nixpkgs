# PostToolUse hook: lint the prose an agent just wrote with Vale and feed error-level alerts back.
# Always uses ~/.vale.ini; project .vale.ini rules are left to the project's own commit hooks.

input=$(cat)

file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[ -n "$file" ] && [ -f "$file" ] || exit 0
case "${file,,}" in
  *.md | *.mdx | *.markdown | *.txt | *.rst | *.adoc) ;;
  *) exit 0 ;;
esac

# Report only alerts on lines the agent wrote, so an edit does not surface the whole file's backlog.
ranges=$(jq -c --rawfile body "$file" '
  def span($s):
    ($body | index($s)) as $i
    | if $s == "" or $i == null then empty
      else ($body[0:$i] | split("\n") | length) as $start
        | [$start, $start + ($s | split("\n") | length) - 1]
      end;
  if .tool_name == "Write" then [[1, ($body | split("\n") | length)]]
  elif .tool_name == "Edit" then [span(.tool_input.new_string // "")]
  elif .tool_name == "MultiEdit" then [.tool_input.edits[]? | span(.new_string // "")]
  else [] end' <<<"$input") || exit 0
[ "$ranges" != "[]" ] || exit 0

config="$HOME/.vale.ini"
[ -f "$config" ] || exit 0
cd "$(dirname "$file")" || exit 0
alerts=$(vale --config="$config" --no-exit --no-wrap --output=JSON --minAlertLevel=error "$file" 2>/dev/null) || exit 0

report=$(jq -r --argjson ranges "$ranges" '
  [.[]? | arrays | .[]
   | select(.Check != "Vale.Spelling")
   | select(.Line as $l | any($ranges[]; $l >= .[0] and $l <= .[1]))
   | "line \(.Line): \(.Check): \(.Message)"]
  | .[:30] | .[]' <<<"$alerts" 2>/dev/null)
[ -n "$report" ] || exit 0

reason="Vale flagged prose you just wrote in $file:
$report
Rewrite the flagged text. If an alert is a false positive in this context, leave that line as is."
jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
