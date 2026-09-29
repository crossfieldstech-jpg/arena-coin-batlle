# Copilot Workspace Instructions

## Mandatory Workflow: Dual-Model Review & Execute Loop

For every coding, refactoring, feature implementation, and bug-fixing request in Copilot:

1. **Always Follow the Review & Execute Protocol**:
   - You must NOT directly jump to applying code edits without a verified review plan.
   - For all non-trivial tasks, either invoke or follow the `Review & Execute` agent workflow ([agents/review-and-execute.agent.md](agents/review-and-execute.agent.md)).
   - **Planning and Architecture Review**: Planning and review must be performed by the best Google model/agent (`Plan Reviewer` / Gemini 2.5 Pro / Gemini Pro) with `reasoning-effort: high` to critically audit and approve the architecture, identify edge cases, and establish concrete steps.
   - **Plan Implementation**: Implementation must be executed by the cheapest Google model/agent (`Task Executor` / Gemini 2.5 Flash / Gemini Flash), strictly implementing the step-by-step plan approved by the main reviewer with surgical precision.

2. **Agent Delegation Rules**:
   - When a user asks a task in default chat, coordinate the task through the mandatory dual-model `Review & Execute` loop or invoke the `Plan Reviewer` and `Task Executor` subagents respectively.
   - Do not bypass plan verification or execute code changes with unreviewed architecture.
   - Keep the dual-model review-and-execute protocol mandatory across all workflows.

## Mandatory Roblox Studio MCP Two-Way Sync Protocol

Roblox Studio MCP does not run an automatic background filesystem watcher. Therefore, the assistant must always maintain bidirectional parity between VS Code and Roblox Studio:

1. **Automatic Inbound Pull (Roblox Studio -> VS Code)**:
   - At the beginning of tasks, or whenever inspecting script state, check if scripts inside Roblox Studio contain changes made in Studio that are not yet on disk.
   - If a script in Roblox Studio has newer content or differs from the local file in `src/`, immediately read its `.Source` via MCP and update the corresponding local workspace file in VS Code.

2. **Automatic Outbound Push (VS Code -> Roblox Studio)**:
   - Whenever files in `src/` are modified, refactored, or newly created in VS Code, the assistant must immediately push the updated content directly to the target script in Roblox Studio via `mcp_robloxstudio_execute_luau` (assigning `target.Source = [===[...]===]`).
   - Also update any associated live `Configuration` folder attributes in `ReplicatedStorage` (e.g. `CoinSettings`, `GemSettings`) when default values change.

3. **Guaranteed Parity**:
   - Never leave local files and Roblox Studio DataModel out of sync. Both environments must reflect the exact same code at the conclusion of every turn.

## Mandatory Git Branch & Pull Request Protocol

Never push directly to `main`. Always allow the user to review and verify changes before merging:

1. **Feature Branching**:
   - For every new feature, bugfix, or refactoring task, create and checkout a descriptive feature branch (e.g. `feat/...` or `fix/...`).
   - Never commit or push directly to `main`.

2. **Branch Push & Pull Request Creation**:
   - Commit changes to the feature branch with descriptive, structured commit messages.
   - Push the feature branch to `origin`.
   - Create a Pull Request (targeting `main`) so the user can inspect diffs and verify code before merging.
