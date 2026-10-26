# Personal AI working agreements

Shared by Codex and Claude Code. Generic rules live in
`~/dotfiles/ai/AGENTS.md`; machine-specific rules live in
`~/.config/ai/AGENTS.local.md`. `dotfiles-ai-build` combines them into
`~/.config/ai/AGENTS.md`, which `~/.codex/AGENTS.md` and
`~/.claude/CLAUDE.md` link to. Edit the sources, not the generated file.

## Cost controls

Never enable Fast mode or select the `fast` or `priority` service tier. Always
use the standard/default service tier for the coordinator and every subagent.

## Code comments

Do not add comments to code. No comments are allowed: this covers `//`, `#`,
`/* */`, Python docstrings, and doc comments such as Rust `///` and `//!`, on
new files and new types as much as on existing code. Express intent through
naming and structure instead; code is expected to read top-down without prose.

The only comments that may be written are machine-read directives that happen
to use comment syntax: shebangs, lint and type pragmas (`#[allow(...)]`,
`# type: ignore`, `# noqa`, `# fmt: off`), coverage markers, and a license
header where the file's convention already requires one.

Never delete a comment a human wrote unless asked. Preserve existing comments
when editing the code around them.

State this constraint in every subagent brief that writes or edits code, not
only ones touching a file that already has no comments, and strip any comments
a subagent added before reporting its work as complete.

## Code review comments

Never post, edit, or delete comments, replies, reviews, or approvals in a code
hosting service unless the user explicitly requests that exact external action
in the current request. Never resolve or reopen review discussions without the
same explicit authorization.

Requests to read, review, address, handle, or act on review feedback authorize
investigation and local code changes only. They do not authorize responding to
reviewers or changing discussion state. Draft proposed responses for the user
to review when useful.

## Merge request descriptions

Keep merge request titles and descriptions short. Explain the concrete problem
and resulting behavior. Include dependency links or constraints when they help
the reviewer understand or merge the change.

Do not add test instructions, checklists, commands, test counts, or validation
reports to merge request descriptions unless I explicitly request them. Run
the required checks and report their results in the conversation instead.

## Git commits

- **Default**: single subject line only. No body, no description, no Co-Authored-By,
  no mention of AI/Devin/Claude/Codium/any tool. This applies to interactive
  sessions and unattended small-fix work (e.g. making CI green).
- **Exception — autonomous sub-agent work**: when parallel sub-agents did
  substantial work and you need to preserve context of what they did, a
  description body is allowed. Still **never** include Co-Authored-By or any AI
  attribution.
- When in doubt, keep it to one line.

## Coordinator and workers

Token spend and main-thread context are real constraints. The default session
shape is: the main agent talks, decides, coordinates, synthesises, and performs
the final review; subagents perform most bounded execution work.

This is a standing request to use subagents for substantial research,
discovery, diagnosis, implementation, and validation. Apply it in every fresh
session without waiting for the user to repeat the preference. Before bulk
exploration or execution, identify a bounded worker assignment, briefly state
the division of work, and delegate it. Sequential work also qualifies: reuse
a worker for discovery, implementation, and validation as decisions become
available. Use concurrent workers when their assignments can proceed
independently.

Delegate searches, documentation gathering, reading many files, inventories,
straightforward code tracing, mechanical edits, implementing a specified
change, test execution, log analysis, and other verifiable work. Direct work
by the main agent is appropriate for tiny tasks where coordination would cost
more, such as a one-line configuration change.

The main agent may still make changes, especially small integration fixes or
judgement-heavy edits, but the majority of routine implementation effort should
normally be assigned to subagents.

Keep judgement with the main agent when a plausible wrong answer would be hard
to detect or unsafe to act on. This includes deciding whether a bug is real,
adversarial verification, security conclusions, irreversible actions,
resolving conflicting evidence, and final acceptance of a change.

Use model tiers deliberately. Three roles, with the model for each assigned
per tool below:

- **Default worker** — narrow, clear, repeatable, or high-volume tasks;
  mechanical edits should have compiler, linter, test, or targeted parent
  verification.
- **Escalation worker** — a delegated task needing substantial multi-file
  tracing or a non-trivial reasoning chain. Keep routine discovery and
  execution with the default worker.
- **Coordinator** — coordination, synthesis, final review, and exceptional
  delegated work requiring independent high-stakes judgement.

### If you are Codex

- Default worker: GPT-6 Luna at `xhigh` reasoning.
- Escalation worker: GPT-6 Sol at `high` reasoning.
- Coordinator: GPT-6 Astra at `high` reasoning.

### If you are Claude Code

- Default worker: Sonnet.
- Escalation worker: none distinct — escalate that task to Opus.
- Coordinator: Opus.
- Do not use Haiku for implementation. Use it only where a wrong answer fails
  loudly or is cheap to spot-check: inventories, listing, format conversion,
  extracting fields from known-shape text.

Ensure spawned workers use the intended model and reasoning effort through
configured defaults or explicit spawn settings. Avoid copying the full main
conversation when a focused handoff supplies enough context.

Use this workflow, scaled to the task:

1. The main agent defines the question, scope, constraints, and acceptance
   criteria.
2. The default worker gathers evidence and returns concise findings with file/line or source
   references, relevant results, and uncertainties.
3. The main agent evaluates the evidence, resolves contradictions, decides
   whether a bug is real, and chooses the recommendation or implementation
   approach. Research and diagnosis requests end with findings unless changes
   are also authorized.
4. For authorized changes, the default worker implements the bounded change and runs the
   relevant validation. The main agent handles difficult integration choices.
5. The main agent reviews the relevant diff and validation evidence, checks
   risky assumptions, and gives the final answer. Spot-check worker results;
   repeat their investigation or tests only when a concrete concern warrants it.

Give each subagent a concrete, bounded deliverable and the context needed to
complete it, including scope, owned files if editing, constraints, and expected
validation. Request concise evidence summaries instead of raw intermediate
output. For concurrent write-heavy work, assign non-overlapping files or
components; otherwise use one writer and parallelise read-only investigation
and verification. The main agent owns integration, spot-checking, relevant
validation, and the final response.

Keep experiments small: start with one worker when sufficient and stay within
the configured concurrency cap, currently three workers. Add workers only for
useful independent assignments or unresolved questions. Do not repeat work
already established in the conversation or by another agent.

If worker launch is unavailable or cannot honor the required standard/default
service tier, report the concrete limitation early. Check safe, supported
alternatives within the task scope. A local `codex exec` worker is an acceptable
fallback when the required model, reasoning effort, and default service tier
can be selected explicitly; use a bounded prompt, preserve the task's permission
constraints, and count it toward the same worker cap. If no compliant worker
route is available, keep main-agent fallback work limited to small useful checks
and request direction before taking over a substantial worker workload. Never
switch to Fast mode or priority processing as a fallback.
