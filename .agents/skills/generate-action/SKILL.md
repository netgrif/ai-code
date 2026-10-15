---
name: generate-action
description: Writes and validates Petriflow actions, the Groovy code that runs on process events, using the Petriflow Action API. Use when writing or changing an action inside a specific process XML, e.g. "compute the total when the price changes", "create a case when this task finishes", "hide a field after approval", or any reaction to data set/get or task assign/finish/cancel/delegate events. Not for designing a new process or its net (use generate-process).
compatibility: Requires the petriflow-mcp MCP server (http://localhost:3000/mcp).
metadata:
  tested: false
  mcp-server: petriflow-mcp
  version: 0.3.0
---

# Generate Petriflow Action

## Overview

An action is an `<action id="...">` element inside `<actions phase="pre|post">`
of an `<event>`. It has two parts:

1. **Mappings:** local variables bound to process elements, e.g.
   `name: f.name, greeting: f.greeting, edit: t.edit_limit;`
   (`f.<fieldId>` data field, `t.<transitionId>` transition, `f.this` the field
   the event belongs to).
2. **Groovy code** run with `ActionDelegate` as delegate, so Petriflow Action
   API methods are available directly.

Always generate an action in the context of its target process XML.

## Steps

1. **Context:** read the target process XML. Note the ids of data fields,
   transitions and roles, the event the action belongs to, and existing action
   ids. If there is no process yet, use the `generate-process` skill first.
2. **Version:** use the latest Petriflow version from `petriflow://versions`
   (or `list_versions`), unless the user or project pins another.
3. **API lookup:** list methods with `petriflow://versions/{version}/actions`
   (or tool `list_actions`). For parameters and examples of the chosen method
   read `petriflow://versions/{version}/actions/{name}` (or `get_action`).
   Never write API signatures from memory. The MCP is authoritative; the docs
   in References are supplementary and may lag behind or contain typos.
4. **Placement:** choose the event and phase (`pre` or `post`) that match the
   desired behavior. If unclear, ask.
5. **Write the action:**
    - Map only fields and transitions that the code uses, and check every id
      exists in the process XML.
    - Refer to other processes (e.g. when creating or finding cases) by their
      full id `<app_name>/<process_name>`, as declared in their XML under
      `processes/`. Check that the id exists; it may belong to another
      application.
    - Prefer Action API methods over hand-written Groovy.
    - Keep it small. One concern per action; several `<action>` elements in one
      `<actions>` run in document order, so split logic across them.
    - Code that is long or reused across actions goes into a function defined
      per the Petriflow schema (fetch the schema from the Petriflow MCP; don't
      invent the syntax).
    - Logic that is a whole service (e.g. OCR of a document) is a module: use the
      `write-module` skill, then call it from the action as
      `Module.<group>.<serviceBeanName>.<method>(args)`.
6. **Insert:** put the code in CDATA with a unique `id` (`actionN`, as in the
   process). If the user asked only for code, return the XML snippet and its
   location instead of editing the file.
7. **Validate the process:** run Stage 1 of the `test-process` skill (`validate_process`). It also validates every
   action in the process, so
   fix anything reported for other actions that your change touches.

## Hard constraints

Never use Grape (`@Grab`), meta-classes (`metaClass`, `ExpandoMetaClass`) or
other reflection programming.

## Example

Event `set` on field `name`, filling `greeting`:

```xml

<event type="set">
    <id>name_set</id>
    <actions phase="post">
        <action id="action1">
            <![CDATA[
            name: f.name,
            greeting: f.greeting;
            change greeting value { "Hello **${name.value}**! How are you?" }
            ]]>
        </action>
    </actions>
</event>
```

## References

Per-method docs with examples (one file each, e.g. `change`, `make`, `setData`,
`createCase`, `findCase`, `finishTask`):
https://github.com/petriflow/petriflow/tree/main/docs/actions
Use them for extra examples; follow the MCP when they disagree.

## Troubleshooting

**Petriflow MCP does not answer.**
Cause: server not configured for this harness, or unreachable.
Solution: tell the user and stop. Do not write Action API calls from memory.

**The needed method is not in `list_actions`.**
Cause: it does not exist in this Petriflow version.
Solution: do not invent it. Combine listed methods, move the logic into a
function, or, for a whole service, use the `write-module` skill.

## Output

The action XML, where it was placed (event, phase), a one-line description of
what it does, the API methods used, and the validation results.

## Common mistakes

- Writing API method names or parameters from memory.
- Mapping fields the code does not use, or ids that don't exist in the process.
- Referring to another process by its short name instead of the full
  `<app_name>/<process_name>` id.
- Duplicate action ids.
- One long action instead of several short ones or a function.
- Raw Groovy that reimplements an Action API method.
- Service-sized logic inside an action instead of a module.
- Wrong phase (`pre` vs `post`).
- Always returning a new value from `change ... value`: return `unchanged`
  when nothing changes, otherwise set-event actions on that field fire again.
