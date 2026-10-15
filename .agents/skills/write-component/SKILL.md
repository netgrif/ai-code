---
name: write-component
description: Creates custom Angular components for Petriflow/NAE data fields with @netgrif/components and @netgrif/components-core, and registers them in ComponentRegistryService so that a data field whose Petriflow component name matches renders with them. Use when the user wants a new, custom or alternative look or behaviour for a data field (text, number, enumeration, date, file, taskRef and other types), a custom datafield renderer, or to override a default component such as text-default, or mentions AbstractBaseDataFieldComponent, DATA_FIELD_PORTAL_DATA or ComponentRegistryService. Not for process logic (use generate-process).
compatibility: Requires Node.js 22+ and the Angular frontend in nae/nae-frontend (@netgrif/components 6.5, Angular 17); npm test needs a browser for Karma.
metadata:
  tested: false
  version: 0.2.0
---

# Creating a custom Petriflow data field component (NAE frontend)

A data field in a Petriflow process can declare a frontend component:

```xml
<data type="text">
    <id>signature</id>
    <title>Signature</title>
    <component>
        <name>my_signature</name>
        <property key="penColor">blue</property>
    </component>
</data>
```

At runtime the frontend looks up a component in `ComponentRegistryService` under the key
`dataField.getTypedComponentType()` = **`<type-prefix><component.name>`** (e.g. `text-my_signature`).
If nothing is registered under that key, **the field renders as empty space** — no fallback, no error.
So a new component is useless until it is registered with exactly the right key.

**Only when the library has nothing that fits.** Per `AGENTS.md`, a custom
component is level 3: first check whether process logic or a built-in component
(see the built-in keys in `references/field-types.md`) can do it. If you still
write one, tell the user why the built-in ones are not enough.

## How rendering works (why the rules below exist)

1. `FieldConverterService.toClass()` turns the backend resource into a model class (`TextField`, `NumberField`, …).
   Component name comes from `component.name`, default `"default"`.
2. `field-component-resolver` skips fields whose `behavior.hidden` is true, otherwise renders
   `<nc-data-field-template>`.
3. `AbstractDataFieldTemplateComponent` calls `registry.get(dataField.getTypedComponentType(), injector)`; the injector
   provides `DATA_FIELD_PORTAL_DATA = {dataField, formControlRef, showLargeLayout, additionalFieldProperties}`; the
   result is a `ComponentPortal` attached via `cdkPortalHost`.
4. The component's constructor receives the portal data. `AbstractBaseDataFieldComponent` copies `dataField`,
   `formControlRef`, `showLargeLayout` onto itself and, if the field isn't initialized yet, creates a new `FormControl`
   (with the field's `updateOn` strategy) and calls `dataField.registerFormControl(...)`. From then on the FormControl
   and the DataField are two-way bound.
5. `ngOnDestroy` of the base class calls `dataField.disconnectFormControl()`.

Because of (3) and (4) the component **must** take `@Optional() @Inject(DATA_FIELD_PORTAL_DATA) dataFieldPortalData` in
its constructor and pass it to `super(...)`. Without it nothing is wired.

## Workflow

1. **Identify the field type and component name.** Ask if unclear. The name is what the process author will put into
   `<component><name>`. Use lowercase, `_` for word separation (existing convention: `autocomplete_dynamic`,
   `dashboard_line_chart`).
2. **Look up the field type in `references/field-types.md`** — it gives the model class, value type, registry prefix,
   the recommended base class and the type-specific gotchas (e.g. button always resolves to `button-default`, text
   `TextAreaField` only for some names, date base class not exported). Read it every time — the gotchas are the part
   that silently breaks things.
3. **Figure out where the code goes:**
    - *Inside the components monorepo* (`projects/netgrif-components` + `projects/netgrif-components-core`): abstract
      logic in core (`ncc-` selector, `Abstract…Component`, `template: ''`, exported from core
      `data-fields/public-api.ts`), concrete component in
      `netgrif-components/src/lib/data-fields/<type>-field/<name>-field/` (`nc-` selector), declared and registered in
      `DataFieldsComponentModule`. Follow the existing core/components split — see `references/templates.md` § "Inside
      the monorepo".
    - *In an application that consumes the libraries* (most common for project-specific components): one concrete
      component that extends a class exported from `@netgrif/components-core`, declared and registered in an app/feature
      NgModule. See `references/templates.md` § "A. Consumer app". Only classes exported from the core public API are
      usable there — the table in `field-types.md` says which.
      **In this project** the consumer app is `nae/nae-frontend` (`@netgrif/components` 6.5.0, Angular 17.3): put the
      component under `nae/nae-frontend/src/app/data-fields/` and import its module in
      `nae/nae-frontend/src/app/app.module.ts`.
4. **Pick the base class** (from the table). Rule of thumb:
    - Field types with validation-error helpers → extend the errors class so `getErrorMessage()` gives the translated
      (or Petriflow-custom) validation message for free: text → `AbstractTextErrorsComponent<TextField>`, number →
      `AbstractNumberErrorsComponent`, i18n → `AbstractI18nErrorsComponent`, date/dateTime →
      `AbstractDateDefaultFieldComponent` / `AbstractDateTimeDefaultFieldComponent`, boolean →
      `AbstractBooleanDefaultFieldComponent` if you want its required/requiredTrue messages.
    - Everything else → `AbstractBaseDataFieldComponent<ModelClass>`.
    - Extending an existing *default* abstract (e.g. `AbstractEnumerationAutocompleteSelectFieldComponent`) is fine when
      the new component is a variation of it and you want its logic.
5. **Write the component** (ts/html/scss, + spec when inside the monorepo). Use the API in
   `references/datafield-api.md`: drive the value through `formControlRef` (`[formControl]` for text inputs, `setValue`
   from the commit event for every other widget — the control is `updateOn: 'blur'` for most types), read behavior from
   `dataField.behavior`, read config from `dataField.component.properties`.
6. **Register it** in the constructor of the NgModule that declares it:
   ```ts
   constructor(registry: ComponentRegistryService) {
       registry.register('text-my_signature',
           (injector: Injector) => new ComponentPortal<any>(MySignatureFieldComponent, null, injector));
   }
   ```
   Key = `ComponentPrefixes.<TYPE>` + component name. Using the enum avoids typos:
   `ComponentPrefixes.TEXT + 'my_signature'`. Pass `injector` through — it carries the portal data.
7. **Make sure the module is actually loaded** — it must be imported (directly or transitively) by the application root
   module, *after* `DataFieldsComponentModule` if you are overriding a built‑in key (registry is a `Map`, last
   `register` wins; module constructors run in import order, imported modules before the importing one).
8. **Tell the user how to use it** in the Petriflow model (`<component><name>…</name>` + properties) and list the
   properties the component reads.
9. **Verify.** In the app (`nae/nae-frontend` in this project) run `npm run lint`, `npm run build` and `npm test`
   (Karma, needs a browser) and read the output. Inside the monorepo run the equivalent lint/build/test of the changed
   projects. If a check cannot run (e.g. no browser for Karma), say so instead of claiming success.

## Checklist before finishing

- [ ] Constructor injects `@Optional() @Inject(DATA_FIELD_PORTAL_DATA)` and passes it to `super` (plus whatever the base
  class needs, in the same order).
- [ ] The value goes through `formControlRef`, never a private copy. `[formControl]` binding only on text-like inputs;
  any other widget (slider, calendar, tiles, picker, canvas…) commits with `formControlRef.setValue(v)` +
  `markAsTouched()` from its "done" event — the FormControl uses `updateOn: 'blur'` for most types, so a `[formControl]`
  -bound non-input widget would commit late or never (see `datafield-api.md` § "updateOn and the setValue rule").
- [ ] Any local display state derived from the value is re-synced on `dataField.valueChanges()` (backend actions change
  values too).
- [ ] Label is shown only when `!showLargeLayout.value` (the large layout already prints the title on the left).
- [ ] Required marker (`dataField.behavior.required`), hint (`dataField.description`), placeholder, error
  (`dataField.isInvalid(formControlRef)` → `getErrorMessage()`) handled where it makes sense.
- [ ] Disabled state comes from `formControlRef.disabled` (set by the framework from `behavior.editable/visible`).
  Widgets not bound via `[formControl]` are disabled through their own API (`[disabled]`, calendar `[dateFilter]`,
  `tabindex=-1` on custom tiles) — CSS `pointer-events` alone leaves keyboard input working — and the commit handler is
  guarded too.
- [ ] No subscriptions / `dataField` access in the constructor — do it in `ngOnInit` (with `@Input()` usage the portal
  data is `null` and inputs aren't set yet in the constructor).
- [ ] `getErrorMessage()` never returns `''` for an error that is set — custom `validationMessage` or a translated
  `dataField.validations.*` default (e.g. `enumeration` for `wrongValue`).
- [ ] If `ngOnDestroy` is overridden, it calls `super.ngOnDestroy()`; own subscriptions are unsubscribed.
- [ ] Component declared in an NgModule that imports what the template needs (`CommonModule`, `ReactiveFormsModule`,
  `MaterialModule`/`TranslateLibModule` from core, `FlexLayoutModule`, …).
- [ ] Registered with key `<prefix><name>`; prefix taken from `ComponentPrefixes`; the module is imported by the app.
- [ ] Inside the monorepo: **two spec files** — `abstract-<name>-field.component.spec.ts` next to the core abstract (a
  tiny `Test…Component extends Abstract…` with `template: ''`, `DATA_FIELD_PORTAL_DATA` provided via `useValue`, testing
  the logic: property parsing/defaults, `getErrorMessage()`, value commit) **and** `<name>-field.component.spec.ts` for
  the concrete component (wrapper with `[dataField]`/`[formControlRef]`/`[showLargeLayout]` inputs). Most core abstracts
  have one (e.g. `abstract-simple-text-field.component.spec.ts`); some older ones don't — don't take those as the
  pattern. See `references/templates.md` § C.
- [ ] Inside the monorepo: the new abstract class is exported from core `data-fields/public-api.ts` (so apps can extend
  it). `netgrif-components/src/lib/data-fields/public-api.ts` exports only the module and the template — concrete
  components don't need to be added there; registration in the module constructor is what makes them usable.

- [ ] `npm run lint`, `npm run build` and `npm test` ran and passed (or the reason they could not run is reported).

## Reference files

- `references/field-types.md` — every field type: Petriflow type → model → value → prefix → existing components → base
  class → gotchas. **Read for every task.**
- `references/datafield-api.md` — what the component has access to (DataField, FormControl, Behavior, component
  properties, validations, layout, portal data) and how to control the field.
- `references/templates.md` — copy‑ready code for the monorepo (core abstract + concrete + spec + registration) and for
  a consumer app.
