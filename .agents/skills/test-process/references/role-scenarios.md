# Role and permission scenarios

Read this when the process has role permissions (roles on transitions or data
fields) or user-bound fields, or when who may see a case matters (R6 in
`generate-process`). It extends Stage 2 of `test-process`: the same approval,
redeploy rules and report, but every step runs as the user who is supposed to do
it. It tests the process, not the engine-mcp mechanism itself.

## How impersonation works

- **Minting:** `create_user(...)` returns the new `User`. Its impersonation
  token is in the response at `attributes["MCP_IMPERSONATION_TOKEN"]`. It is
  opaque and stable per user: reuse that exact string for every call as that
  user.
- **Realm:** all test users live in the realm `app-users` (AGENTS.md, "Realms").
  The MCP works in one active realm: `create_user`, `get_user`, `assign_role` and
  tokens act in it, and a token works only in the realm of its user. After
  `switch_realm` to `Admin` (final admin-roles step) the tokens stop working, so
  switch back to `app-users` at once. A plugin restart resets the active realm to
  `Admin`: check `current_realm` before every user operation.
- **Applying:** these tools take `impersonationToken`: `whoami`, `create_case`,
  `delete_case`, `deploy_process`, `delete_process`, `assign_task`,
  `cancel_task`, `finish_task`, `execute_task`, `set_data_at_task`, `get_case`,
  `get_task`, `list_tasks_of_case`. The engine evaluates the whole call as that
  user: author, view filtering, assign/set/finish rights, delete rights.
- **No token means system:** a call without the token runs as the system user
  with unlimited rights. Never draw a permission conclusion from a token-less
  call. Omit the token deliberately and only for admin-side work: deploying or
  replacing the process and the final cleanup.
- **Never take a token:** `create_user`, `delete_user`, `get_user`,
  `assign_role`, `get_process`, `list_processes`, `list_process_roles`,
  `list_global_roles`, and the realm tools (`list_realms`, `create_realm`,
  `current_realm`, `switch_realm`, ...).
- **Roles:** the `roles` arguments are the `stringId` of the roles, as strings.
  `get_process` shows roles only by `importId`, which `assign_role` does not
  accept. Read the `stringId` of the roles of a process with
  `list_process_roles(processIdentifier)` and of global roles with
  `list_global_roles`; `processRoles` in `get_user` shows what a user has.
  `assign_role` is authoritative: the list replaces the user's whole set of
  roles, and an omitted id is removed, so include the roles the user must keep
  (for example the global `default`; check `get_user` first).
- **Role ids change when a process is replaced.** After every deploy read the
  local role ids again with `list_process_roles` and assign them again. Never
  reuse ids from before the redeploy.
- **Tokens are secrets.** Do not write them into files, the report or chat
  output. Name users instead.
- A tool error such as "Invalid or tampered token" or "Unknown impersonation
  user ..." is a result. Report it, do not work around it.

## Setup (as system, no token)

0. **Realm.** Call `list_realms`. If `app-users` does not exist, create it
   (`create_realm`, name `app-users`, `makeActive`); otherwise `switch_realm` to
   it. Never create another realm. Check `current_realm` is `app-users`. Write
   `DEFAULT_REALM=app-users` into `.env` and recreate the frontend (see
   AGENTS.md, "Realms"), so the test users can sign in there. Realm creation,
   the switch and the `.env` change are part of the approved scenario.
1. Deploy the process (see "Redeploying while iterating" in `SKILL.md`) and read
   the `stringId` of its roles with `list_process_roles` and of the global roles
   it uses with `list_global_roles`.
2. Create one test user per role to test, plus one user without roles. Check the
   `create_user` schema for its parameters, pass `password: "password"` and
   prefix every test user with `mcptest_`, so the report and a future cleanup
   can tell them from real users.
3. `assign_role` per user with the ids from step 1. Check the result with
   `get_user`.
4. `whoami` with each user's token: it must return exactly that user. If not,
   stop and report: every later result would be worthless.

## Expected matrix first

Before running anything, derive from the process XML who may do what, and write
a matrix: user (role) × action → expected outcome. Actions are: see the case,
see the task, assign, set data, finish, cancel, delete. If the XML does not
decide an outcome, ask the user instead of guessing.

## Scenarios

Cover the ones that apply to the process:

1. **View enforcement.** `list_tasks_of_case`, `get_task` and `get_case` as a
   role-holder, a non-holder and an unrelated user. Distinguish "empty or
   filtered" from "error" and report which one it was.
2. **Operation rights.** Assign, set data, finish and cancel a task as the right
   role (must work) and the wrong role (must fail; note where in the flow it is
   refused). Also `execute_task` end to end as both.
3. **Role changes mid-case.** Grant a role with `assign_role`, rerun a
   previously denied action (must now work), revoke the role, rerun (must fail
   again).
4. **Author attribution.** `create_case` as user X, then `get_case` as X shows X
   as the author.
5. **Per-user cases.** Where each user has their own case, user A must not see
   user B's case.
6. **Destructive rights.** `delete_case` as a user without the right (must
   fail), only if the process or requirement cares. Run `delete_process` as a
   non-admin last, and only if it matters: if it unexpectedly succeeds, the
   process under test is gone and must be redeployed.

## While running

- Every step uses the token of the user who is supposed to do it. A step without
  a token is system and proves nothing about permissions.
- A divergent result is the finding. Report the exact tool output: error text,
  filtered versus empty, author and user names. Never retry and adjust until the
  result matches the expectation.
- Label each outcome: process permission behavior, schema or validation error, or
  suspected engine or MCP defect.
- A mismatch with the matrix is either a process bug (fix the XML, validate,
  replace the deployed process, run a new scenario) or an engine defect (report
  it).

## Cleanup (after every scenario, also after a failed one)

1. Delete the cases you created, including cases that actions created in other
   processes, with `delete_case` and no token. A replaced process already took
   its cases with it.
2. The plugin runtime cannot delete users: the admin REST API has no
   user-delete route, so `delete_user` returns an error. Do not claim it
   succeeded; list the `mcptest_` users in the report (with their realm
   `app-users`) so they can be removed later. A future admin image fix will add
   the endpoint.
3. The realm `app-users` is not deleted: it stays, like the deployed processes,
   and the test users stay usable for the developer.

Never delete anything you did not create. The deployed processes and the menu
stay. Report what you deleted and anything you could not find or delete.

## Admin roles (last step of the implementation)

The `admin` account does not get the roles of processes automatically. Once,
after the last deploy and the last scenario (not after every replacement), do
the "Admin roles" steps from `AGENTS.md`: collect the `stringId` of the roles of
all deployed processes of the application and of their global roles; `switch_realm`
to `Admin` and read the roles of `admin` with `get_user`; change nothing if
`admin` already has all of them, otherwise `assign_role` with the union of its
existing roles and these; then always `switch_realm` back to `app-users` and
check `current_realm`. This step needs no approval and is not part of the
scenario presented for approval. A replaced process has new local role ids, so a
replacement counts as a change. Report whether the roles were assigned or left
unchanged.

## Report

Add to the `test-process` report: the scenario matrix (user × action → expected /
observed / verdict), the outcome label of every deviation, the cleanup
result, the test users (realm `app-users`, password `password`, roles) and the
result of the admin roles step.
