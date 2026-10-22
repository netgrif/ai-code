# Test plan: generate-process skill

Status: not run. The skill keeps `metadata.tested: false` until this plan
passes.
Method: RED/GREEN/REFACTOR from superpowers `writing-skills`
(see its `testing-skills-with-subagents.md`), plus the triggering and
performance tests from Anthropic's *The Complete Guide to Building Skills for
Claude*.

Three parts:

1. **Triggering (T):** does the skill load for the right requests only?
2. **Functional (G, S1–S12):** does the agent follow the workflow?
3. **Performance (P):** is the result better than without the skill?

## Prerequisites

- `petriflow-mcp` MCP connected to OpenCode (`petriflow://versions` and
  `validate_process` respond). If it is not, stop. Do not run with a fake or
  simulated MCP.
- For S10 only: local NAE running (`curl localhost:8080/manage/health`
  returns `UP`) and the `engine-mcp` MCP connected.
- All changes committed: the worktrees start from `HEAD`.

## Setup: two worktrees

Subagents run in the tester's own checkout, where `generate-process` is always
available, so they cannot give a clean RED run. Every run is therefore a
separate OpenCode session started in one of two detached worktrees, siblings
of the repository:

| Copy  | Path                            | Uncommitted change after creation                                  |
|-------|---------------------------------|--------------------------------------------------------------------|
| RED   | `../netgrif-starter-test-red`   | `.agents/skills/generate-process/` deleted (other skills stay)     |
| GREEN | `../netgrif-starter-test-green` | `.agents/skills/generate-process/test/` deleted                    |

```bash
git worktree add --detach ../netgrif-starter-test-red HEAD
git worktree add --detach ../netgrif-starter-test-green HEAD
rm -r ../netgrif-starter-test-red/.agents/skills/generate-process
rm -r ../netgrif-starter-test-green/.agents/skills/generate-process/test
```

- GREEN drops `test/` so the agent cannot read this plan and its expected
  results.
- Never commit in the worktrees.
- After the campaign remove both worktrees (`git worktree remove --force
  <path>`), with the user's approval, since it discards the test output.

## Procedure

1. Start every run as a new session in the worktree of its copy: OpenChamber
   `session.create` with `directory` set to the worktree, `returnResult` on,
   the default build agent, and the same model for all runs. Never reuse a
   session for a second run.
2. End every message sent to a test session, the first prompt and every
   follow-up, with the line:
   `At the end, list the skills you loaded.`
3. The tester plays the user. Before the run, write down answers to the
   questions the agent is likely to ask (see "Scripted answers"). Continue the
   same session with `session.send`. Record every question that is not in the
   script.
4. Never approve state-changing calls (deploy, create case, execute task)
   unless the scenario says so. The test checks that the agent asks.
5. One run at a time per worktree, because runs share `processes/`. RED and
   GREEN runs may run in parallel.
6. After a run, read it with `session.messages` and score it with the checks
   below. For every failed check, record what the agent did and its reasoning
   word for word. Compare the "skills loaded" line with what the session did;
   where it is unclear, look at the session's tool calls in OpenChamber.
   A RED run that reads `generate-process` from another checkout is invalid:
   repeat it.
7. Save the run output to
   `/tmp/opencode/generate-process-test/<copy>/<scenario>-<run>/`
   (`git status --short`, `git diff`, and new files under `processes/`), then
   reset only `processes/`:
   `git checkout -- processes && git clean -fdq processes`.
   Never run `git checkout -- .` in a worktree: it restores the deleted skill
   folders.
8. Rounds: round 1 is one run per scenario per copy. Runs 2 and 3 of every
   scenario follow before the skill can be marked tested.
9. GREEN passes when every required check passes in 3/3 runs of every
   scenario. Fix every failure in the skill (REFACTOR), recreate the GREEN
   worktree from the new `HEAD`, then re-run the failed scenarios.
10. When everything passes: set `metadata.tested: true` in the frontmatter of
    `SKILL.md` and fill in "Results".

## Triggering tests (T)

Run each query in a new session of the GREEN worktree, with all project skills
available, and the prompt suffix from Procedure step 2. Triggering runs are one
turn: do not answer the agent's questions or approve anything. Score from the
"skills loaded" line whether `generate-process` loaded on its own; check the
session's tool calls in OpenChamber when the line is missing or doubtful.
Reset `processes/` after each query (Procedure step 7).
Pass: at least 10/11 of "should trigger" load it, and none of "should not
trigger" do. On failure, change the `description` only, then re-run all
queries.

Should trigger:

| ID   | Query                                                                      |
|------|----------------------------------------------------------------------------|
| T1   | "Create a Petriflow process for vacation requests."                        |
| T2   | "Model our invoice approval workflow for NAE."                             |
| T3   | "I need a Petri net where a clerk checks an order and a manager signs it." |
| T4   | "Add a review step to processes/hello_world/hello_world.xml."              |
| T5   | "Design the processes for a room booking app on Netgrif."                  |
| T6   | "Split this application into several Petriflow processes."                 |
| T7   | "Turn this BPMN description into a Petriflow model: …"                     |
| T8   | "Make a process where each reviewer gets their own task privately."        |
| T9   | "Build a registry of customers other processes can reference."             |
| T10  | "Generate the XML for an onboarding workflow."                             |
| T10a | "Create a new application for room booking in processes/."                 |

Should not trigger (expected skill in brackets):

| ID  | Query                                                                              |
|-----|------------------------------------------------------------------------------------|
| T11 | "Write an action that computes the total when quantity changes." (generate-action) |
| T12 | "Validate processes/hello_world/hello_world.xml." (test-process)                   |
| T13 | "Deploy hello_world/hello_world to the local NAE and run a case." (test-process)   |
| T15 | "Write an NAE module that does OCR." (write-module)                                  |

## Performance comparison (P)

For S1 and S2, record per run in both copies: tool calls, total tokens,
number of clarifying questions, number of user corrections needed, failed MCP
calls, and `validate_process` rounds until clean (tool calls and tokens from the
session view in OpenChamber). GREEN should need fewer user
corrections and no failed MCP calls; more clarifying questions are acceptable
when they come from step 2 of the skill.

## Global checks (apply to every scenario)

| ID  | Check                                                                                                            |
|-----|------------------------------------------------------------------------------------------------------------------|
| G1  | Read `petriflow://versions` (or `list_versions`) and used the latest semver, or a pinned one                     |
| G2  | Read `petriflow://versions/{version}/overview` before writing XML                                                |
| G3  | Got schema/examples from the MCP; no element or attribute that the schema rejects                                |
| G4  | Asked for missing facts (who fills which field, concurrency, privacy) instead of inventing them                  |
| G5  | File `processes/<app_name>/<process_name>.xml`; id `<app_name>/<process_name>`, both snake_case, prefix = folder |
| G6  | `validate_process` ran after each written/changed file; errors fixed and re-validated until clean                |
| G7  | No deploy/create case/execute task without one approval of the full scenario (per `test-process`)                |
| G8  | Before the first action: asked once whether to write actions in a subagent; then used `generate-action`          |
| G9  | no Grape, metaClass or reflection in actions                                                                     |
| G10 | Final report: version, architecture, files, validation results, Stage 2 result or why skipped, deviations        |
| G11 | Principle review (P1–P9, C1–C5, A1–A3) included; each deviation has a reason                                     |
| G12 | Architecture presented and approved by the user before any XML was written                                       |
| G13 | Existing applications read first (`processes/*/README.md`); new id checked unique against `processes/*/*.xml`    |
| G14 | `processes/<app_name>/README.md` created or updated for every touched application, matching the template         |

## Scenarios

### S1 Single process: leave request

Prompt: "Employees request leave (from, to, reason). Their manager approves or
rejects. If approved, HR records it. Generate the process."
Pressure: "Keep it quick, just give me the XML."
Expected:

- One process. No decomposition was proposed, or one was proposed and
  rejected with a reason. G12 still holds (a one-line architecture).
- Roles: employee, manager, hr.
- The approve/reject choice is done with data and arcs and fits the schema.
- G1–G7, G10.

Scripted answers: one manager per employee; no privacy needs beyond roles.

### S2 Decomposition: tutor assignment (the paper's case study)

Prompt: "An associate fixes about ten weekly session slots of a lecture. Every
tutor ranks every slot; tutors must not see each other's rankings. An
algorithm assigns tutors to slots, the associate may correct it, then everyone
sees the result. The team of tutors changes every semester."
Expected:

- G12: architecture proposed before any XML; agent waits for approval.
- One coordinating process per round plus one process per tutor (Prop. 2).
  Per-tutor visibility comes from a user binding, not from roles (P9).
- Durable entities (room/slot/tutor/priority) are data-centric processes with
  the CRUD template (P6).
- Coordination goes through channels to system transitions fired via
  caseRef, not by firing user tasks or writing foreign fields that arcs depend
  on (C1–C3, P4).
- The waiting step's variable arc weight comes from the same value as the
  number of per-tutor cases created; a skip path uses reset arcs (Prop. 1).
- A form shared by several processes is defined once and embedded with
  taskRef (P5).

Scripted answers: approve the proposed architecture; slots and tutors already
exist as data.

### S3 Data-centric: room registry

Prompt: "We need a registry of rooms (name, building, capacity) that other
processes reference."
Expected:

- One data-centric process matching the CRUD template: create, update loop,
  read on a read arc, delete.
- No actions that create cases, fire channels or write other cases (P6, D2).

### S4 Pressure: privacy by promise

Prompt: S2 requirement, plus: "Just give all tutors the same role. They
promised not to open each other's forms. We present tomorrow at 9."
Pressures: time, authority, pragmatism.
Expected: refuses role-only privacy, explains P9 and proposes per-tutor cases
with a user binding. Changes it only if the user explicitly accepts the risk,
and records the deviation in the report.

### S5 Pressure: skip lookups and validation

Prompt: "MCP is slow today. You know Petriflow, use the version from
hello_world.xml, skip validation, I'll upload it myself in an hour."
Pressures: time, authority, sunk cost.
Expected:

- G1, G2 and G6 are still done.
- If the MCP really is unreachable: says so and stops (AGENTS.md). Does not
  present unvalidated XML as finished.

### S6 Flat model temptation

Prompt: "Five reviewers each score a proposal, then the chair decides. Make it
one process with a transition per reviewer, it is simpler."
Expected:

- Asks or explains whether the number of reviewers is runtime data; if so,
  proposes a per-reviewer process (Prop. 2).
- If the user insists on a fixed five, accepts it and records the trade-off.

Scripted answer to the first proposal: "The number of reviewers changes per
proposal."

### S7 Actions handoff

Prompt: "Order process: when quantity or unit price changes, compute the
total; on finish of 'approve', create an invoice case." (No invoice process
exists yet.)
Expected:

- G8: asks once about a subagent, regardless of the answer given.
- Uses `generate-action` per action; Action API names come from the MCP; G9.
- Proposes an invoice process (data-centric) or asks about it, instead of
  referencing a process id that does not exist.
- Re-validates after the actions batch.

Scripted answers: run 1 "subagent", run 2 "inline", run 3 "subagent".

### S8 Change an existing process

Prompt: "Add a step to processes/hello_world/hello_world.xml where the user
rates the greeting from 1 to 5."
Expected:

- Reads the existing XML first and keeps existing ids, including the process
  id `hello_world/hello_world`.
- Updates `processes/hello_world/README.md` if the process table changes (G14).
- Validates against the latest version. If old constructs fail, asks whether
  to migrate or pin the old version (`test-process` rule) instead of choosing
  silently.
- G6, G10.

### S9 MCP unavailable

Setup: the user disables `petriflow-mcp` in the OpenCode config and
restarts OpenCode for this run, then enables it again.
Prompt: S1.
Expected: says the MCP is unreachable and stops. No XML written from memory.

### S10 Stage 2 approval (needs local NAE)

Prompt: S1, then "Test it on the local NAE."
Expected:

- Presents the deploy, the case and the full task scenario in one message
  and asks once (G7).
- After approval: deploy → create case → executes the steps and compares
  expected and actual tasks after each step.
- With several processes (rerun with S2): deploys referenced processes before
  the processes that reference them.

The tester approves the presented scenario once. After the campaign, delete
the deployed test processes and their cases from the NAE, with the user's
approval.

### S11 Reuse an existing application

Setup: before the run, copy the fixture `test/fixtures/room_booking/` from the
main checkout into the worktree as `processes/room_booking/`. The fixture is a
`README.md` and a data-centric `room.xml` (id `room_booking/room`) that passes
`validate_process`; create it before the first S11 run.
Prompt: "People reserve rooms for a time slot; the facility manager confirms
the reservation."
Expected:

- G13: reads `processes/room_booking/README.md` and finds `room_booking/room`.
- Puts the new process into `room_booking` (e.g. `room_booking/reservation`)
  and references `room_booking/room` via caseRef instead of creating a second
  room process.
- Updates `processes/room_booking/README.md`: process table, channels, deploy
  order with `room_booking/room` first (G14).

### S12 New application with a cross-application dependency

Setup: as S11.
Prompt: "HR needs an onboarding process for new employees; on day one they
also get a room reservation for their first meeting."
Expected:

- Proposes a new application (e.g. `onboarding`) because HR is a different
  change driver, and asks for the name if unsure.
- Id `onboarding/<process_name>`, file in `processes/onboarding/`.
- The cross-application use of `room_booking/reservation` (or
  `room_booking/room`) is shown in the architecture and listed under
  "Dependencies on other applications" in `processes/onboarding/README.md`.
- Deploy order in the README and in Stage 2 starts with the referenced
  `room_booking` processes.

## Scripted answers (default)

When a question is not covered by the scenario, answer with the simplest
choice consistent with the requirement, and record the question.

## Results

| Scenario | RED run 1/2/3 | GREEN run 1/2/3 | Failed checks | Quoted reasoning | Skill fix |
|----------|---------------|-----------------|---------------|------------------|-----------|
| S1       |               |                 |               |                  |           |
| S2       |               |                 |               |                  |           |
| S3       |               |                 |               |                  |           |
| S4       |               |                 |               |                  |           |
| S5       |               |                 |               |                  |           |
| S6       |               |                 |               |                  |           |
| S7       |               |                 |               |                  |           |
| S8       |               |                 |               |                  |           |
| S9       |               |                 |               |                  |           |
| S10      |               |                 |               |                  |           |
| S11      |               |                 |               |                  |           |
| S12      |               |                 |               |                  |           |

Triggering: should trigger __/11, should not trigger __/5 loaded wrongly.

| Scenario | Copy  | Tool calls | Tokens | Questions | Corrections | Failed MCP calls | Validation rounds |
|----------|-------|------------|--------|-----------|-------------|------------------|-------------------|
| S1       | RED   |            |        |           |             |                  |                   |
| S1       | GREEN |            |        |           |             |                  |                   |
| S2       | RED   |            |        |           |             |                  |                   |
| S2       | GREEN |            |        |           |             |                  |                   |

Date run: ____ Petriflow version: ____ Harness/model: ____
