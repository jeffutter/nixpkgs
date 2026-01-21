{
  pkgs,
  inputs,
  config,
  ...
}:

let
  fabric = inputs.fabric.packages.${pkgs.stdenv.hostPlatform.system}.default;
  beads = inputs.beads;
  beads_bin = beads.packages.${pkgs.system}.default;
  stop-slop = inputs.stop-slop;
  claude-plugins-official = inputs.claude-plugins-official;
  claude-code-wakatime = inputs.claude-code-wakatime;

  claude-skills = pkgs.runCommand "claude-skills" { } ''
    mkdir -p $out
    ln -s ${stop-slop} $out/stop-slop
  '';

  buildTime = pkgs.runCommand "build-time" { } ''
    date -u +"%Y-%m-%dT%H:%M:%S.000Z" > $out
  '';

  commitMsgCommon = {
    intro = "You are generating a git commit message based on staged changes.";

    writingStyle = ''
      WRITING STYLE:
      - Clear, analytical, and technical without unnecessary verbosity
      - Break down changes into logical components
      - Explain the "why" behind architectural decisions
      - Balance technical precision with practical understanding
      - Acknowledge trade-offs and implications honestly
      - Use active, imperative voice for subject lines
      - Occasionally include technical puns or wordplay when it flows naturally (don't force it)
    '';

    technicalDepth = ''
      TECHNICAL DEPTH GUIDELINES:
      - Explain architectural patterns, not implementation minutiae
      - Highlight performance characteristics when measurable
      - Note breaking changes or compatibility impacts
      - Call out potential pitfalls or edge cases addressed
      - Reference specific technologies/frameworks when relevant
    '';

    toneExamples = ''
      TONE EXAMPLES:

      Good:
      - "Fix race condition in cache invalidation by introducing write-through semantics"
      - "Add retry logic with exponential backoff to handle transient network failures"
      - "Refactor authentication middleware to separate concerns between authN and authZ"

      Avoid:
      - "Fixed some bugs in the cache"
      - "Made improvements to the auth system"
      - "Updated code to be better"
    '';

    antiPatterns = ''
      ANTI-PATTERNS TO AVOID:
      - Corporate speak ("leverage", "utilize", "going forward")
      - Hedging language ("sort of", "kind of", "basically")
      - Passive voice ("was updated", "has been refactored")
      - Vague quantifiers ("much faster", "more reliable")
      - Over-explaining obvious changes
    '';

    specifics = ''
      WHEN TO INCLUDE SPECIFICS:
      - Performance numbers if measured: "reduces latency by 40%"
      - Bug identifiers: "fixes issue where X caused Y"
      - Breaking changes: "BREAKING: removes deprecated Z API"
      - Migration requirements: "requires database migration"
      - Architecture shifts: "moves from polling to event-driven"
    '';

    closing = ''
      Remember: Write for the engineer reviewing code history six months from now, trying to understand why this change was necessary. They're technical, time-constrained, and appreciate clarity over cleverness.

      Context:
      - Use context provided by the LLM
      - You may also read in changeds by executing `git diff HEAD`
    '';
  };
in

{
  home.packages = with pkgs; [
    beads_bin
    fabric
    (llm.withPlugins {
      llm-cmd = true;
      llm-jq = true;
    })
    ollama
    shell-gpt
  ];

  home.file.".claude/plugins/marketplaces/beads-marketplace".source = beads;
  home.file.".claude/plugins/marketplaces/claude-plugins-official".source = claude-plugins-official;
  home.file.".claude/plugins/marketplaces/claude-code-wakatime".source = claude-code-wakatime;

  home.file.".claude/plugins/known_marketplaces.json".text =
    let
      timestamp = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile buildTime);
    in
    builtins.toJSON {
      claude-plugins-official = {
        source = {
          source = "github";
          repo = "anthropics/claude-plugins-official";
        };
        installLocation = "${config.home.homeDirectory}/.claude/plugins/marketplaces/claude-plugins-official";
        lastUpdated = timestamp;
      };
      beads = {
        source = {
          source = "github";
          repo = "steveyegge/beads";
        };
        installLocation = "${config.home.homeDirectory}/.claude/plugins/marketplaces/beads-marketplace";
        lastUpdated = timestamp;
      };
      claude-code-wakatime = {
        source = {
          source = "github";
          repo = "wakatime/claude-code-wakatime";
        };
        installLocation = "${config.home.homeDirectory}/.claude/plugins/marketplaces/claude-code-wakatime";
        lastUpdated = timestamp;
      };
    };

  programs.claude-code = {
    enable = true;
    settings = {
      alwaysThinkingEnabled = true;
      includeCoAuthoredBy = false;
      attribution = {
        commit = "";
        pr = "";
      };
      permissions = {
        defaultMode = "acceptEdits";
        allow = [
          "Bash(bd --help:*)"
          "Bash(bd blocked)"
          "Bash(bd close:*)"
          "Bash(bd comments:*)"
          "Bash(bd create:*)"
          "Bash(bd dep add:*)"
          "Bash(bd dep tree:*)"
          "Bash(bd help:*)"
          "Bash(bd init:*)"
          "Bash(bd label add:*)"
          "Bash(bd list:*)"
          "Bash(bd ready:*)"
          "Bash(bd show:*)"
          "Bash(bd sync:*)"
          "Bash(bd update:*)"
          "Bash(biome check:*)"
          "Bash(biome format:*)"
          "Bash(biome lint:*)"
          "Bash(cargo build:*)"
          "Bash(cargo check:*)"
          "Bash(cargo clippy:*)"
          "Bash(cargo doc:*)"
          "Bash(cargo run:*)"
          "Bash(cargo test:*)"
          "Bash(cargo tree:*)"
          "Bash(mix compile:*)"
          "Bash(mix credo:*)"
          "Bash(mix deps.clean:*)"
          "Bash(mix deps.compile:*)"
          "Bash(mix deps.get:*)"
          "Bash(mix dump_schema:*)"
          "Bash(mix ecto.migrate:*)"
          "Bash(mix format:*)"
          "Bash(mix lint:*)"
          "Bash(mix phx.server:*)"
          "Bash(mix seed:*)"
          "Bash(mix test:*)"
          "Skill(beads:create)"
          "Skill(beads:init)"
          "Skill(beads:list)"
          "Skill(beads:show)"
          "WebFetch(domain:docs.rs)"
          "WebFetch(domain:github.com)"
          "WebFetch(domain:hexdocs.pm)"
          "WebFetch(domain:raw.githubusercontent.com)"
          "WebSearch"
        ];
      };
      theme = "dark";
      enabledPlugins = {
        "beads@beads" = true;
        "context7@claude-plugins-official" = true;
        "rust-analyzer-lsp@claude-plugins-official" = true;
        "claude-code-wakatime@claude-code-wakatime" = true;
      };
      disabledMcpjsonServers = [ "context7:context7" ];
      hooks = {
        SessionStart = [
          {
            matchers = "";
            hooks = [
              {
                type = "command";
                command = "${beads_bin}/bin/bd prime";
              }
            ];
          }
        ];
        PreCompact = [
          {
            matchers = "";
            hooks = [
              {
                type = "command";
                command = "${beads_bin}/bin/bd prime";
              }
            ];
          }
        ];
      };
    };

    memory.text = ''
      # Software Design Philosophy

      These principles guide how to write and structure code. Apply them thoughtfully—they are heuristics, not laws.

      ## Core Premises

      **Premise 1: Software design is fundamentally about managing complexity.**

      Total complexity = Σ(essential complexity × interaction points)

      Essential complexity is unavoidable—it's what makes an HTTP client an HTTP client. Your job is to minimize interaction points through encapsulation, not to eliminate the essential work.

      **Premise 2: All code has cost.**

      Every line, every abstraction, every module adds cognitive load. The value of any code must significantly exceed its cost. If you can't articulate what value a piece of code provides beyond "organization," question whether it should exist.

      ```
      value >> cost   → keep it
      value ≈ cost    → simplify or remove
      value < cost    → remove it
      ```

      ## Deep Modules

      **Modules should hide complexity, not just organize code.**

      A deep module has a simple interface but significant implementation behind it. A shallow module has an interface nearly as complex as its implementation—it provides little leverage against complexity.

      ```
      Good: 
        read(file, buffer, count)  // hides buffering, caching, disk blocks, error recovery

      Bad:
        file_stream = open_file(path)
        buffered = add_buffering(file_stream)
        object_stream = add_serialization(buffered)
        // caller assembles the abstraction themselves
      ```

      **Test for depth:** If understanding the implementation is necessary to use the interface correctly, the module is too shallow.

      **Test for false layers:** If changing one layer requires changing another, they aren't truly separate—merge them or redesign the boundary.

      ## Information Hiding

      **Each module should encapsulate design decisions.**

      Hidden information typically includes:
      - Data structure choices
      - Algorithms and their parameters  
      - File/wire formats
      - Policies (retry logic, caching strategies)
      - Platform-specific details

      **Information leakage is a critical red flag.** If the same knowledge appears in multiple modules, you have a dependency that will cause pain during changes.

      ```
      Leaky: 
        // Module A knows file format
        write_header(file, VERSION_2, CHECKSUM_CRC32)
        
        // Module B also knows file format  
        if header.version == VERSION_2 and header.checksum_type == CHECKSUM_CRC32:
          ...

      Better:
        // Single module owns format knowledge
        file_handler.write(data)  // format is internal
        file_handler.read()       // format is internal
      ```

      ## Complete Functions

      **Each function should do one thing completely.**

      Don't fragment a single responsibility across multiple functions that must be called in sequence or that share implicit state. A longer function that handles its full responsibility is better than several short functions that leak implementation details to each other.

      ```
      Fragmented (bad):
        fuse = get_fuse(service)
        check_fuse_state(fuse)
        result = call_if_fuse_ok(fuse, request)
        update_cache_from_result(result)
        maybe_blow_fuse(fuse, result)

      Complete (better):
        result = fetch_with_circuit_breaker(service, request)
        // All fuse logic, caching, and retry is internal
      ```

      **Long functions are acceptable when:**
      - They have a simple interface
      - Their blocks are relatively independent (can be read sequentially)
      - Breaking them up would create conjoined functions that can't be understood independently

      ## Different Layer, Different Abstraction

      **If two layers have the same abstraction, one is probably unnecessary.**

      Pass-through methods are a red flag—they add interface complexity without adding functionality:

      ```
      Bad (pass-through):
        class Document:
          def get_cursor_offset(self):
            return self.text_area.get_cursor_offset()  // adds nothing
            
      Better:
        // Expose text_area directly, or give Document a genuinely different abstraction
      ```

      **Decorators and wrappers should be used sparingly.** Before creating one, ask:
      - Can this functionality go directly in the base class?
      - Can it merge with an existing decorator?
      - Does it actually need to wrap, or can it be independent?

      ## Define Errors Out of Existence

      **Reduce the number of places where exceptions must be handled.**

      The best error handling is making errors impossible or irrelevant:

      ```
      Error-prone:
        unset(variable)  // throws if variable doesn't exist

      Error-free:
        ensure_absent(variable)  // succeeds whether or not variable exists
      ```

      ```
      Error-prone:
        substring(start, end)  // throws if indices out of bounds

      Error-free:
        substring(start, end)  // returns empty string if no overlap, clips to bounds
      ```

      **Techniques:**
      - Redefine operations so edge cases are normal cases
      - Mask exceptions at low levels when higher levels can't do anything useful
      - Aggregate exception handling—catch many exceptions in one place rather than wrapping every call
      - Let the system crash for truly unrecoverable errors (out of memory, corrupted state)

      ## General-Purpose Interfaces

      **Somewhat general-purpose modules are deeper than specialized ones.**

      Design interfaces around fundamental operations, not specific use cases:

      ```
      Too specialized:
        backspace()           // deletes char before cursor
        delete_key()          // deletes char after cursor  
        delete_selection()    // deletes highlighted text

      General-purpose:
        delete(start, end)    // deletes range; all above are trivial callers
      ```

      **Questions to ask:**
      - What's the simplest interface covering all current needs?
      - How many situations will this method be used in? (If one, it's too specialized)
      - Can I reduce the number of methods without adding complex parameters?

      **Push specialization to the edges.** Core infrastructure should be general; application-specific behavior belongs in the outer layers that call into it.

      ## Pull Complexity Downward

      **It's better for a module's implementer to suffer than its users.**

      When you encounter unavoidable complexity, absorb it in the implementation rather than exposing it in the interface. Users of your module are more numerous than you.

      ```
      Pushing complexity up (bad):
        // Caller must understand retry policy, timeout configuration, error types
        config = RetryConfig(attempts=3, backoff=exponential(base=2))
        result = fetch(url, timeout=30, retry_config=config, on_error=log_and_continue)

      Pulling complexity down (better):
        result = fetch(url)  // sensible defaults internal; rare overrides via separate methods
      ```

      **Configuration parameters are often a failure to make decisions.** Before exposing a parameter, ask: "Will users actually know better than I can compute automatically?"

      ## Writing Comments

      **Comments describe what isn't obvious from the code.**

      There are two valid directions:
      1. **Lower-level (precision):** Units, boundary conditions, null meanings, invariants
      2. **Higher-level (intuition):** Why this approach, what the code is trying to accomplish, how pieces fit together

      ```
      Useless (repeats code):
        count = count + 1  // increment count

      Useful (adds precision):
        // Timeout in milliseconds; 0 means no timeout
        timeout = 5000

      Useful (adds intuition):
        // Try to append to an existing RPC to the same server that hasn't been sent yet
        for rpc in pending_rpcs:
          ...
      ```

      **Interface comments** describe what a function/class does, its parameters, return values, side effects, and preconditions—everything needed to use it without reading the implementation.

      **Implementation comments** describe *what* blocks of code accomplish (not *how*), and *why* tricky decisions were made.

      **Write comments before code.** If you can't describe what a function does simply, the design isn't clean yet.

      ## Naming

      **Names create mental images.** Choose words that convey the most information about the entity's purpose:

      ```
      Vague: data, result, value, info, temp, x
      Better: connection_pool, retry_count, user_permissions, cursor_position
      ```

      **Be consistent.** Use the same name for the same concept everywhere. Never use the same name for different concepts.

      **Be precise.** If `block` could mean "disk block" or "file block," use `disk_block` and `file_block`.

      ## Consistency

      **Similar things should look similar. Different things should look different.**

      Consistency creates cognitive leverage—once you learn a pattern, you can apply that knowledge everywhere it appears.

      This applies to:
      - Naming conventions
      - Parameter ordering
      - Error handling patterns
      - Code organization within modules

      **Don't change existing conventions** unless you have significant new information *and* you're willing to update all existing uses. A "better" approach isn't worth the inconsistency.

      ## Red Flags

      Watch for these symptoms:

      | Red Flag | What It Suggests |
      |----------|------------------|
      | Shallow module | Interface nearly as complex as implementation |
      | Information leakage | Same knowledge in multiple places |
      | Pass-through method | Layer adds no abstraction |
      | Conjoined functions | Can't understand one without the other |
      | Hard to name | Unclear purpose or mixed responsibilities |
      | Hard to describe | Interface isn't clean |
      | Repetition | Missing abstraction |
      | Many special cases | Normal case isn't general enough |

      ## Strategic vs Tactical

      **Tactical:** "What's the smallest change to make this work?"  
      **Strategic:** "What design would I have built if I'd known about this requirement from the start?"

      Tactical programming accumulates complexity. Strategic programming invests ~10-20% extra time in design to pay dividends forever.

      When modifying existing code:
      1. Don't just patch—consider whether the current design is still appropriate
      2. If not, refactor toward the design you'd build from scratch
      3. Leave the code cleaner than you found it

      ## Summary Heuristics

      1. **Ask "value > cost?" for every abstraction.** If you can't articulate the value, remove the abstraction.
      2. **Encapsulate complexity; don't just organize it.** A module that requires reading its implementation has failed.
      3. **Complete functions over fragmented ones.** It's fine if they're longer.
      4. **General interfaces, specialized callers.** Push application-specific behavior outward.
      5. **Define errors out of existence** when possible; handle the rest in few places.
      6. **Comments explain what code cannot.** Write them first.
      7. **Consistency beats local optimality.** Follow existing patterns.
      8. **Invest in design continuously.** Every change is an opportunity to improve structure.
    '';

    agents = {
      bd-planner = ''
        ---
        name: bd-planner
        description: Plan a beads (bd) task
        model: opus
        color: blue
        ---

        You are a software architect and planning specialist for Claude Code. Your role is to explore the codebase and design implementation plans.

        You will use `beads` tools to insert plans into existing tickets, and create additional child tickets if necessary.

        ## Your Process

        1. Understand Requirements: Focus on the requirements provided and apply your assigned perspective throughout the design process.

        2. Explore Thoroughly:

        - Read any files provided to you in the initial prompt
        - Find existing patterns and conventions using GLOB, GREP, and READ 
        - Understand the current architecture
        - Identify similar features as reference
        - Trace through relevant code paths
        - Use BASH ONLY for read-only operations (ls, git status, git log, git diff, find, cat, head, tail)
        - NEVER use BASH for: mkdir, touch, rm, cp, mv, git add, git commit, npm install, pip install, or any file creation/modification

        3. Design Solution:

        - Create implementation approach based on your assigned perspective
        - Consider trade-offs and architectural decisions
        - Use the AskUserQuestion tool to answer any questions or make any necessary decisions
        - Follow existing patterns where appropriate

        4. Detail the Plan:

        - Provide step-by-step implementation strategy
        - Create sub-task tickets in beads if that makes sense
        - Identify dependencies and sequencing
        - Anticipate potential challenges
        - Indicate what should be tested (but don't write out the tests themselves)

        ## Output

        - Add the plans to the description of the tickets.
        - Mark the ticket as planned
        - Do not execute the plan, only create the plan and update the tickets.
      '';
    };

    commands = {
      bd-plan = ''
        ---
        description: Plan all unplanned beads (bd) tickets 
        ---

        For every bd task that doesn't have the `planned` label (`bd list --json | jq -r '. | map(select(.status == "open" and (.labels.[] | contains("planned") | not ) )) | .[].id'`): 
        - Launch a foreground bd-planner subagent to add a plan to the ticket
      '';

      bd-execute = ''
        ---
        description: Execute one ready beads (bd) tickets 
        ---

        1. Find an outstanding tasks that hasn't been assigned (`bd ready -l planned -u`):
        2. Choose a task
        3. View the issue and implement the plan
        4. Once the implementation is complete:
           - Mark it complete in beads
           - Unassign yourself
           - Commit the changes
      '';

      bd-execute-all = ''
        ---
        description: Execute all ready beads (bd) tickets 
        ---

        Complete all ready beads (bd) tickets:

        1. Find all outstanding tasks that have been planned (`bd ready -l planned -u`):
        2. Complete these tasks one at a time (serially)
        3. For each task: 
          - Launch a sub-agent to do the work (to limit context)
          - In the agent, view the issue and implement the plan.
          - Once the implementation is complete:
            - Mark it complete in beads 
            - Commit the changes
        4. Finally, move on to the next task.
      '';

      fix-pr-comments = ''
        ---
        description: Fetch and address unresolved PR review comments for the current branch
        ---

        Fetch unresolved review comments for the current branch's PR and help address them.

        First, get the PR number and repository info by running these commands:

        ```bash
        gh pr view --json number -q .number
        ```

        ```bash
        gh repo view --json owner,name -q '.owner.login + "/" + .name'
        ```

        If there's no PR for the current branch, let me know.

        Then fetch unresolved comments using those values (replace OWNER, REPO, PR_NUMBER):

        ```bash
        gh api -X POST graphql -f query='query { repository(owner: "OWNER", name: "REPO") { pullRequest(number: PR_NUMBER) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 100) { nodes { author { login } body url diffHunk line startLine path } } } } } } }' | jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
        ```

        Then:
        1. Summarize each unresolved comment
        2. For each comment, identify the file and code that needs to be changed
        3. Propose fixes for each issue
        4. Use the AskUserQuestion tool to ask if I want to apply the fixes

        If there are no unresolved comments, let me know the PR looks good.
      '';

      commit-msg-short = ''
        ---
        description: Write a short commit message based on context and changes to the project
        ---

        ${commitMsgCommon.intro}

        ${commitMsgCommon.writingStyle}
        STRUCTURE:
        - 2-3 sentences total
        - Subject: Imperative statement of what changed
        - Context: Why it matters or what problem it solves
        - Focus on the key insight, not exhaustive details

        Example:
        "Implement connection pooling for database layer. Reduces query overhead by reusing established connections rather than creating new ones per request, dropping P95 latency from 45ms to 12ms."

        ${commitMsgCommon.technicalDepth}
        ${commitMsgCommon.toneExamples}
        ${commitMsgCommon.antiPatterns}
        ${commitMsgCommon.specifics}
        ${commitMsgCommon.closing}
      '';

      commit-msg-detailed = ''
        ---
        description: Write a detailed commit message based on context and changes to the project
        ---

        ${commitMsgCommon.intro}

        ${commitMsgCommon.writingStyle}
        STRUCTURE:
        - Subject line: Clear summary in imperative mood (50-72 chars)
        - Blank line
        - Body paragraphs (wrapped at 72 chars):
          * What changed and why
          * Technical rationale and architecture considerations
          * Trade-offs, performance implications, or migration notes
          * Related issues/tickets if applicable

        Example structure:
        ```
        Refactor GraphQL federation schema composition

        Previous approach composed schemas at runtime, introducing 200ms+
        overhead on cold starts. New approach pre-composes schemas during
        build phase and caches the result.

        Key changes:
        - Move schema composition to build-time codegen
        - Add schema validation in CI pipeline
        - Implement cached schema loading with TTL

        Trade-offs:
        - Requires rebuild to update federated schema
        - Increases build time by ~30 seconds
        - Reduces runtime composition overhead to zero

        Closes #234
        ```

        ${commitMsgCommon.technicalDepth}
        ${commitMsgCommon.toneExamples}
        ${commitMsgCommon.antiPatterns}
        ${commitMsgCommon.specifics}
        ${commitMsgCommon.closing}
      '';
    };

    skillsDir = claude-skills;
  };
}
