{ pkgs, ... }:
let
  # ── Helper scripts ────────────────────────────────────────────────────────

  # Network speed: reads /proc/net/dev, diffs against a tmp state file
  # Usage: eww-net-speed <interface> rx|tx
  netSpeedScript = pkgs.writeShellScript "eww-net-speed" ''
    IFACE="$1"
    DIR="$2"
    TMPFILE="/tmp/eww-net-$IFACE-$DIR"
    [ "$DIR" = "rx" ] && COL=2 || COL=10

    CUR=$(${pkgs.gawk}/bin/awk -v iface="$IFACE:" -v col="$COL" \
      '$1==iface{print $col}' /proc/net/dev)
    NOW=$(${pkgs.coreutils}/bin/date +%s%3N)

    if [ -f "$TMPFILE" ] && [ -n "$CUR" ]; then
      read -r PREV_B PREV_T < "$TMPFILE"
      DIFF_B=$(( CUR - PREV_B ))
      DIFF_T=$(( NOW - PREV_T ))
      if [ "$DIFF_T" -gt 0 ] && [ "$DIFF_B" -ge 0 ]; then
        SPD=$(( DIFF_B * 1000 / DIFF_T ))
      else
        SPD=0
      fi
    else
      SPD=0
    fi

    [ -n "$CUR" ] && echo "$CUR $NOW" > "$TMPFILE"
    ${pkgs.gawk}/bin/awk -v s="$SPD" 'BEGIN {
      if      (s >= 1048576) printf "%.1fM\n", s/1048576
      else if (s >= 1024)    printf "%.0fK\n", s/1024
      else                   printf "%dB\n",   s
    }'
  '';

  # Hyprland workspace list via IPC; emits a JSON array on every workspace event
  workspacesScript = pkgs.writeShellScript "eww-workspaces" ''
    HYPRCTL="${pkgs.hyprland}/bin/hyprctl"
    SOCAT="${pkgs.socat}/bin/socat"
    JQ="${pkgs.jq}/bin/jq"

    emit() {
      AID=$($HYPRCTL -j activeworkspace | $JQ '.id')
      $HYPRCTL -j workspaces | $JQ -c --argjson aid "$AID" '
        ([range(1;6) | {id:., name:(.|tostring)}]) as $base |
        ($base + .) | group_by(.id) | map(last) | sort_by(.id) |
        map(. + {active: (.id == $aid)})
      '
    }

    emit
    $SOCAT -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | \
      while IFS= read -r _; do emit; done
  '';

  # Volume JSON via pactl subscribe; emits {vol, mute} on every sink change
  volumeScript = pkgs.writeShellScript "eww-volume" ''
    PACTL="${pkgs.pulseaudio}/bin/pactl"

    emit() {
      VOL=$($PACTL get-sink-volume @DEFAULT_SINK@ | \
            ${pkgs.gnugrep}/bin/grep -oP '\d+(?=%)' | head -1)
      MUTE=$($PACTL get-sink-mute @DEFAULT_SINK@ | \
             ${pkgs.gnugrep}/bin/grep -c "yes" || true)
      echo "{\"vol\": ''${VOL:-0}, \"mute\": $([ "''${MUTE:-0}" -gt 0 ] && echo true || echo false)}"
    }

    emit
    $PACTL subscribe 2>/dev/null | \
      ${pkgs.gnugrep}/bin/grep --line-buffered "sink" | \
      while IFS= read -r _; do emit; done
  '';

  # CPU usage %: stateful diff of /proc/stat
  cpuScript = pkgs.writeShellScript "eww-cpu" ''
    TMPFILE="/tmp/eww-cpu"
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    TOT=$(( user+nice+system+idle+iowait+irq+softirq+steal ))
    USED=$(( user+nice+system+irq+softirq+steal ))

    if [ -f "$TMPFILE" ]; then
      read -r PT PU < "$TMPFILE"
      DT=$(( TOT - PT ))
      DU=$(( USED - PU ))
      if [ "$DT" -gt 0 ]; then
        ${pkgs.gawk}/bin/awk -v u="$DU" -v t="$DT" 'BEGIN{printf "%.0f\n", u/t*100}'
      else
        echo 0
      fi
    else
      echo 0
    fi

    echo "$TOT $USED" > "$TMPFILE"
  '';

  # Battery JSON: capacity, status, icon glyph, CSS class
  batteryScript = pkgs.writeShellScript "eww-battery" ''
    CAP=$(cat /sys/class/power_supply/BAT0/capacity  2>/dev/null || echo 0)
    STA=$(cat /sys/class/power_supply/BAT0/status    2>/dev/null || echo Unknown)

    case "$STA" in
      Charging|Full) ICON="󰂄"; CLS=charging ;;
      *)
        if   [ "$CAP" -le 10 ]; then ICON="󰂃"; CLS=critical
        elif [ "$CAP" -le 20 ]; then ICON="󰁺"; CLS=warning
        elif [ "$CAP" -le 40 ]; then ICON="󰁼"; CLS=low
        elif [ "$CAP" -le 60 ]; then ICON="󰁾"; CLS=normal
        elif [ "$CAP" -le 80 ]; then ICON="󰂀"; CLS=normal
        else                         ICON="󰁹"; CLS=good
        fi ;;
    esac

    echo "{\"capacity\":$CAP,\"status\":\"$STA\",\"icon\":\"$ICON\",\"class\":\"$CLS\"}"
  '';

  # WiFi JSON: connected, ssid, signal%
  wifiScript = pkgs.writeShellScript "eww-wifi" ''
    INFO=$(${pkgs.iw}/bin/iw dev wlo1 link 2>/dev/null)
    SSID=$(echo "$INFO"   | ${pkgs.gnugrep}/bin/grep -oP '(?<=SSID: ).*'     || true)
    SIGNAL=$(echo "$INFO" | ${pkgs.gnugrep}/bin/grep -oP '(?<=signal: )-?\d+' || true)

    if [ -z "$SSID" ]; then
      echo '{"connected":false,"ssid":"N/A","signal":0}'
    else
      PCT=$(${pkgs.gawk}/bin/awk -v s="''${SIGNAL:--90}" \
        'BEGIN{p=int((s+90)/60*100); if(p>100)p=100; if(p<0)p=0; print p}')
      SSID_ESC=$(echo "$SSID" | ${pkgs.gnused}/bin/sed 's/"/\\"/g')
      echo "{\"connected\":true,\"ssid\":\"$SSID_ESC\",\"signal\":$PCT}"
    fi
  '';

  # Volume scroll: accepts "up" or "down" from eww's {} substitution
  volScrollScript = pkgs.writeShellScript "eww-vol-scroll" ''
    if [ "$1" = "up" ]; then
      ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%
    else
      ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%
    fi
  '';

in
{
  programs.eww = {
    enable = true;
    package = pkgs.eww;
  };

  # ── eww.yuck ──────────────────────────────────────────────────────────────

  home.file.".config/eww/eww.yuck".text = ''
    ;; ─── Variables ────────────────────────────────────────────────────────────

    (deflisten workspaces :initial "[]"
      `${workspacesScript}`)

    (deflisten vol-json :initial "{\"vol\": 0, \"mute\": false}"
      `${volumeScript}`)

    (defpoll clock     :interval "10s"
      `${pkgs.coreutils}/bin/date '+%a %m/%d %I:%M %p'`)

    (defpoll cpu       :interval "2s"
      `${cpuScript}`)

    (defpoll memory    :interval "5s"
      `${pkgs.procps}/bin/free | ${pkgs.gawk}/bin/awk '/^Mem:/{printf "%.0f",$3/$2*100}'`)

    (defpoll disk      :interval "60s"
      `${pkgs.coreutils}/bin/df / | ${pkgs.gawk}/bin/awk 'NR==2{gsub(/%/,"",$5);print $5}'`)

    (defpoll battery   :interval "30s"
      `${batteryScript}`)

    (defpoll backlight :interval "2s"
      `${pkgs.gawk}/bin/awk 'BEGIN{c=int(ARGV[1]); m=int(ARGV[2]); printf "%.0f", c/m*100}' \
       $(cat /sys/class/backlight/intel_backlight/brightness) \
       $(cat /sys/class/backlight/intel_backlight/max_brightness)`)

    (defpoll wifi      :interval "5s"
      `${wifiScript}`)

    (defpoll wifi-rx   :interval "2s"  `${netSpeedScript} wlo1 rx`)
    (defpoll wifi-tx   :interval "2s"  `${netSpeedScript} wlo1 tx`)
    (defpoll ts-rx     :interval "2s"  `${netSpeedScript} tailscale0 rx`)
    (defpoll ts-tx     :interval "2s"  `${netSpeedScript} tailscale0 tx`)

    (defpoll ts-on     :interval "5s"
      `${pkgs.iproute2}/bin/ip link show tailscale0 2>/dev/null | \
       ${pkgs.gnugrep}/bin/grep -q "state UP" && echo true || echo false`)

    ;; ─── Window ───────────────────────────────────────────────────────────────

    (defwindow bar
      :monitor 0
      :geometry (geometry :x "0%"
                          :y "0%"
                          :width "100%"
                          :height "30px"
                          :anchor "top center")
      :stacking "fg"
      :exclusive true
      :focusable false
      (bar-widget))

    ;; ─── Layout ───────────────────────────────────────────────────────────────

    (defwidget bar-widget []
      (centerbox :orientation "h" :class "bar"
        (bar-left)
        (bar-center)
        (bar-right)))

    (defwidget bar-left []
      (box :orientation "h" :space-evenly false :halign "start" :class "bar-left"
        (workspaces-widget)))

    (defwidget bar-center []
      (box :orientation "h" :space-evenly false :halign "center" :class "bar-center"
        (clock-widget)))

    (defwidget bar-right []
      (box :orientation "h" :space-evenly false :halign "end" :class "bar-right" :spacing 0
        (ts-widget)
        (wifi-widget)
        (disk-widget)
        (memory-widget)
        (cpu-widget)
        (volume-widget)
        (backlight-widget)
        (battery-widget)
        (systray :class "module tray" :icon-size 16 :spacing 4 :prepend-new false)))

    ;; ─── Workspaces ───────────────────────────────────────────────────────────

    (defwidget workspaces-widget []
      (box :orientation "h" :space-evenly false :class "workspaces" :spacing 2
        (for ws in workspaces
          (button
            :class {"ws-btn" + (ws.active ? " active" : "")}
            :onclick {"${pkgs.hyprland}/bin/hyprctl dispatch workspace " + ws.id}
            {ws.name}))))

    ;; ─── Clock ────────────────────────────────────────────────────────────────

    (defwidget clock-widget []
      (label :class "module clock" :text clock))

    ;; ─── System stats ─────────────────────────────────────────────────────────

    (defwidget cpu-widget []
      (box :orientation "h" :space-evenly false :class "module" :spacing 4
        (label :class "icon cpu-icon" :text "󰻠")
        (label :text {cpu + "%"})))

    (defwidget memory-widget []
      (box :orientation "h" :space-evenly false :class "module" :spacing 4
        (label :class "icon mem-icon" :text "󰍛")
        (label :text {memory + "%"})))

    (defwidget disk-widget []
      (box :orientation "h" :space-evenly false :class "module" :spacing 4
        (label :class "icon disk-icon" :text "󰋊")
        (label :text {disk + "%"})))

    ;; ─── Network ──────────────────────────────────────────────────────────────

    (defwidget wifi-widget []
      (box :orientation "h" :space-evenly false :class "module" :spacing 4
        (label :class "icon net-icon"
               :text {wifi.connected ? "󰤨" : "󰤭"})
        (label :class "ssid" :text {wifi.ssid})
        (label :class "dim"  :text {"↓" + wifi-rx + " ↑" + wifi-tx})))

    (defwidget ts-widget []
      (box :orientation "h" :space-evenly false :class "module"
           :visible {ts-on == "true"} :spacing 4
        (label :class "icon ts-icon" :text "󰒃")
        (label :class "dim" :text {"↓" + ts-rx + " ↑" + ts-tx})))

    ;; ─── Volume ───────────────────────────────────────────────────────────────

    (defwidget volume-widget []
      (eventbox
        :onclick      "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
        :onrightclick "${pkgs.pavucontrol}/bin/pavucontrol"
        :onscroll     "${volScrollScript} {}"
        (box :orientation "h" :space-evenly false :class "module" :spacing 4
          (label :class {"icon vol-icon" + (vol-json.mute ? " muted" : "")}
                 :text  {vol-json.mute ? "󰖁" : "󰕾"})
          (label :text  {vol-json.vol + "%"}))))

    ;; ─── Backlight ────────────────────────────────────────────────────────────

    (defwidget backlight-widget []
      (box :orientation "h" :space-evenly false :class "module" :spacing 4
        (label :class "icon bright-icon" :text "󰛨")
        (label :text {backlight + "%"})))

    ;; ─── Battery ──────────────────────────────────────────────────────────────

    (defwidget battery-widget []
      (box :orientation "h" :space-evenly false
           :class {"module battery " + battery.class} :spacing 4
        (label :text {battery.icon})
        (label :text {battery.capacity + "%"})))
  '';

  # ── eww.scss ──────────────────────────────────────────────────────────────

  home.file.".config/eww/eww.scss".text = ''
    // Tokyo Night Storm (OLED variant)
    $bg:      #000000;
    $surface: #0d0e14;
    $border:  #1a1b26;
    $fg:      #c0caf5;
    $dim:     #565f89;
    $blue:    #7aa2f7;
    $cyan:    #7dcfff;
    $green:   #9ece6a;
    $yellow:  #e0af68;
    $orange:  #ff9e64;
    $red:     #f7768e;
    $purple:  #bb9af7;
    $r: 8px;

    * {
      font-family: "MonaspiceNe Nerd Font", "Font Awesome 6 Free Solid";
      font-size: 11px;
      color: $fg;
      border: none;
      padding: 0;
      margin: 0;
    }

    .bar {
      background-color: $bg;
      border-bottom: 1px solid $border;
    }

    .bar-left, .bar-right { padding: 2px 4px; }
    .bar-center { padding: 2px; }

    .module {
      background-color: $surface;
      border-radius: $r;
      padding: 2px 8px;
      margin: 2px 3px;
      min-height: 22px;
    }

    // Workspaces
    .workspaces { margin-left: 2px; }

    .ws-btn {
      background-color: transparent;
      color: $dim;
      padding: 2px 8px;
      border-radius: $r;
      min-width: 22px;

      &:hover  { background-color: $border; color: $fg; }
      &.active { background-color: $blue;   color: $bg; }
    }

    // Icons
    .icon        { margin-right: 2px; }
    .cpu-icon    { color: $purple; }
    .mem-icon    { color: $blue;   }
    .disk-icon   { color: $cyan;   }
    .net-icon    { color: $green;  }
    .ts-icon     { color: $cyan;   }
    .vol-icon    { color: $yellow; }
    .vol-icon.muted { color: $dim; }
    .bright-icon { color: $orange; }

    // Misc
    .dim   { color: $dim; font-size: 10px; }
    .ssid  { color: $fg;  }
    .clock { color: $fg;  }

    // Battery states (colour entire module text)
    .battery {
      &.charging label { color: $green;  }
      &.critical label { color: $red;    }
      &.warning  label { color: $yellow; }
      &.good     label { color: $green;  }
    }

    .tray { min-width: 10px; }
  '';
}
