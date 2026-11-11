// The ctrl-a prefix table and how to run an entry, pasted by Nix into the prefix and prefix-help
// mods. herdr-app refuses imports that symlink outside a mod folder, which every Nix file does.
// Uses focused, hc, openOverlay and run, which the including mod imports from "herdr".

// How long the prefix popup stays open for another press of a `repeat` entry.
const REPEAT_MS = 500;

// [{ key, section, label, group?, repeat?, command, args } | { ..., overlay } | { ..., keys }]
// in display order.
const BINDINGS = @bindings@;

const BY_KEY = new Map(BINDINGS.map((b) => [b.key, b]));
const MODIFIERS = new Set(["shift", "control", "ctrl", "alt", "cmd", "platform", "function", "fn"]);

// The entry for a keypress, by keystroke or, for keys that type a character, that character.
// Returns null for modifier-only presses and key repeats, undefined for unbound keys.
function lookup(e) {
  if (MODIFIERS.has(e.key) || e.is_held) return null;
  return BY_KEY.get(e.keystroke) ?? (e.key_char ? BY_KEY.get(e.key_char) : undefined);
}

// Replays a keypress the popup swallowed into `terminal`.
function forward(e, terminal) {
  if (!terminal) return;
  const mods = /^((?:(?:ctrl|alt|cmd|shift)-)*)/.exec(e.keystroke)[1];
  if (e.key_char && e.key_char.length === 1 && e.key_char >= " " && !/ctrl|alt|cmd/.test(mods)) {
    hc(["send", terminal, e.key_char]);
  } else {
    hc(["keys", terminal, mods.replaceAll("-", "+") + e.keystroke.slice(mods.length)]);
  }
}

// `terminal` receives { keys } entries: the one that was focused when ctrl-a was pressed.
function dispatch(action, terminal) {
  if (action.keys) {
    if (terminal) hc(["keys", terminal, action.keys]);
  } else if (action.overlay) {
    const f = focused();
    openOverlay({ ...action.overlay, props: { ...action.overlay.props, space: f?.space, folder: f?.cwd } });
  } else {
    run(action.command, action.args ?? {});
  }
}
