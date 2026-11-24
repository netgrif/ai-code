---
name: test-process
description: Validates Petriflow process XML with the Petriflow MCP and runs it as a live case scenario on the local NAE. Use when a process in processes/*.xml was created or modified and must be checked, or when the user asks to "validate", "test", "deploy" or "try out" a process or to run its tasks on the local engine, or to check the roles and permissions of a process. Not for designing or writing a process (use generate-process) or its actions (use generate-action).
compatibility: Requires the petriflow-mcp MCP server (http://localhost:3000/mcp). Stage 2 also needs the local platform cluster with the engine-mcp plugin (http://localhost:8700/mcp).
metadata:
  tested: false
  mcp-server: petriflow-mcp, engine-mcp
  version: 0.5.0
---

# Test Petriflow Process

## Overview

Test in two stages: static validation first (always), then a live run on the
local NAE, only after validation passes. Never replace validation with reading
the XML by eye.

**Approval rule:** any tool call that changes the local NAE (deploy, create
case, execute task, create or delete users, create a realm, switch the active
realm, assign roles, delete cases, write `.env`, recreate the frontend) needs
user approval before it runs. The one exception is the final admin roles step
(Stage 2, step 6). Read-only calls (`list_versions`, `validate_process`, `list_processes`,
`list_tasks_of_case`)
don't. For file edits see Stage 1, step 6. `deploy_process` with
`replaceExisting` also deletes the cases and tasks of the replaced process (see
Redeploying while iterating).

## Stage 1: Validate (petriflow-mcp MCP)

1. If the Petriflow MCP does not answer, say so and stop. Never replace
   validation with reading the XML by eye.
2. Get the available Petriflow versions: read resource `petriflow://versions`;
   if resources aren't provided, call `list_versions`. Versions follow semver.
   Use the latest, unless the user or project pins another.
3. Call `validate_process` with that version, the raw XML and `appId` (the
   application folder name; check the tool schema for exact verbatim parameter
   names). Petriflow MCP requires the process id to be `<appId>/<processId>`
   when `appId` is set.
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

## Stage 2: Live test (engine-mcp MCP, http://localhost:8700/mcp)

Precondition: Stage 1 has no errors. If the NAE MCP tools are unavailable, say
so and stop. Do not fake results. Suggest running `docker compose up -d` in the
repository root and checking the admin (:8888), gateway (:8080) and plugin
(:8700) health endpoints. The plugin needs the whole cluster, not just a worker.

1. Read the process (places, transitions, data, actions). Write a scenario:
   ordered tasks, data values to set, expected enabled tasks and data after
   each step. If the process isn't understood well enough to predict outcomes,
   stop and ask instead of guessing inputs. If the process has role permissions
   or user-bound fields, read `references/role-scenarios.md` first and add role
   scenarios: every step then runs as an impersonated test user, because a
   token-less call is the system user and proves nothing about permissions.
   The impersonation token gives the identity (author) only: the MCP does not
   enforce role permissions, so check permissions with a real login over REST
   as described there.
2. Call `list_processes` to see which process ids and versions are deployed.
   Present to the user, in one message: the processes to deploy (the plugin
   deploys to its default worker, `NETGRIF Root Worker`), for each whether it is
   a new deploy or a replacement (the replaced id and version, and that its
   cases and tasks will be deleted), the case to create (title), the test users
   with their roles (role scenarios) and the realm `app-users` they live in (and,
   if it does not exist yet, that it is created, that `DEFAULT_REALM=app-users`
   is written to `.env` and that the frontend is recreated), the cleanup, and
   the full scenario. Ask
   for approval **once**. Approval covers `deploy_process` (including
   `replaceExisting` for these processes) or `upload_application` +
   `deploy_application` when the scenario uses a package, `create_case`, every
   `execute_task` in that scenario, creating the realm `app-users`, its `.env`
   entry and the frontend recreate, creating its test users, `assign_role`, and
   the cleanup deletes, and their repeats while you iterate on the same
   implementation: later replacements of the same processes need no new
   approval. The plugin cannot delete users (see step 5). Anything outside it
   (extra processes, extra tasks, different data, a second case, a changed
   scenario) needs new approval.
3. After approval: compare `git hash-object` (first 8 characters) of every file you
   are about to deploy with the hash you noted when you last read or wrote it,
   or with the `Hash` column of the application `README.md`. The user may have
   edited it in the builder. Re-read files that differ and keep the user's
   changes; do not deploy from a stale copy. Then `deploy_process` (see
   Redeploying while iterating) →
   `create_case` → loop `list_tasks_of_case` → `execute_task` →
   `list_tasks_of_case`.
   In the plugin runtime `get_task` returns `data` as one synthetic group with
   `fields.content[]`; do not compare it against the module's nested group shape.
   After each step compare the actual enabled tasks and data to the expected
   ones. When a step fails, keep the exact outputs as evidence and clean up (step 5). Then fix the process, validate it
   again (Stage 1), redeploy it per
   the table below and run the scenario again from step 3 as a new run.
4. Several cooperating processes: deploy the processes that others reference (via caseRef, taskRef or case creation)
   before the processes that reference
   them, and include the cross-case effects (cases created, channels fired) in
   the expected results. This also applies across applications: take the order
   from the "Deploy order" and "Dependencies on other applications" sections of
   `processes/<app_name>/README.md`, and include referenced processes of other
   applications in the scenario you present for approval. Replace in the same
   order. Replacing a referenced process deletes its cases, so cases of other
   processes may hold dead caseRefs: redeploy the processes that reference it (with `replaceExisting` if the same
   version is deployed) and recreate their
   cases in the scenario.
5. **Clean up after every scenario**, also a failed one, so the user finds a
   clean UI. Delete the test cases you created (`delete_case`), including cases
   created by actions. Test users use the `mcptest_` prefix; the plugin runtime
   cannot delete them (`delete_user` is unsupported because the admin REST API
   has no user-delete route; it answers with `isError` false and the text
   `{"error": "Deleting users is not supported ..."}`, so read the text, not
   the flag), so list them in the report and do not claim
   cleanup that did not happen. Delete nothing you did not create. Deployed
   processes, the menu and the realm `app-users` stay. The deployed process must be the final file: if
   the XML changed after the last deploy, replace it, run the scenario again and
   clean up again. Report what was deleted and what could not be deleted.
6. **Admin roles, once, as the last step** (after the last deploy and scenario,
   not after every replacement): the `admin` account gets no process roles
   automatically. Follow "Admin roles" in `AGENTS.md` and
   `references/role-scenarios.md`: compare the `stringId` of the roles of the
   deployed processes with the roles of `admin` (`get_user` in realm `Admin`),
   `assign_role` only if some are missing, and always `switch_realm` back to
   `app-users`. A global role `x` of a process is listed by `list_global_roles`
   as `global_x`. No approval needed. Report assigned or unchanged.

## Redeploying while iterating

`<version>` in the process XML is the process version, not the Petriflow
version. `deploy_process` has an optional boolean `replaceExisting` (default
`false`). The engine fails when the same process id and version is already
deployed and the flag is not `true`. With `true` the engine deletes the
deployed version **including all its cases and tasks** and imports the provided
XML.

In the plugin runtime the replacement first deletes the deployed process and
then waits about 5 s before importing. If the old version is still listed, the
plugin skips the import and the call fails. Re-check `list_processes` and retry
once the old version is gone; do not bump the version to get around it.

An earlier cluster reported success from `delete_process` and then failed
asynchronously when test users held roles of the process (engine log:
`Requested role ID in AssignRolesToUserRequest cannot be null`), and refused to
import the same process id again. On the 1.1.0 cluster (tested 2026-11-24)
`delete_process` removed a process whose local role a test user held, the role
disappeared from the user, and the same id was imported again at once, also with
`replaceExisting`. Still check `list_processes` after a delete. Local role ids
change with every import: assign them again.

## Deploying an application package

For several processes of one application, the cluster can take a package: build
the ZIP with a `multipart/form-data` POST to
`http://localhost:3000/applications/package` — fields `appId`, `name`, `version`
(or one `manifest.xml` file), the process XML files, and optional
`validate=true`; the response is the ZIP. Then `upload_application` and
`deploy_application` with the worker name. For one process, `deploy_process` is
simpler.

| Situation                                                                | `<version>` in the XML                                                                                                           | `deploy_process`                            |
|--------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| Process id not deployed (per `list_processes`)                           | `1.0.0` for a new process, otherwise unchanged                                                                                   | plain                                       |
| Id and version deployed by you earlier in this task, same implementation | unchanged                                                                                                                        | `replaceExisting: true`                     |
| The user gave a new instruction to edit an implemented process           | bumped once for that instruction: minor for added or changed behavior, major for removed fields or transitions; ask when unclear | plain (a new version, nothing is replaced)  |
| Id and version deployed, but not by you in this task                     | unchanged                                                                                                                        | ask the user before using `replaceExisting` |

- Never bump the version to get around a failed or refused deploy.
- Check `list_processes` before every deploy. After a failed deploy do not retry
  blindly with `replaceExisting: true`; follow the table.
- "Deployed by you in this task" means your own `deploy_process` call in this
  session.

## Quick reference

| Need                             | Tool                                                              | Approval                                                             |
|----------------------------------|-------------------------------------------------------------------|----------------------------------------------------------------------|
| List language versions           | `petriflow://versions` / `list_versions`                          | no                                                                   |
| Check XML                        | `validate_process`                                                | no                                                                   |
| List deployed processes          | `list_processes`                                                  | no                                                                   |
| Detect edits made in the builder | `git hash-object <file>`                                          | no                                                                   |
| Apply fix to file                | edit                                                              | only for existing/user files                                         |
| Deploy / create case / run task  | `deploy_process`, `create_case`, `execute_task`                   | yes, once per presented scenario                                     |
| Redeploy the same version        | `deploy_process` with `replaceExisting: true`                     | covered by that approval; deletes the process's cases and tasks      |
| Inspect case tasks               | `list_tasks_of_case`                                              | no                                                                   |
| Realm for test users             | `list_realms`, `current_realm` (read); `create_realm`, `switch_realm` | read: no; create/switch: yes, once per presented scenario            |
| Role ids                         | `list_process_roles`, `list_global_roles` (not `get_process`)     | no                                                                   |
| Test users and roles             | `create_user`, `assign_role`, `get_user`, `whoami`                | yes, once per presented scenario; see `references/role-scenarios.md` |
| Admin roles (last step)          | `switch_realm`, `get_user`, `assign_role` for `admin`             | no; only if roles changed; switch back to `app-users`                |
| Clean up after the scenario      | `delete_case` (`delete_user` unsupported: result text `error`)    | covered by that approval; only what the scenario created             |

## Report

End with: Petriflow version used; validation issues → fixes → final state;
deployed process ids and versions (new or replaced, and the cases a
replacement deleted); case id; per-step table (task, input, expected, actual,
pass/fail); for role scenarios the matrix (user × action → expected, observed,
verdict); the cleanup result; the test users (realm `app-users`, password
`password`, roles); whether the admin roles step assigned roles or left them
unchanged; suggested process changes for any mismatch. If the
process stays deployed, finish with the "Try it now" block from "Hand-off to the
user" in `AGENTS.md`.

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
- Deploying or replacing a process from a copy that the user has edited in the
  builder since you read it.
- Running a role-protected process only token-less (as system) and calling the
  permissions fine.
- Drawing a permission conclusion from a call without an impersonation token, or
  from a permitted result of a call with one: the MCP does not enforce
  permissions (use the real login over REST).
- Reusing role ids from before a redeploy.
- Creating test users in the realm `Admin` (every user there is an administrator,
  so role assignments prove nothing), or creating any realm other than `app-users`.
- Calling `assign_role` with an `importId` or the output of `get_process` instead
  of the `stringId` from `list_process_roles` / `list_global_roles`.
- Not checking `current_realm` before a user operation (it resets to `Admin` when
  the plugin restarts), or leaving the realm on `Admin` after the admin roles step.
- `assign_role` without the roles the user already has (it replaces the whole set).
- Assigning roles to `admin` after every replacement of a process, or when
  `admin` already has all of them, or not at all at the end of the implementation.
- Creating `app-users` without writing `DEFAULT_REALM=app-users` to `.env` and
  recreating the frontend, so nobody can sign in there.
- Retrying and adjusting a role scenario until it matches the expectation.
- Leaving test cases behind, or deleting ones you did not create.
- Claiming test users were deleted when the plugin's `delete_user` returned an
  error; they stay and must be reported.
- Retrying a plugin replacement immediately instead of waiting until the old
  process is gone.
- Writing impersonation tokens into files, the report or chat output.
