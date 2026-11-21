// Plays Herdr's blocked/done sounds, but not while the macOS screen is locked.
// settings.json sets sounds.enabled=false so only this mod makes the sound.
import { View, div } from "gpui-kit";
import { agents, exec, playSound } from "herdr";

const SOUND_FOR = { blocked: "blocked", done: "done" };
const LOCKED = /CGSSessionScreenIsLocked<\/key>\s*<true\/>/;

async function screenLocked() {
  try {
    const r = await exec("ioreg", ["-n", "Root", "-d1", "-a"], { timeout: 5000 });
    return LOCKED.test(r.stdout);
  } catch {
    return false;
  }
}

export default class AttentionSound extends View {
  init(_props, cx) {
    this.seen = new Map(agents().map((a) => [a.address, a.status]));
  }

  render(cx) {
    const next = new Map();
    const fire = new Set();
    for (const a of agents()) {
      next.set(a.address, a.status);
      const sound = SOUND_FOR[a.status];
      if (sound && this.seen.get(a.address) !== a.status) fire.add(sound);
    }
    this.seen = next;
    if (fire.size > 0) {
      // "blocked" outranks "done" when both arrive in one render.
      const sound = fire.has("blocked") ? "blocked" : "done";
      cx.spawn(async () => {
        if (!(await screenLocked())) playSound(sound);
      });
    }
    return div();
  }
}
