// One-shot mod for a key that needs command arguments: keys.json can only pass one value,
// so the key runs `mod.open:<this mod>` and this overlay runs ACTION, then closes itself.
import { View, div } from "gpui-kit";
import { closeOverlay, focused, openOverlay, props, run } from "herdr";

const ACTION = @action@;

export default class Action extends View {
  init() {
    const { overlay } = props() ?? {};
    // `herdr-app check` renders without an overlay; do nothing there.
    if (!overlay) return;
    closeOverlay(overlay);
    if (ACTION.overlay) {
      const f = focused();
      openOverlay({ ...ACTION.overlay, props: { ...ACTION.overlay.props, space: f?.space, folder: f?.cwd } });
    } else {
      run(ACTION.command, ACTION.args);
    }
  }

  render() {
    return div();
  }
}
