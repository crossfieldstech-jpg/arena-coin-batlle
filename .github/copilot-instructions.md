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
