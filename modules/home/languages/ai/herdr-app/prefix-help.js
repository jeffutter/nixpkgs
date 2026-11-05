// The ctrl-a prefix keys, opened by ctrl-a ?. A prefix key pressed here closes it and runs.
import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { closeOverlay, focused, hc, openOverlay, props, run, theme } from "herdr";

@prefixLib@

const COLUMNS = [
  ["Tabs", "Spaces", "Agents"],
  ["Panes", "Files and worktrees", "App"],
];
const ARROWS = { left: "←", right: "→", up: "↑", down: "↓" };

function keyName(k) {
  if (ARROWS[k]) return ARROWS[k];
  if (/^[A-Z]$/.test(k)) return `shift-${k.toLowerCase()}`;
  return k;
}

// One row per label (or group), in list order, keys joined: "h  ←" for Focus pane left.
function rows(section) {
  const byLabel = new Map();
  for (const b of BINDINGS) {
    if (b.section !== section) continue;
    const id = b.group ?? b.label;
    const row = byLabel.get(id) ?? { label: b.label, keys: [] };
    if (b.group) row.keys = [b.group];
    else row.keys.push(keyName(b.key));
    byLabel.set(id, row);
  }
  return [...byLabel.values()];
}

export default class PrefixHelp extends View {
  init(_props, cx) {
    this.terminal = focused()?.terminal;
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  close() {
    closeOverlay(props()?.overlay);
  }

  press(e) {
    if (e.keystroke === "escape" || e.keystroke === "q") return this.close();
    const action = lookup(e);
    if (!action) return;
    this.close();
    // ? opens this panel; pressed here it only closes it.
    if (action.key !== "?") dispatch(action, this.terminal);
  }

  render() {
    const t = theme();
    return v_flex()
      .id("prefix-help")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        cx.stop_propagation?.();
        this.press(e);
      })
      .size_full()
      .p(16)
      .gap(12)
      .text_size(13)
      .text_color(t.foreground)
      .overflow_y_scrollbar()
      .child(
        h_flex()
          .justify_between()
          .child(div().font_semibold().text_size(15).child("ctrl-a keys"))
          .child(div().text_color(t.dim).child("press a key to run it - esc closes")),
      )
      .child(
        h_flex()
          .items_start()
          .gap(24)
          .children(
            COLUMNS.map((sections) =>
              v_flex()
                .flex_1()
                .gap(12)
                .children(
                  sections.map((section) =>
                    v_flex()
                      .gap(4)
                      .child(div().text_color(t.accent).font_semibold().child(section))
                      .children(
                        rows(section).map((r) =>
                          h_flex()
                            .gap(12)
                            .child(div().w(100).flex_none().text_color(t.muted).child(r.keys.join("  ")))
                            .child(div().flex_1().child(r.label)),
                        ),
                      ),
                  ),
                ),
            ),
          ),
      );
  }
}
