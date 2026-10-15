# What a data field component can use and control

Everything here is available on a component extending `AbstractBaseDataFieldComponent<T>` (directly or via an errors
class).

## Contents

1. Inputs set by the base class
2. Controlling the value (FormControl ↔ DataField binding)
3. Behavior (required / editable / visible / hidden)
4. Component name and properties from Petriflow
5. Validations
6. Layout / appearance / title / hint / placeholder
7. Portal data and extra context (task id)
8. Lifecycle and subscriptions
9. Template skeleton

---

## 1. Inputs set by the base class

| Member                          | Type                                 | Meaning                                                                                                              |
|---------------------------------|--------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| `dataField`                     | `T` (model class)                    | the field model — value, behavior, component, validations, layout, title…                                            |
| `formControlRef`                | `FormControl`                        | Angular form control bound to the field. **The only thing the template should bind to.**                             |
| `showLargeLayout`               | `WrappedBoolean` (`.value: boolean`) | `true` → the template wrapper already prints the title on the left half; the component must not render its own label |
| `checkPropertyInComponent(key)` | `boolean`                            | `true` if `dataField.component.properties` has `key`                                                                 |
| `hasTitle()`, `hasHint()`       | `boolean`                            | title / description is non-empty                                                                                     |

They are also `@Input()`s, so the component can be used directly in a template (that's how specs test it).

## 2. Controlling the value

`dataField.registerFormControl(fc)` wires two subscriptions:

- `formControlRef.valueChanges` → `dataField.value = newValue` (marks the field `changed`, `TaskDataService` then sends
  it to the backend via `setData`, respecting `valid` / `sendInvalidValues`),
- `dataField.valueChanges()` → `formControlRef.setValue(newValue)` (backend changes from actions show up in the UI).

So:

| Want to…                                               | Do                                                                                                   |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| read current value                                     | `formControlRef.value` (or `dataField.value`)                                                        |
| set value from UI code (click, custom widget, canvas…) | `formControlRef.setValue(v)`; also `formControlRef.markAsTouched()` so errors show                   |
| bind a material/native input                           | `[formControl]="formControlRef"`                                                                     |
| react to value changes (incl. from backend)            | `dataField.valueChanges().subscribe(...)` or `formControlRef.valueChanges` — remember to unsubscribe |
| set value without marking as changed (no backend call) | `dataField.valueWithoutChange(v)` — rarely needed                                                    |
| focus the field programmatically                       | assign `dataField.input = elementRef` (`@ViewChild`) and call `dataField.focus()`                    |
| know if a backend round-trip is running                | `dataField.waitingForResponse`                                                                       |

Don't keep the value in a private property and write it to `dataField.value` behind the FormControl's back — validation
state and `changed` flags are derived from the FormControl. If the widget needs a different representation (e.g. comma
separated string ↔ array), convert in both directions, but `setValue` the model value.

### `updateOn` and the setValue rule

The FormControl is created by `field-component-resolver` as
`new FormControl('', {updateOn: dataField.getUpdateOnStrategy()})` — **`blur` for every type except boolean /
enumeration / multichoice (`change`)**. With `blur`, a value coming from a `[formControl]`-bound control reaches the
FormControl (→ `dataField.value` → backend) only when that element loses focus. That's right for text inputs (one
backend call per edit) but wrong for widgets the user doesn't "leave": slider, calendar, tiles, toggle groups, color
pickers, canvas, drag & drop… The value then stays uncommitted (and anything displaying `formControlRef.value` lags)
until some blur happens — or never.

**Rule:** bind `[formControl]="formControlRef"` only to text-like inputs (`matInput`, `textarea`, `mat-select` on
`change` types). For any other widget, don't bind `[formControl]`; listen to the widget's commit event and call:

```ts
commit(value: T): void {
    if (this.formControlRef.disabled) {
        return;
    }
    this.formControlRef.setValue(value);   // programmatic setValue ignores updateOn → propagates immediately
    this.formControlRef.markAsTouched();
}
```

- Pick the event that means "user finished": slider → `(dragEnd)` / thumb `(change)`, not every `(input)` tick (each
  `setValue` that changes the value triggers a backend `setData`); calendar → `(selectedChange)`; tile → `(click)`.
- For live preview during interaction keep a local display value, but treat `formControlRef.value` as the truth and
  re-sync the local value from `dataField.valueChanges()` (backend actions can change it).
- Disabled state then has to be applied manually — **on the widget itself, not just visually**. A CSS
  `pointer-events: none` / opacity wrapper only stops the mouse; keyboard (Tab, arrows, Enter) still works. Do both:
    1. disable the widget through its own API — `mat-slider [disabled]="formControlRef.disabled"`;
       `mat-calendar [dateFilter]="dateFilter"` with a filter that returns `false` for every date while
       `formControlRef.disabled` (make it an arrow-function property or getter that reads `formControlRef.disabled` at
       call time, and pass `[dateFilter]` so the calendar re-evaluates); `mat-button-toggle-group [disabled]`; own
       tiles/buttons → `[attr.aria-disabled]`, `tabindex="-1"`, no `(keydown)` handling;
    2. guard the commit handler (`if (this.formControlRef.disabled) return;`).
       The disabled state changes at runtime (behavior changes from actions), so bind it in the template, don't compute
       it once.
- Don't change `getUpdateOnStrategy()` of the model just for one component — it affects all components of that type.

## 3. Behavior

`dataField.behavior: Behavior` — `{ required?, optional?, visible?, editable?, hidden?, forbidden? }`.

| Behavior                           | Who handles it                                                                                                                 | What the component should do                                                                                                                                                                                                                                                                                                                                                |
|------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `hidden`                           | `field-component-resolver` doesn't render the field at all                                                                     | nothing                                                                                                                                                                                                                                                                                                                                                                     |
| `visible` (read-only) / `editable` | `DataField` calls `formControlRef.disable()` / `.enable()` on every `update()` (`dataField.disabled === visible && !editable`) | material inputs follow automatically; custom interactive UI must check `formControlRef.disabled` (e.g. `[disabled]="formControlRef.disabled"`, early return in click handlers, `[ngClass]="{'netgrif-label-disabled': formControlRef.disabled}"`)                                                                                                                           |
| `required`                         | `Validators.required` is added to the FormControl                                                                              | show the marker: `[required]="dataField.behavior.required"` on matInput, or `<nc-required-label *ngIf="dataField.behavior.required" [isIn]="true">` (only inside the components library — `RequiredLabelComponent` is neither exported from the package nor from `DataFieldsComponentModule`, so in an app render your own marker, e.g. `<span class="required"> *</span>`) |

Behavior can change at runtime (actions); `applyChange` → `update()` re-applies it. Template bindings to
`dataField.behavior.*` / `formControlRef.disabled` stay correct automatically. If you cache anything derived from
behavior, recompute it in an `update` handler or a getter, not once in the constructor.

Other flags: `dataField.valid`, `dataField.validRequired`, `dataField.changed`, `dataField.initialized` /
`initialized$`, `dataField.block = true/false` (temporarily disable, e.g. during an upload), `dataField.touch = true`
(mark touched).

## 4. Component name and properties

```xml
<component>
    <name>my_widget</name>
    <property key="color">red</property>
    <property key="rows">5</property>
    <property key="readonlyLabel">true</property>
</component>
```

- `dataField.component?.name` / `dataField.getComponentType()` (`'default'` if none) — one component can serve several
  names (registered twice) and branch on it.
- `dataField.component?.properties` — `{[key: string]: any}`; values come as **strings** from the XML → parse:
  `=== 'true'`, `parseInt`, `JSON.parse` for structured values.
- `dataField.component?.optionIcons` — `Array<{key, type: 'material'|'svg', value}>` (used by `enumeration-icon`).
- Pattern used across the codebase:

```ts
get rows(): number {
    return this.checkPropertyInComponent('rows') ? parseInt(this.dataField.component.properties.rows, 10) : 3;
}

get readonlyLabel(): boolean {
    return this.checkPropertyInComponent('readonlyLabel') && this.dataField.component.properties.readonlyLabel === 'true';
}
```

Always provide a default — the property may be missing. Document every property the component reads.
`dataField.componentChange$()` emits when the component is replaced at runtime (the template wrapper does **not**
re-resolve the registry portal, so only properties change meaningfully).

## 5. Validations

- `dataField.validations: Array<{validationRule: string, validationMessage: string}>` — raw Petriflow rules, e.g.
  `'minLength 5'`, `'regex ^[0-9]*$'`, `'inrange 1,10'`, `'between today,future'`.
- The model turns them into Angular validators (`resolveValidations()` in each model), so errors appear on
  `formControlRef.errors` / `formControlRef.hasError('minlength')`.
- `dataField.isInvalid(formControlRef)` → `!disabled && !valid && touched` — the standard condition for showing
  `<mat-error>`.
- `getErrorMessage()` from the errors base classes returns the custom `validationMessage` or translated default.
  Validation key enums: `TextFieldValidation`, `NumberFieldValidation`, `BooleanFieldValidation`,
  `EnumerationFieldValidation`, `AbstractTimeInstanceFieldValidation`, `I18nFieldValidation`, `FileListFieldValidation`,
  `ButtonFieldValidation`, `FilterFieldValidation`.
- Custom validators only for the new component: better put them into the model (`resolveValidations`) — the
  FormControl's validators are reset by the DataField on every `update()`, so validators added from the component would
  be lost.

## 6. Layout / appearance / texts

| Member                                   | Use                                                                                                        |
|------------------------------------------|------------------------------------------------------------------------------------------------------------|
| `dataField.title`                        | label (`<mat-label *ngIf="!showLargeLayout.value">`)                                                       |
| `dataField.description`                  | hint / tooltip (`<mat-hint [ngClass]="{'mat-hint-disabled': formControlRef.disabled}">`)                   |
| `dataField.placeholder`                  | placeholder                                                                                                |
| `dataField.materialAppearance`           | `'outline'`, `'fill'`, … → `<mat-form-field [appearance]="dataField.materialAppearance">` (resolved from layout or app config before the component is created) |
| `dataField.layout` / `localLayout`       | grid position (`x, y, cols, rows`), `template` (`material`/`netgrif`), `appearance`, `offset`, `alignment` |
| `dataField.stringId`                     | field id (use for element ids / test ids)                                                                  |
| `dataField.parentTaskId`, `parentCaseId` | set when the field comes from a referenced task (taskRef)                                                  |

Global CSS classes used by existing fields: `full-width`, `netgrif-label`, `netgrif-label-disabled`,
`mat-hint-disabled`, `min-height-62`.

## 7. Portal data and task context

The base class keeps only `dataField`, `formControlRef`, `showLargeLayout`. If you need more, keep a reference in the
constructor:

```ts
constructor(@Optional() @Inject(DATA_FIELD_PORTAL_DATA) protected portalData: DataFieldPortalData<TextField>) {
    super(portalData);
}

get taskId(): string {
    return this.portalData?.additionalFieldProperties?.taskId as string;
}
```

`additionalFieldProperties` from task content = `{taskId, taskContentComponentClassReference}`.
Any service from the app/root injector can be injected normally (`TranslateService`, `TaskResourceService`,
`SnackBarService`, `DialogService`, `LoggerService`, `ConfigurationService`, …) — the portal injector has the template's
injector as parent.

## 8. Lifecycle

- The constructor is where portal data arrives. But the same component can also be created directly with `@Input()`s
  (specs, or embedding `<nc-…-field [dataField] [formControlRef]>` in a template) — then the portal data is `null` and
  `dataField` / `formControlRef` are still `undefined` in the constructor. So **don't subscribe or read `dataField` in
  the constructor**; do it in `ngOnInit`, where both paths have the inputs set:
  ```ts
  ngOnInit(): void {
      this._valueSub = this.dataField.valueChanges().subscribe(v => this.syncFromValue(v));
  }
  ngOnDestroy(): void {
      super.ngOnDestroy();
      this._valueSub?.unsubscribe();
  }
  ```
  (Use `?.` on unsubscribe — `ngOnInit` may not have run if creation failed.)
- `ngOnDestroy` in the base disconnects the FormControl. Override as:
  ```ts
  ngOnDestroy(): void {
      super.ngOnDestroy();
      this._subs.unsubscribe();
  }
  ```
- Components are re-created when the task content re-renders (e.g. layout change), so never assume a single instance per
  field.

## 9. Template skeleton (material input style)

```html
<mat-form-field [appearance]="dataField.materialAppearance" class="full-width" color="primary">
    <mat-label *ngIf="!showLargeLayout.value">{{dataField.title}}</mat-label>
    <input matInput
           [placeholder]="dataField.placeholder"
           [required]="dataField.behavior.required"
           [formControl]="formControlRef">
    <mat-hint [ngClass]="{'mat-hint-disabled': formControlRef.disabled}">{{dataField.description}}</mat-hint>
    <mat-error *ngIf="dataField.isInvalid(formControlRef)">{{getErrorMessage()}}</mat-error>
</mat-form-field>
```

Non-form-field style (custom widget):

```html
<div fxLayout="column" class="min-height-62">
    <mat-label class="netgrif-label" [ngClass]="{'netgrif-label-disabled': formControlRef.disabled}"
               *ngIf="!showLargeLayout.value && hasTitle()">{{dataField.title}}<span
            *ngIf="dataField.behavior.required"> *</span></mat-label>
    <!-- custom widget: read formControlRef.value, write formControlRef.setValue(), respect formControlRef.disabled -->
    <mat-hint [ngClass]="{'mat-hint-disabled': formControlRef.disabled}" *ngIf="!dataField.isInvalid(formControlRef)">
        {{dataField.description}}
    </mat-hint>
    <mat-error *ngIf="dataField.isInvalid(formControlRef)">{{getErrorMessage()}}</mat-error>
</div>
```
