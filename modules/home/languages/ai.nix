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
      };
      theme = "dark";
      enabledPlugins = {
        "beads@beads" = true;
        "context7@claude-plugins-official" = true;
        "ralph-loop@claude-plugins-official" = true;
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

        1. Design Solution:

        - Create implementation approach based on your assigned perspective
        - Consider trade-offs and architectural decisions
        - Use the AskUserQuestion tool to answer any questions or make any necessary decisions
        - Follow existing patterns where appropriate

        1. Detail the Plan:

        - Provide step-by-step implementation strategy
        - Create sub-task tickets in beads if that makes sense
        - Identify dependencies and sequencing
        - Anticipate potential challenges

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

        For every bd task that doesn't have the `planned` label: 
        - Launch a foreground bd-planner subagent to add a plan to the ticket
      '';

      bd-execute = ''
        ---
        description: Execute all ready beads (bd) tickets 
        ---

        Complete all ready beads (bd) tickets:

        1. Find all outstanding tasks that have been planned: `bd ready -l planned`
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
