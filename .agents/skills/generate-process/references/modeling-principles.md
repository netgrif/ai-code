# Petriflow modeling principles

Source: M. Kimmel, R. Lorenz, *Modeling with Process-Centric Objects: A Case
Study on the Netgrif Platform* (University of Augsburg), model repository
https://gitlab.com/uni-a/software-engineering-principles-for-process-centric-modeling.
The four principles M1–M4 come from it; the paper calls them preliminary. The
complementary rules R1–R6 and Prop. 1 come from the authors' earlier manuscript
*Software Engineering Principles for Low-Code Process Modeling*. This file
condenses both into checks an agent can apply. XML syntax is not given here on
purpose: take it from the Petriflow MCP schema and examples.

## Vocabulary

| Term                         | Meaning                                                                                                                         |
|------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Place, transition            | Petri net nodes; tokens in places form the marking (the state of the net)                                                       |
| Enabled, firing              | A transition is enabled when every input place holds the arc weight in tokens and every read arc's place a token; firing moves tokens |
| Read arc                     | Checks its place holds a token, consumes nothing; the transition stays available while the token is there                       |
| Reset arc                    | Empties its place when the transition fires                                                                                     |
| Variable arc                 | Weight is a data field, so the field value decides at runtime how many tokens move                                              |
| Process-centric class (PCC)  | One process XML: data fields, lifecycle, roles, forms and actions per transition                                                |
| Lifecycle                    | The Petri net of a PCC; decides which activities on its data happen in what order                                               |
| Process-centric object (PCO) | A case: runtime instance of a PCC with its own field values, marking and users                                                  |
| Network of running cases     | All cases at runtime, joined by caseRefs, taskRefs and actions                                                                  |
| User transition              | A transition a user executes through its form; granted by `roleRef` or `actorRef`                                               |
| System transition            | A transition no user may perform; it fires only through a channel or a trigger, or is embedded by a taskRef                     |
| Form, access mode            | The fields a transition shows; each `visible`, `editable` or `required` (required ⊂ editable ⊂ visible)                         |
| Role, actorRef               | Roles grant transitions to groups; `actorRef` with an `actor`/`actorList` field narrows a transition of one case to named users  |
| caseRef field                | Stores references to other cases (an object reference)                                                                          |
| taskRef field                | Embeds the form of another, enabled task into the current form                                                                  |
| Channel                      | After a user transition fires, its action fires a system transition in the cases its caseRef holds (M4)                         |
| Application                  | A set of PCCs whose cases form a network at runtime                                                                             |

A transition without `roleRef` or `actorRef` is open to the built-in roles
`default` (any logged-in user) and `anonymous`, and both are on unless the
process sets `<defaultRole>` and `<anonymousRole>`. A system transition is
therefore only "no user" when the process switches them off or otherwise keeps
them from it. Check this for every system transition.

Petriflow has no primitive that synchronizes two cases. A channel fires the
receiver from inside the sender's action; if the receiver is not enabled, the
sender still fires and its writes stay. Model so that the receiver is enabled
whenever the sender can fire.

## Helper notions

- **Access set of a transition:** fields its form shows, fields its actions
  read or write, and fields used as weights of its variable arcs.
- **Access graph of a PCC:** transitions and fields, joined when the field is
  in the transition's access set. A transition with an empty access set only
  moves tokens and stays outside the graph.
- **Change driver:** one group of people that requests changes for its own
  reason (e.g. the personnel office for personal data, the associate for
  priorities).
- **Cause graph:** edge C → C' when an action of C sends a channel to C',
  creates or deletes a case of C', or writes a field of C'.

## Core principles (M1–M4)

Apply them in this order: M1 shapes the transitions (the flat model), M2 and
M3 decide the PCCs, M4 decides how their cases are connected.

**M1 Static atomicity.** A user transition is atomic if exactly one user
executes it with one form. Every user transition is atomic.

- A form filled by several users in turn, or one transition every user of a
  role executes "for themselves", violates it: the form would show one user's
  data to others or adapt to the user.
- An activity with subactivities that need different forms is split into one
  transition per subactivity: first submission and revision
  (`assign_priority`, `reassign_priority`), automatic and manual distribution.
- Actions do not adapt a form, its title or its roles to the user or the phase
  to emulate several activities. That hides process logic in code.
- Check: name the one user and the one form of every user transition.

**M2 Dynamic atomicity.** The number of transitions of a lifecycle does not
depend on runtime data; only the number of cases may. *Work that grows with
the data belongs on cases.*

- A transition per tutor, reviewer, item or slot (`approve_user_1..n`) fails as
  soon as the count changes. Extract the repeated branch into its own PCC and
  create one case per element at runtime.
- Do not run n instances of an activity inside one case either; give each run
  its own case.
- Corollary (one case per user): one case offers at most one form per
  transition at the same time. If n users must each fill their own form at the
  same time and n is runtime data, use n cases. M1 plus R6 (visibility)
  together force a per-user PCC bound to its user.

**M3 Cohesion.** A PCC is cohesive if its access graph is connected.

- Several components are a *sign* of several reasons to change, not a rule.
  Ask (or check the requirement) whether different groups of people request
  changes to the components. Only if they do, cut the PCC into one PCC per
  change driver.
- Connect the cut PCCs with a **caseRef** (an object reference) so that one can
  show or read the data of the other. A cut does not need a channel unless the
  lifecycles must signal each other (M4).
- A connected graph may still join different change drivers through a shared
  field. Remove that field in thought; if the graph then splits along change
  drivers, consider the cut. The modeler decides.
- One group of people requesting all changes is a reason not to cut.
- A field no transition accesses is a component of its own: remove it, or name
  who reads it.

**M4 Object communication.** Cases are connected only at levels U4–U6. For each
aspect use the loosest level that works. *Model where possible, actions where
needed.*

| Level | Case C uses case C' by…                                            | Allowed |
|-------|--------------------------------------------------------------------|---------|
| U1    | reading or writing the marking of C'                               | no      |
| U2    | writing fields of C' without firing a transition of C'             | no      |
| U3    | firing a user transition of C'                                     | no      |
| U4a   | creating C', passing initial values and caseRefs                   | yes     |
| U4b   | firing a system transition of C' along a channel                   | yes     |
| U5    | holding a caseRef to C' and reading its fields                     | yes     |
| U6    | embedding a system transition of C' with a taskRef                 | yes     |

- Under this discipline each lifecycle can be understood, and checked for
  soundness, on its own.
- Use actions only for what the net, forms and roles cannot express:
  computations, creating cases, channels. Routing, waiting and permissions
  belong in the model.
- **Channel** = (name, sender transition, receiver transition):
    - the sender is a *user* transition; the channel runs after it fires (the
      finish event, post phase);
    - the receivers are the cases referenced by a caseRef in the sender's
      form or access set;
    - for each receiver it fires the receiver *system* transition only if it is
      enabled; otherwise it skips that receiver, and the sender is not blocked;
    - the name states its purpose;
    - no cascades: a receiver system transition does not send further
      channels. A cascade is a deviation with a reason.
- **Push a signal, pull the data.** A channel carries no data. The receiver's
  action reads what it needs from the sender through a caseRef (U5). The
  sender never writes the receiver's fields (U2).
- At creation (U4a) the creator may set initial values and the caseRefs both
  cases need, e.g. each per-user case gets a caseRef to its coordinator and
  the coordinator a caseRef list of the cases it created.

## Complementary rules (R1–R6)

**R1 Interface.** Declare per PCC which fields and transitions other PCCs may
use. Every foreign field an action reads is declared, every foreign transition
it fires is a declared system transition, every embedded transition is a
declared system transition.

**R2 One owner.** Every piece of knowledge has one owning PCC. Forms are shared
by embedding a system transition with taskRef, data through a data-centric PCC,
code through functions. Two isomorphic net fragments are extracted into their
own PCC only if they share a change driver and the replacing channels can be
atomic; otherwise they stay copied. Example: the CRUD template is copied into
every data-centric PCC (different drivers), but the priority form is defined
once in Priority (its `form` transition) and embedded twice.

**R3 Class categories.** Every PCC is exactly one of:

- **Data-centric:** (D1) no variable arc, and the lifecycle behaves like the
  CRUD template: `create` once, `update`/`read` freely, `delete` at least once,
  only system transitions silent; (D2) no outgoing edge in the cause graph (it
  creates, deletes, calls and writes nothing outside itself).
- **Process-centric:** D1 fails, it has an outgoing cause edge, and its own
  fields hold only coordination state; business data stays in referenced
  cases.

A PCC that fits neither is a modeling error. Size does not decide: a tiny PCC
that sends one channel is process-centric. Entities that live before, during
and after a workflow (rooms, tutors, slots) get their own data-centric PCC.

**R4 Communication checks.**

- C1: every system transition receives a channel, is embedded by a taskRef, or
  fires by a trigger.
- C2: every channel receiver is a system transition; no action fires a user
  task (U3).
- C3: every action navigates at most one caseRef field (Law of Demeter); give
  the coordinator direct caseRefs to every case it must reach.
- C4: one channel name = one purpose, one receiver per PCC.
- C5: a process part used more than once with one change driver is its own
  PCC, not a copied subnet.

**R5 Completion and transactions.** Every transition:

- A2: can be completed when it becomes enabled (the data exists by then);
- A3: makes all effects of its actions effective together or none. Touching
  no other case: fine. Touching one other case: handle the failed call.
  Touching two or more: not atomic, since Petriflow has no cross-case
  transaction or undo; split it or add compensation steps (saga). A channel to
  a list of receivers counts as one call per receiver.

**R6 Role-bounded visibility.** Every case a user can see (tasks they may
execute, fields such forms show) is one they are allowed to see. Roles select
by group only, so users of one role who must not see each other need separate
cases bound to each user at creation (`actorRef`). Access resting on users'
promises is a violation.

**Prop. 1 (Composition is not enough).** PCCs that are each correct can
deadlock together when a variable arc weight does not match runtime facts.
Example: a transition waits for `d` tokens, but only one channel delivers a
token while `d = 2`. Rule: set the weight field from the same value that
determines how many senders exist (e.g. the number of cases created), and give
a skip path with reset arcs.

The principles pull against each other: M2, M3 and R6 create PCCs, every cut
costs a caseRef or a channel, M4 and R2 limit what may cross a cut, and M1 and
R6 decide where a cut between two tasks must be a PCC boundary.

## Patterns (structure only; syntax from the MCP)

- **CRUD template (data-centric lifecycle):** places p1 (1 token), p2, p3, p4.
  `create`: p1 → p2, p3. `update`: loop on p2. `read`: read arc on p3 only.
  `delete`: p2, p3 → p4. `form`: system transition on a read arc to p3, never
  fired by a user; it holds the entity's form so other PCCs embed it by taskRef
  (U6) while the entity exists. Final marking: one token in p4.
- **Channel:** sender user transition (finish, post) → caseRef field in its
  access set → system transition in each receiver, fired only if enabled.
  Receiver must be enabled whenever the sender can fire.
- **Counter (wait for n answers):** the coordinator's start transition creates
  n per-user cases and puts n tokens (variable arc from field `n`) into a
  counting place; each per-user case sends `counter` to a system transition
  that moves one token on; the continuing transition consumes n (same field).
  `skip` empties the counting places with reset arcs.
- **Per-user case:** created by the coordinator, bound to its user through
  `actorRef`, holding a caseRef to the coordinator; its user task sends a
  channel back; system transitions receive `skip`/`finish` when the round ends.
- **Embedded editing:** a loop transition in the coordinator embeds the `form`
  system transitions of data-centric cases via taskRef, so one form edits
  several cases. It never embeds their user transitions (that would be U3).

## Worked example: tutor assignment (the paper's case study)

Requirement: each lecture has weekly session slots, each supervised by one
tutor. The associate collects the tutors; each tutor ranks every slot (and may
change the ranking until the distribution starts); a tool assigns tutors, the
associate may correct the result by hand, then everyone sees it. The tutor
team changes every semester.

1. **First attempt:** four activities in a row: `fix_tutors`,
   `state_priorities`, `assign_tutors`, `show_result`. Violates M1: several
   tutors share one transition, and `state_priorities` (first vs. new ranking)
   and `assign_tutors` (automatic vs. manual) each hide two forms.
2. **M1, flat model (two tutors):** `start_prio`, then per tutor a branch
   `create_tutor_i` → `update_tutor_i` loop → `assign_priority_i` →
   `reassign_priority_i` loop, then `auto_distribute`, `manual_distribute`
   loop, `finish_distribution`, `show_distribution` on a read arc. Every
   transition is atomic, but the number of branches is runtime data.
3. **M2:** one branch becomes the PCC Tutor-Assignment-Process (TAP), with the
   system transition `finish_assignment` that ends it. The
   Global-Assignment-Process (GAP) keeps one lifecycle for any number of
   tutors: `start_prio` (weight n) → `count_priority` (system) →
   `auto_distribute` (weight n) → `manual_distribute` loop →
   `finish_distribution` → `show_distribution`.
4. **M3:** TAP's access graph splits into personal data (`name`, `email`;
   `create_tutor`, `update_tutor`) and priorities (`slot`, `priority`;
   `assign_priority`, `reassign_priority`). Different change drivers
   (personnel office, associate), so Tutor becomes its own PCC; each TAP case
   holds a caseRef to its Tutor case. Tutor manages data and lives outside GAP
   and TAP.
5. **M4:** `start_prio` creates one TAP case per selected tutor (U4a) and passes
   the GAP caseRef; channel `counter`: `assign_priority` (TAP) →
   `count_priority` (GAP); channel `finish`: `auto_distribute` (GAP) →
   `finish_assignment` (each TAP). No other connection.

Result of the paper: two process-centric PCCs (GAP, TAP) plus the data-centric
Tutor. A deadline for the priorities would need a further transition in GAP
(the `skip` path of the counter pattern).

**Extension beyond the paper** (the authors leave data management out of
scope): a Lecture-Process (semester workflow; loop tasks embed `form`
transitions of the data-centric cases; starts a round; waits for `finish` from
GAP) and data-centric PCCs Semester, Room, Lecture, Contract, Slot, Tutor,
Priority on the CRUD template. The priority form lives in Priority and is
embedded by TAP and by the manual correction. Channels: `counter` (TAP → GAP),
`skip` and `finish` (GAP → TAP), `finish` (GAP → Lecture-Process). Creating
the GAP case is not a channel. Effect: adding a room type touches Room only;
replacing the algorithm touches one GAP action; letting tutors revise touches
TAP only.

## Review checklist

- [ ] M1: every user transition has one user and one form; subactivities with
      different forms are separate transitions; no action reshapes a form,
      title or roles per user or phase.
- [ ] M2: no transition per runtime element; runtime-sized work lives on
      separate cases.
- [ ] M3: each PCC has a connected access graph, or the split was checked
      against change drivers and kept with a reason; cut PCCs are joined by
      caseRef.
- [ ] M4: cross-case use only at U4–U6; no foreign field writes after creation
      (U2), no foreign user transitions fired (U3), no marking access (U1);
      logic the net can express is not in actions.
- [ ] Channels: sent from a user transition after it fires, to system
      transitions referenced in its access set, fired only if enabled, no
      cascades; the receiver pulls data through a caseRef.
- [ ] taskRefs embed only system transitions of other cases.
- [ ] System transitions really grant no one (no roleRef/actorRef, built-in
      `default` and `anonymous` roles kept off).
- [ ] R1: every foreign field/transition used is part of the target's
      declared interface.
- [ ] R2: shared forms defined once and embedded via taskRef.
- [ ] R3: each PCC is data-centric or process-centric, not both or neither.
- [ ] R4: C1–C5 hold; every action navigates at most one caseRef.
- [ ] R5: A2 and A3 hold; actions touching two or more cases have
      compensation.
- [ ] R6: per-user privacy enforced by `actorRef`, not by promise.
- [ ] Prop. 1: variable arc weights match the number of cases that send; a
      skip path exists.
- [ ] `immediate="true"` only on fields users search by, show as list columns,
      or that actions and menu filters query; each with a reason; none on
      technical, long, file or reference fields (see Indexed fields in
      `SKILL.md`). Data-centric PCCs usually index only the fields that
      identify an entity (name, code) and its state.
- [ ] Roles used by several processes or applications, or by the menu, are
      global (`global="true"` in every process using them, identical
      declaration); roles meaningful only inside one process stay local; no
      near duplicates of existing global roles (see Global roles in `SKILL.md`).
