# Role and permission scenarios

Read this when the process has role permissions (roles on transitions or data
fields) or user-bound fields, or when who may see a case matters (R6 in
`generate-process`). It extends Stage 2 of `test-process`: the same approval,
redeploy rules and report, but every step runs as the user who is supposed to do
it, through a real sign-in.

## Tooling on cluster 1.1.0 (BYPASS W3)

`engine-mcp` (plugin 1.0.0) cannot run these scenarios: it has no realm tools,
no role listing, its `create_user` makes users without a password in the realm
`Admin` (every user there is an administrator), and its impersonated calls do
not enforce role permissions (a user without the role created a case and set
data in a task of another role). Use `workarounds/nae.sh` (bash + curl, Git Bash
on Windows) for users, roles and every step of a scenario. Use `engine-mcp` only
for admin-side work: `deploy_process`, `list_processes`, `get_process`, and
`delete_case` in the cleanup.

`workarounds/nae.sh as <user> METHOD PATH [JSON]` signs in through the gateway
as that user of `app-users` (password `password`) and calls the engine REST API
with the user's session. The token is never printed. Output is the JSON body; an
HTTP status of 400 or more exits with 1 and prints `HTTP <code>` to stderr.

## Engine REST calls (gateway, `http://localhost:8080`)

| Step | Call |
|------|------|
| Create a case | `POST /api/workflow/case/` (trailing slash; without it 404) with `{"netId":"<process stringId>","title":null,"color":null}`; the case is in `outcome.aCase` or `outcome.outcomes[0].aCase` |
| Cases the user may see | `POST /api/workflow/case/search?page=0&size=50` with `{"process":[{"identifier":"<app>/<process>"}]}`; add `"query":"dataSet.<field>.textValue.keyword:\"<value>\""` to search by a field |
| Tasks of a case | `GET /api/task/case/<caseId>` (lists every task of the case, also ones the user may not do: try the task, do not infer from the list) |
| Assign | `GET /api/task/assign/<taskId>` |
| Set data | `POST /api/task/<taskId>/data` with `{"<taskId>":{"<fieldId>":{"type":"text","value":"..."}}}` (`enumeration_map` takes the key, `number` a number) |
| Read data | `GET /api/task/<taskId>/data` |
| Finish | `GET /api/task/finish/<taskId>` |
| Cancel | `GET /api/task/cancel/<taskId>` |

How the engine answers:

- **A refused operation is often HTTP 200** with `{"error": "..."}` in the body,
  for example `Field "Customer ID" has null value` (required field), or
  `... cannot be assigned` (already assigned). Read the body of every call.
- **No permission:** assign answers `403 Forbidden`; finish without assign
  answers `405` ("not assigned").
- **Data by id is not protected:** `GET /api/task/<id>/data` and
  `GET /api/workflow/case/<id>` return the data to any signed-in user who knows
  the id. Test what a role sees through `case/search` and through the tasks it
  can assign, and report the by-id gap (AGENTS.md, "Known gap: data by id")
  when the requirement hides data from a role.
- Pass role ids as `stringId` strings. Global roles of a process are listed by
  `workarounds/nae.sh roles` with `importId` `global_<id>`; local roles with
  their `processIdentifier`. A new user has the global `default` role.

## Expected matrix first

Before running anything, derive from the process XML who may do what, and write
a matrix: user (role) × action → expected outcome. Actions are: see the case
(search), see the task, assign, set data, finish, cancel, delete. If the XML
does not decide an outcome, ask the user instead of guessing.

## Setup

0. **Realm.** `workarounds/nae.sh realms`: `app-users` must exist with
   `"defaultRealm":true` (the compose job `realm-init`, BYPASS W2, does it). If
   not, read `docker compose logs realm-init` and stop. Never create a realm.
1. Deploy the process (see "Redeploying while iterating" in `SKILL.md`) and read
   the `stringId` of its roles and of the global roles it uses with
   `workarounds/nae.sh roles` (optionally with a search text).
2. Create one test user per role to test, plus one user without roles:
   `workarounds/nae.sh create-user mcptest_<name> <First> <Last>`. Note the `id`
   of each from the output. The prefix `mcptest_` tells test users from real ones.
3. Assign roles: `workarounds/nae.sh assign-roles app-users <userId> <defaultRoleId> <roleId>...`.
   It replaces the whole set, so include the `default` role id (read it first
   with `workarounds/nae.sh user app-users <userId>`). Check the result with
   `user` again.
4. Sign-in check: `workarounds/nae.sh as mcptest_<name> POST '/api/workflow/case/search?page=0&size=1' '{}'`
   must answer for every user. If a sign-in fails, stop and report.

Role ids change when a process is replaced: read them again after every
replacement and assign them again. Never reuse ids from before the redeploy.

## Scenarios

Cover the ones that apply to the process.

1. **View.** `case/search` as a role-holder, a non-holder and an unrelated
   user. Distinguish "empty" from "error" and report which one it was.
2. **Operation rights.** Assign, set data, finish and cancel a task as the right
   role (must work) and the wrong role (must fail; note the status and body).
3. **Required fields and validations.** Finish with a required field empty (must
   fail with an `error` body), then fill it and finish.
4. **Role changes mid-case.** Grant a role with `assign-roles`, rerun a
   previously denied action (must now work), revoke the role, rerun (must fail
   again).
5. **Author and per-user cases.** A case created by user X shows X as
   `author`; where each user has their own case, user B must not find user A's
   case in `case/search`.
6. **Destructive rights.** Delete a case as a user without the right (must fail),
   only if the process or requirement cares.

## While running

- Every step runs as the user who is supposed to do it (`nae.sh as`). A step
  through `engine-mcp` or without a user is system and proves nothing about
  permissions.
- A divergent result is the finding. Report the exact output: status, error
  text, filtered versus empty, author and user names. Never retry and adjust
  until the result matches the expectation.
- Label each outcome: process permission behavior, schema or validation error, or
  suspected engine defect.
- A mismatch with the matrix is either a process bug (fix the XML, validate,
  replace the deployed process, run a new scenario) or an engine defect (report
  it).

## Cleanup (after every scenario, also after a failed one)

1. Delete the cases you created, including cases that actions created in other
   processes and cases left by a failed step, with the MCP `delete_case` (no
   token). Find them with `case/search` as a user who sees all of them, or
   `list_tasks_of_case`/`get_case` by id. A replaced process already took its
   cases with it.
2. Users cannot be deleted (the admin REST API has no user-delete route). List
   the `mcptest_` users in the report with their realm `app-users`; they stay
   usable for the developer.
3. The realm `app-users` stays, like the deployed processes.

Never delete anything you did not create. The deployed processes and the menu
stay. Report what you deleted and anything you could not find or delete.

## Admin roles (last step of the implementation)

Once, after the last deploy and the last scenario, do the "Admin roles" steps
from `AGENTS.md` with `workarounds/nae.sh` (`roles`, `users Admin`,
`user Admin <id>`, `assign-roles Admin <id> ...`). This step needs no approval
and is not part of the scenario presented for approval. Report whether the
roles were assigned or left unchanged.

## Report

Add to the `test-process` report: the scenario matrix (user × action → expected /
observed / verdict), the outcome label of every deviation, the cleanup result,
the test users (realm `app-users`, password `password`, roles) and the result of
the admin roles step.
