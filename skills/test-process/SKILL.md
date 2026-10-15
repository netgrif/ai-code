---
name: test-process
description: Validates Petriflow process XML with the Petriflow MCP and runs it as a live case scenario on the local NAE. Use when a process in processes/*.xml was created or modified and must be checked, or when the user asks to "validate", "test", "deploy" or "try out" a process or to run its tasks on the local engine. Not for designing or writing a process (use generate-process) or its actions (use generate-action).
compatibility: Requires the Petriflow MCP server (https://localhost:3000/mcp). Stage 2 also needs a running local NAE with the local-nae MCP (http://localhost:8080/mcp).
metadata:
  tested: false
  mcp-server: petriflow, local-nae
  version: 0.3.0
---

# Test Petriflow Process

## Overview

Test in two stages: static validation first (always), then a live run on the
local NAE, only after validation passes. Never replace validation with reading
the XML by eye.

**Approval rule:** any tool call that changes the local NAE (deploy, create
case, execute task) needs user approval before it runs. Read-only calls
(`list_versions`, `validate_process`, `list_tasks_of_case`) don't. For file
edits see Stage 1, step 5.

## Stage 1: Validate (petriflow MCP)

0. If the Petriflow MCP does not answer, say so and stop. Never replace
   validation with reading the XML by eye.
1. Get the available Petriflow versions: read resource `petriflow://versions`;
   if resources aren't provided, call `list_versions`. Versions follow semver.
   Use the latest, unless the user or project pins another.
2. Call `validate_process` with that version and the raw XML (check the tool
   schema for exact parameter names).
3. For every returned issue: quote it, locate the element in the XML, and
   propose a concrete fix as a diff. Group related issues.
4. If validation against the latest version fails on constructs that belong to
   an older Petriflow release, report it and ask whether to migrate the process
   to the latest version or pin the older one. Do not choose silently.
5. Apply the fixes, then re-validate the updated XML. Repeat until there are no
   errors. Report remaining warnings.
    - A file the agent is writing in the current task (e.g. from
      `generate-process` or `generate-action`): apply fixes directly and list
      them in the report.
    - An existing or user-written file: apply fixes only after the user
      approved the proposed diff.

## Stage 2: Live test (local-nae MCP, http://localhost:8080/mcp)

Precondition: Stage 1 has no errors. If the NAE MCP tools are unavailable, say
so and stop. Do not fake results. Suggest running `docker compose up` in `nae/`.

1. Read the process (places, transitions, data, actions). Write a scenario:
   ordered tasks, data values to set, expected enabled tasks and data after
   each step. If the process isn't understood well enough to predict outcomes,
   stop and ask instead of guessing inputs.
2. Present to the user, in one message: the process to deploy, the case to
   create (title), and the full scenario. Ask for approval **once**. Approval
   covers `deploy_process`, `create_case` and every `execute_task` in that
   scenario. Anything outside it (extra tasks, different data, a second case)
   needs new approval.
3. After approval: `deploy_process` → `create_case` → loop
   `list_tasks_of_case` → `execute_task` → `list_tasks_of_case`.
   After each step compare the actual enabled tasks and data to the expected ones.
4. Several cooperating processes: deploy the processes that others reference
   (via caseRef, taskRef or case creation) before the processes that reference
   them, and include the cross-case effects (cases created, channels fired) in
   the expected results. This also applies across applications: take the order
   from the "Deploy order" and "Dependencies on other applications" sections of
   `processes/<app_name>/README.md`, and include referenced processes of other
   applications in the scenario you present for approval.

## Quick reference

| Need                            | Tool                                            | Approval                         |
|---------------------------------|-------------------------------------------------|----------------------------------|
| List language versions          | `petriflow://versions` / `list_versions`        | no                               |
| Check XML                       | `validate_process`                              | no                               |
| Apply fix to file               | edit                                            | only for existing/user files     |
| Deploy / create case / run task | `deploy_process`, `create_case`, `execute_task` | yes, once per presented scenario |
| Inspect case tasks              | `list_tasks_of_case`                            | no                               |

## Report

End with: Petriflow version used; validation issues → fixes → final state;
deployed process id; case id; per-step table (task, input, expected, actual,
pass/fail); suggested process changes for any mismatch.

## Common mistakes

- Hardcoding a Petriflow version instead of looking up the latest.
- Choosing between migrating and pinning an older version without asking.
- Deploying before validation is clean.
- Calling a state-changing tool before the scenario was approved.
- Executing tasks with invented data instead of the declared data fields.
- Reporting "works" without comparing against the expected scenario.
- Re-validating the old XML after edits.
