# Petriflow modeling principles

Source: M. Kimmel, R. Lorenz, *Software Engineering Principles for Low-Code
Process Modeling: A Case Study on the Netgrif Platform* (University of
Augsburg). This file condenses the vocabulary, the nine principles and the
case study into checks an agent can apply. XML syntax is not given here on
purpose: take it from the Petriflow MCP schema and examples.

## Vocabulary

| Term               | Meaning                                                                                                             |
|--------------------|---------------------------------------------------------------------------------------------------------------------|
| Place, transition  | Petri net nodes; tokens in places form the marking (the state of the net)                                           |
| Enabled, firing    | A transition is enabled when every input place holds the arc weight in tokens; firing moves tokens                  |
| Read arc           | Checks its place holds a token, consumes nothing; the transition stays available while the token is there           |
| Reset arc          | Empties its place when the transition fires                                                                         |
| Variable arc       | Weight is a data field, so the field value decides at runtime how many tokens move                                  |
| Petriflow class    | One process XML: data fields, lifecycle net, roles, actions, forms                                                  |
| Case               | Runtime instance of a class; its state = field values + marking                                                     |
| Task, form         | A transition a user may execute; it shows selected data fields; submitting it fires the transition                  |
| Role, user binding | Roles grant transitions to groups; a user binding (user list field) narrows a transition of one case to named users |
| caseRef field      | Stores references to other cases                                                                                    |
| taskRef field      | Embeds the form of another case's task into the current form                                                        |
| Channel            | An action navigates a caseRef field and fires a transition in the referenced case                                   |
| System transition  | A transition no role and no user binding grants; it fires only through a channel (or at creation)                   |
| Application        | A set of classes whose cases form a network at runtime                                                              |

Petriflow has no primitive that synchronizes two cases. A channel fires the
receiver from inside the sender's action. If the receiver is not enabled, the
sender still fires and its writes stay. Model so that the receiver is enabled
whenever the sender can fire.

## Helper notions

- **Access set of a transition:** fields its form shows, its actions read or
  write, and fields used as weights of its variable arcs.
- **Access graph of a class:** transitions and fields, joined when the field is
  in the transition's access set.
- **Change driver:** one group of users that requests changes for its own
  reason (e.g. facility management for rooms, HR for contracts).
- **Cause graph:** edge C → C' when an action of C sends a channel to C',
  creates or deletes a case of C', or writes a field of C'.

## The nine principles

### Carried over from software engineering

**P1 Single responsibility.** At most one change driver owns changes that touch
a class. Check: name the driver of every transition and field; more than one
driver means split.

**P2 Cohesion.** The access graph of a class is connected, and every field is
accessed by some transition. Check: if the graph splits into k components,
cut the class into k classes joined by channels. A field nobody accesses is an
error.

**P3 Modularity.** Declare per class which fields and transitions other classes
may use (its interface). Every foreign field an action reads or writes is
declared, every foreign transition it fires is a declared system transition,
and no action reads places or the marking of another case.

**P4 Low coupling.** Usage levels from tightest to loosest:

| Level | Class C uses class C' by…                                  | Allowed |
|-------|------------------------------------------------------------|---------|
| U1    | reading places/marking of a C' case                        | no      |
| U2    | writing a field of a C' case without firing anything       | no*     |
| U3    | firing a transition a user could also fire                 | no      |
| U4    | firing a system transition (channel) or creating a C' case | yes     |
| U5    | only holding a caseRef to C'                               | yes     |
| U6    | only embedding a C' form by one taskRef                    | yes     |

\* U2 is tolerable only when C' has no variable arc, because a foreign write to
an arc-weight field changes which transitions are enabled. Under this
discipline each class can be reasoned about alone.

**P5 One owner.** Every piece of knowledge has one owning class. Forms are
shared with taskRef, data through a data-centric class, code through
functions. Two isomorphic net fragments are extracted into their own class
only if they share a change driver and the replacing channels can be atomic;
otherwise they stay copied. Example: the CRUD template is copied into every
data-centric class (different drivers), but the priority form is defined once
and embedded twice.

### Specific to executable process networks

**P6 Class categories.** Every class is exactly one of:

- **Data-centric:** (D1) no variable arc, and the lifecycle behaves like the
  CRUD template: `create` once, `update`/`read` freely, `delete` at least once,
  only system transitions silent; (D2) no outgoing edge in the cause graph (it
  creates, deletes, calls and writes nothing outside itself).
- **Process-centric:** D1 fails, it has an outgoing cause edge, and its own
  fields hold only coordination state; business data stays in referenced
  cases.

A class that fits neither is a modeling error. Size does not decide: a tiny
class that sends one channel is process-centric.

**P7 Case communication.**

- C1: every system transition receives a channel or fires at creation.
- C2: every channel receiver is a system transition; no action fires a user task.
- C3: every action navigates at most one caseRef field (Law of Demeter);
  give the coordinator direct caseRefs to every case it must reach.
- C4: one channel name = one purpose, one receiver per class.
- C5: a process part used more than once with one change driver is its own
  class, not a copied subnet.

**P8 Atomicity.** Every transition:

- A1: is either a system transition, or one user who can supply every
  required field of its form (no form filled by several users in turn);
- A2: can be completed when it becomes enabled (the data exists by then);
- A3: makes all effects of its actions effective together or none. Touching
  no other case: fine. Touching one other case: handle the failed call.
  Touching two or more: not atomic, since Petriflow has no cross-case
  transaction or undo; split it or add compensation steps (saga).

**P9 Role-bounded visibility.** Every case a user can see (tasks they may
execute, fields such forms show) is one they are allowed to see. Roles select
by group only, so users of one role who must not see each other need separate
cases bound to each user at creation. Access resting on users' promises is a
violation.

## Two results to design by

**Prop. 1 (Composition is not enough).** Classes that are each correct can
deadlock together when a variable arc weight does not match runtime facts.
Example: a transition waits for `d` tokens, but only one channel delivers a
token while `d = 2`. Rule: set the weight field from the same value that
determines how many senders exist (e.g. the number of cases created), and give
a skip path with reset arcs.

**Prop. 2 (Limit of one case).** One case offers at most one form per
transition at the same time. If n users must each fill their own form
simultaneously and n is runtime data, use n cases. Atomicity (A1) plus
visibility (P9) together force a per-user class.

The principles pull against each other: P1/P2 want small classes, every cut
costs a channel, P4/P5 limit cuts, and P8/P9 decide where a cut between two
tasks must be a class boundary.

## Patterns (structure only; syntax from the MCP)

- **CRUD template (data-centric lifecycle):** places p1 (1 token), p2, p3, p4.
  `create`: p1 → p2, p3. `update`: loop on p2. `read`: read arc on p3 only.
  `delete`: p2, p3 → p4. Final marking: one token in p4.
- **Channel:** sender action → caseRef field → system transition in receiver.
  Receiver must be enabled whenever the sender can fire.
- **Counter (wait for n answers):** the coordinator creates n per-user cases
  and puts n tokens (variable arc from field `n`) into a counting place; each
  per-user case sends `counter` to a system transition that moves one token;
  the continuing transition consumes n (same field). `skip` empties the
  counting places with reset arcs.
- **Per-user case:** created by the coordinator, bound to its user through a
  user list field; its user task sends a channel back; system transitions
  receive `skip`/`finish` when the round ends.
- **Embedded editing:** a loop transition in the coordinator embeds the
  create/update forms of data-centric cases via taskRef, so one form edits
  several cases.

## Worked example: tutor assignment

Requirement: an associate fixes ~10 session slots; every tutor ranks every
slot privately; an algorithm assigns tutors; the associate corrects; everyone
sees the result. The tutor team changes every semester.

- Flat model: `prio_tutor_1..n` transitions plus auto/manual distribution. It
  must be rebuilt when the team changes, so it fails Prop. 2.
- Decomposition, 10 classes:
    - Process-centric: **Lecture-Process** (semester workflow; loop tasks embed
      CRUD forms; starts a round; waits for `finish`), **Global-Assignment-Process**
      (one round; creates one TAP and one Priority case per tutor/slot; counter
      with variable arc n; skip with reset arcs; auto then manual distribution
      loop; sends `finish` to LP), **Tutor-Assignment-Process** (one tutor, bound
      by user binding; `assign_priority` sends `counter`; revise loop; system
      transitions receive `skip` and `finish`).
    - Data-centric (CRUD template): Semester, Room, Lecture, Contract, Slot,
      Tutor, Priority. The priority form lives in Priority and is embedded by TAP
      and by the manual correction.
- Channels: `counter` (TAP → GAP), `skip` and `finish` (GAP → TAP),
  `finish` (GAP → LP). Creating the GAP case is not a channel.
- Effect: adding a room type touches Room only; replacing the algorithm
  touches one GAP action; letting tutors revise touches TAP only.

## Review checklist

- [ ] Every transition atomic (A1–A3); system transitions really grant no one.
- [ ] Runtime-sized parallel work lives on separate cases (Prop. 2).
- [ ] Per-user privacy enforced by binding, not by promise (P9).
- [ ] Each class has one change driver and a connected access graph (P1, P2).
- [ ] Each class is data-centric or process-centric, not both or neither (P6).
- [ ] Cross-case use only at levels U4–U6; U2 only into classes without variable arcs (P4).
- [ ] Every foreign field/transition used is part of the target's declared interface (P3).
- [ ] C1–C5 hold; every action navigates at most one caseRef.
- [ ] Variable arc weights match the number of cases that send (Prop. 1); a skip path exists.
- [ ] Shared forms defined once and embedded via taskRef (P5).
