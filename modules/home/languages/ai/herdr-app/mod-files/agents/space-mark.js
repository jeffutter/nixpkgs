
// ---- Appended to my-agents/main.js by the build; it shares that file's imports. ----
// Needs from there: h_flex, spaces, panes, shared, exec.
//
// A space's avatar for an agent row: the letter and color the Spaces sidebar draws.
// A worktree space has no avatar there; it shows its main checkout's, found through git.

// The sidebar's avatar colors by stored name.
const SPACE_MARK_COLORS = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

class SpaceMarks {
  constructor() {
    this.gitInfo = {}; // [machine, folder] -> { repo, linked }, or null (not a repo)
    this.asking = new Set();
  }

  // Reads the spaces and panes once for a render. Returns (agent) => avatar element.
  frame(t, cx) {
    const colors = shared("space.colors") ?? {};
    const allSpaces = spaces();
    const allPanes = panes();

    const gitOf = (s) => {
      const tabIds = new Set((s.tabs ?? []).map((c) => c.id));
      const cwd = allPanes.find((p) => tabIds.has(p.tab) && p.cwd)?.cwd || s.folder;
      if (!cwd) return null;
      const key = JSON.stringify([s.machine ?? null, cwd]);
      if (!(key in this.gitInfo) && !this.asking.has(key)) {
        this.asking.add(key);
        cx.spawn(async (cx) => {
          try {
            const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on: s.machine });
            const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, on: s.machine });
            const repo = common.stdout.trim();
            this.gitInfo[key] = top.code === 0 && common.code === 0
              ? { repo: JSON.stringify([s.machine ?? null, repo]), linked: repo !== `${top.stdout.trim()}/.git` }
              : null;
          } catch { this.gitInfo[key] = null; }
          this.asking.delete(key);
          cx.notify();
        });
      }
      return this.gitInfo[key] ?? null;
    };

    const owner = (id) => {
      const s = allSpaces.find((x) => x.id === id);
      const g = s && gitOf(s);
      if (!g?.linked) return s;
      return allSpaces.find((x) => gitOf(x)?.repo === g.repo && !gitOf(x).linked) ?? s;
    };

    return (a) => {
      const s = owner(a.space);
      const c = colors[s?.id ?? a.space] ?? "ansi6";
      const fill = c.startsWith("#") ? c : (SPACE_MARK_COLORS[c] ?? t[c]);
      return h_flex().size(16).flex_none().rounded(4).bg(fill).items_center().justify_center()
        .text_size(10).font_bold().text_color("#ffffff")
        .child([...(s?.name || a.space_name || "?")][0].toUpperCase());
    };
  }
}
