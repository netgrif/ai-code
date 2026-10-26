---
name: test-process
description: Validates Petriflow process XML with the Petriflow MCP and runs it as a live case scenario on the local NAE. Use when a process in processes/*.xml was created or modified and must be checked, or when the user asks to "validate", "test", "deploy" or "try out" a process or to run its tasks on the local engine, or to check the roles and permissions of a process. Not for designing or writing a process (use generate-process) or its actions (use generate-action).
compatibility: Requires the petriflow-mcp MCP server (http://localhost:3000/mcp). Stage 2 also needs a running local NAE with the engine-mcp MCP (http://localhost:8080/mcp).
metadata:
  tested: false
  mcp-server: petriflow-mcp, engine-mcp
  version: 0.3.0
---

# Test Petriflow Process

## Overview

Test in two stages: static validation first (always), then a live run on the
local NAE, only after validation passes. Never replace validation with reading
the XML by eye.

**Approval rule:** any tool call that changes the local NAE (deploy, create
case, execute task, create or delete users, assign roles, delete cases) needs
user approval before it runs. Read-only calls
(`list_versions`, `validate_process`, `list_processes`, `list_tasks_of_case`)
don't. For file edits see Stage 1, step 6. `deploy_process` with
`replaceExisting` also deletes the cases and tasks of the replaced process (see
Redeploying while iterating).

## Stage 1: Validate (petriflow-mcp MCP)

1. If the Petriflow MCP does not answer, say so and stop. Never replace
   validation with reading the XML by eye.
2. Get the available Petriflow versions: read resource `petriflow://versions`;
   if resources aren't provided, call `list_versions`. Versions follow semver.
   Use the latest, unless the user or project pins another.
3. Call `validate_process` with that version and the raw XML (check the tool
   schema for exact parameter names).
4. For every returned issue: quote it, locate the element in the XML, and
   propose a concrete fix as a diff. Group related issues.
5. If validation against the latest version fails on constructs that belong to
   an older Petriflow release, report it and ask whether to migrate the process
   to the latest version or pin the older one. Do not choose silently.
6. Apply the fixes, then re-validate the updated XML. Repeat until there are no
   errors. Report remaining warnings.
    - A file the agent is writing in the current task (e.g. from
      `generate-process` or `generate-action`): apply fixes directly and list
      them in the report.
    - An existing or user-written file: apply fixes only after the user
      approved the proposed diff.

## Stage 2: Live test (engine-mcp MCP, http://localhost:8080/mcp)

Precondition: Stage 1 has no errors. If the NAE MCP tools are unavailable, say
so and stop. Do not fake results. Suggest running `docker compose up -d` in the repository root.

1. Read the process (places, transitions, data, actions). Write a scenario:
   ordered tasks, data values to set, expected enabled tasks and data after
   each step. If the process isn't understood well enough to predict outcomes,
   stop and ask instead of guessing inputs. If the process has role permissions
   or user-bound fields, read `references/role-scenarios.md` first and add role
   scenarios: every step then runs as an impersonated test user, because a
   token-less call is the system user and proves nothing about permissions.
2. Call `list_processes` to see which process ids and versions are deployed.
   Present to the user, in one message: the processes to deploy, for each
   whether it is a new deploy or a replacement (the replaced id and version, and
   that its cases and tasks will be deleted), the case to create (title), the
   test users with their roles (role scenarios), the cleanup, and the full
   scenario. Ask for approval **once**. Approval covers `deploy_process`
   (including `replaceExisting` for these processes), `create_case`, every
   `execute_task` in that scenario, creating and deleting its test users,
   `assign_role`, and the cleanup deletes, and their repeats while you iterate
   on the same implementation: later replacements of the same processes need no
   new approval. Anything outside it (extra processes, extra tasks, different
   data, a second case, a changed scenario) needs new approval.
3. After approval: `deploy_process` (see Redeploying while iterating) →
   `create_case` → loop `list_tasks_of_case` → `execute_task` →
   `list_tasks_of_case`.
   After each step compare the actual enabled tasks and data to the expected
   ones. When a step fails, keep the exact outputs as evidence and clean up
   (step 5). Then fix the process, validate it again (Stage 1), redeploy it per
   the table below and run the scenario again from step 3 as a new run.
4. Several cooperating processes: deploy the processes that others reference
   (via caseRef, taskRef or case creation) before the processes that reference
   them, and include the cross-case effects (cases created, channels fired) in
   the expected results. This also applies across applications: take the order
   from the "Deploy order" and "Dependencies on other applications" sections of
   `processes/<app_name>/README.md`, and include referenced processes of other
   applications in the scenario you present for approval. Replace in the same
   order. Replacing a referenced process deletes its cases, so cases of other
   processes may hold dead caseRefs: redeploy the processes that reference it
   (with `replaceExisting` if the same version is deployed) and recreate their
   cases in the scenario.
5. **Clean up after every scenario**, also a failed one, so the user finds a
   clean UI. Delete the test cases you created (`delete_case`), including cases
   created by actions, then the test users you created (`delete_user`). Delete
   nothing you did not create. Deployed processes and the menu stay. The deployed
   process must be the final file: if the XML changed after the last deploy,
   replace it, run the scenario again and clean up again. Report what was
   deleted and anything you could not delete.

## Redeploying while iterating

`<version>` in the process XML is the process version, not the Petriflow
version. `deploy_process` has an optional boolean `replaceExisting` (default
`false`). The engine fails when the same process id and version is already
deployed and the flag is not `true`. With `true` the engine deletes the
deployed version **including all its cases and tasks** and imports the provided
XML.

| Situation                                                                       | `<version>` in the XML                                                                                                                               | `deploy_process`                                      |
|---------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| Process id not deployed (per `list_processes`)                                  | `1.0.0` for a new process, otherwise unchanged                                                                                                       | plain                                                 |
| Id and version deployed by you earlier in this task, same implementation        | unchanged                                                                                                                                            | `replaceExisting: true`                               |
| The user gave a new instruction to edit an implemented process                  | bumped once for that instruction: minor for added or changed behavior, major for removed fields or transitions; ask when unclear                    | plain (a new version, nothing is replaced)            |
| Id and version deployed, but not by you in this task                            | unchanged                                                                                                                                            | ask the user before using `replaceExisting`           |

- Never bump the version to get around a failed or refused deploy.
- Check `list_processes` before every deploy. After a failed deploy do not retry
  blindly with `replaceExisting: true`; follow the table.
- "Deployed by you in this task" means your own `deploy_process` call in this
  session.

## Quick reference

| Need                            | Tool                                            | Approval                         |
|---------------------------------|-------------------------------------------------|----------------------------------|
| List language versions          | `petriflow://versions` / `list_versions`        | no                               |
| Check XML                       | `validate_process`                              | no                               |
| List deployed processes         | `list_processes`                                | no                               |
| Apply fix to file               | edit                                            | only for existing/user files     |
| Deploy / create case / run task | `deploy_process`, `create_case`, `execute_task` | yes, once per presented scenario |
| Redeploy the same version       | `deploy_process` with `replaceExisting: true`   | covered by that approval; deletes the process's cases and tasks |
| Inspect case tasks              | `list_tasks_of_case`                            | no                               |
| Test users and roles            | `create_user`, `assign_role`, `get_user`, `get_process`, `whoami` | yes, once per presented scenario; see `references/role-scenarios.md` |
| Clean up after the scenario     | `delete_case`, `delete_user`                    | covered by that approval; only what the scenario created |

## Report

End with: Petriflow version used; validation issues → fixes → final state;
deployed process ids and versions (new or replaced, and the cases a
replacement deleted); case id; per-step table (task, input, expected, actual,
pass/fail); for role scenarios the matrix (user × action → expected, observed,
verdict); the cleanup result; suggested process changes for any mismatch.

## Common mistakes

- Hardcoding a Petriflow version instead of looking up the latest.
- Choosing between migrating and pinning an older version without asking.
- Deploying before validation is clean.
- Calling a state-changing tool before the scenario was approved.
- Executing tasks with invented data instead of the declared data fields.
- Reporting "works" without comparing against the expected scenario.
- Re-validating the old XML after edits.
- Bumping the process version between iterations, or to get around a refused
  deploy.
- Using `replaceExisting` on a first deploy or together with a bumped version.
- Replacing a process without saying in the scenario that its cases and tasks
  are deleted.
- Replacing a process that was not deployed by you in this task without asking.
- Replacing a referenced process but not redeploying the processes that
  reference it.
- Retrying a failed deploy with `replaceExisting: true` without checking
  `list_processes`.
- Mixing up the Petriflow version and the process `<version>`.
- Running a role-protected process only token-less (as system) and calling the
  permissions fine.
- Drawing a permission conclusion from a call without an impersonation token.
- Reusing role ids from before a redeploy.
- Retrying and adjusting a role scenario until it matches the expectation.
- Leaving test cases or test users behind, or deleting ones you did not create.
- Writing impersonation tokens into files, the report or chat output.
