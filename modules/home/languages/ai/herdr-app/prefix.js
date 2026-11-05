// Prefix mode: keys.json binds ctrl-a to open this popup, which takes the next key.
// herdr-app has no prefix mode, and "ctrl-a n" chords in keys.json never reach a focused terminal.
import { View, div } from "gpui-kit";
import { closeOverlay, focused, hc, openOverlay, props, run, theme } from "herdr";

@prefixLib@

export default class Prefix extends View {
  init(_props, cx) {
    this.done = false;
    this.repeating = false;
    this.generation = 0;
    this.terminal = focused()?.terminal;
    this.handle = cx.focus_handle();
    this.handle.focus();
    // The opening keypress can hand focus back to the terminal; take it again.
    cx.timer.after(50, () => this.handle.focus());
    this.arm(cx, 3000);
  }

  // Close after `ms` unless a later arm() call replaces this timer.
  arm(cx, ms) {
    const generation = ++this.generation;
    cx.timer.after(ms, () => {
      if (generation === this.generation) this.close();
    });
  }

  close() {
    if (this.done) return;
    this.done = true;
    const { overlay } = props() ?? {};
    if (overlay) closeOverlay(overlay);
  }

  press(e, cx) {
    const action = lookup(e);
    if (action === null) return;
    if (action?.repeat) {
      dispatch(action, this.terminal);
      this.repeating = true;
      this.arm(cx, REPEAT_MS);
      cx.notify();
      return;
    }
    this.close();
    if (action) dispatch(action, this.terminal);
  }

  render() {
    const t = theme();
    return div()
      .id("prefix")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        cx.stop_propagation?.();
        this.press(e, cx);
      })
      .size_full()
      .flex()
      .items_center()
      .justify_center()
      .gap(8)
      .text_size(13)
      .text_color(t.muted)
      .child(div().text_color(t.accent).font_semibold().child(this.repeating ? "repeat" : "ctrl-a"))
      .child(this.repeating ? "same keys again - any other key closes" : "waiting for a key - esc cancels");
  }
}
