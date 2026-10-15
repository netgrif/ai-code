# Petriflow data field types → frontend models → registry keys

Source of truth (verify if the library version differs, NAE 6.x / Angular 17):

- prefixes: `netgrif-components-core/src/lib/data-fields/models/component.ts` (`ComponentPrefixes`,
  `DEFAULT = "default"`)
- model selection: `netgrif-components-core/src/lib/task-content/services/field-converter.service.ts` (`toClass`)
- built-in registrations: `netgrif-components/src/lib/data-fields/data-fields.module.ts` (constructor)
- exports usable from apps: `netgrif-components-core/src/lib/data-fields/public-api.ts`

Registry key = `getTypedComponentType()` = `ComponentPrefixes.X + (component?.name ?? 'default')`.

## Overview table

| Petriflow `type`                            | Model class (`@netgrif/components-core`)                                            | Value type `T`                                             | Prefix (`ComponentPrefixes`)               | Built-in keys registered                                                                                                                                                                                                                            | Recommended base class                                                                                                                      |
|---------------------------------------------|-------------------------------------------------------------------------------------|------------------------------------------------------------|--------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `text`                                      | `TextField` (or `TextAreaField`, see below)                                         | `string`                                                   | `TEXT` = `text-`                           | `text-default`, `text-password`, `text-textarea`, `text-richtextarea`, `text-htmltextarea`, `text-signature`, `text-dashboard_line_chart`, `text-dashboard_pie_chart`, `text-dashboard_bar_chart`, `text-dashboard_iframe`, `text-dashboard_portal` | `AbstractTextErrorsComponent<TextField>`                                                                                                    |
| `number`                                    | `NumberField`                                                                       | `number`                                                   | `NUMBER` = `number-`                       | `number-default`, `number-currency`, `number-decimal`                                                                                                                                                                                               | `AbstractNumberErrorsComponent`                                                                                                             |
| `boolean`                                   | `BooleanField`                                                                      | `boolean`                                                  | `BOOLEAN` = `boolean-`                     | `boolean-default`                                                                                                                                                                                                                                   | `AbstractBaseDataFieldComponent<BooleanField>` or `AbstractBooleanDefaultFieldComponent` (gives `getErrorMessage()` + `createValueLabel()`) |
| `enumeration`, `enumeration_map`            | `EnumerationField` (`DynamicEnumerationField` only for name `autocomplete_dynamic`) | `string` (selected key)                                    | `ENUMERATION` = `enumeration-`             | `enumeration-default`, `-autocomplete`, `-autocomplete_dynamic`, `-list`, `-stepper`, `-icon`, `-caseref`                                                                                                                                           | `AbstractBaseDataFieldComponent<EnumerationField>`                                                                                          |
| `multichoice`, `multichoice_map`            | `MultichoiceField`                                                                  | `Array<string>` (selected keys)                            | `MULTICHOICE` = `multichoice-`             | `multichoice-default`, `-list`, `-caseref`, `-autocomplete`                                                                                                                                                                                         | `AbstractBaseDataFieldComponent<MultichoiceField>`                                                                                          |
| `date`                                      | `DateField`                                                                         | `Moment`                                                   | `DATE` = `date-`                           | `date-default`                                                                                                                                                                                                                                      | `AbstractDateDefaultFieldComponent`                                                                                                         |
| `dateTime`                                  | `DateTimeField`                                                                     | `Moment`                                                   | `DATE_TIME` = `date-time-`                 | `date-time-default`                                                                                                                                                                                                                                 | `AbstractDateTimeDefaultFieldComponent`                                                                                                     |
| `file`                                      | `FileField`                                                                         | `FileFieldValue {file?: File, name?: string}`              | `FILE` = `file-`                           | `file-default`, `file-preview`                                                                                                                                                                                                                      | `AbstractFileDefaultFieldComponent` (upload/download logic) or `AbstractBaseDataFieldComponent<FileField>`                                  |
| `fileList`                                  | `FileListField`                                                                     | `FileListFieldValue {namesPaths?: FileFieldValue[]}`       | `FILE_LIST` = `file-list-`                 | `file-list-default`                                                                                                                                                                                                                                 | `AbstractFileListDefaultFieldComponent` or `AbstractBaseDataFieldComponent<FileListField>`                                                  |
| `user`                                      | `UserField`                                                                         | `UserValue` (`id`, `name`, `surname`, `fullName`, `email`) | `USER` = `user-`                           | `user-default`                                                                                                                                                                                                                                      | `AbstractBaseDataFieldComponent<UserField>` (or `AbstractUserDefaultFieldComponent` to reuse the side‑menu user assign)                     |
| `userList`                                  | `UserListField`                                                                     | `UserListValue` (`userValues: Map<string, UserValue>`)     | `USER_LIST` = `user-list-`                 | `user-list-default`                                                                                                                                                                                                                                 | `AbstractBaseDataFieldComponent<UserListField>`                                                                                             |
| `i18n`                                      | `I18nField`                                                                         | `I18nFieldValue {defaultValue, key?, translations?}`       | `I18N` = `i18n-`                           | `i18n-default`, `i18n-text`, `i18n-divider`                                                                                                                                                                                                         | `AbstractI18nErrorsComponent` (validations) or `AbstractBaseDataFieldComponent<I18nField>` (read-only/divider style)                        |
| `taskRef`                                   | `TaskRefField`                                                                      | `Array<string>` (task ids)                                 | `TASK_REF` = `task-ref-`                   | `task-ref-dashboard`, `task-ref-task-list` (**no `task-ref-default`** — default taskRef is rendered inline by task content, not through the registry)                                                                                               | `AbstractBaseDataFieldComponent<TaskRefField>`                                                                                              |
| `caseRef`                                   | `CaseRefField`                                                                      | `Array<string>` (case ids)                                 | `CASE_REF` = `case-ref-`                   | `case-ref-default`                                                                                                                                                                                                                                  | `AbstractBaseDataFieldComponent<CaseRefField>`                                                                                              |
| `processRef`                                | `ProcessRefField`                                                                   | `Array<string>`                                            | `PROCESS_REF` = `process-ref-`             | `process-ref-default` (registered only in `BuilderComponentModule`)                                                                                                                                                                                 | `AbstractBaseDataFieldComponent<ProcessRefField>`                                                                                           |
| `caseFilter`, `taskFilter`, `processFilter` | `FilterField`                                                                       | `string` (query)                                           | `FILTER` = `filter-`                       | `filter-default`, `filter-filter-tab-view`, `filter-string-query`, `filter-advanced-search-query`                                                                                                                                                   | `AbstractBaseDataFieldComponent<FilterField>`                                                                                               |
| `button`                                    | `ButtonField`                                                                       | `number` (click counter)                                   | `BUTTON` = `button-`                       | `button-default`                                                                                                                                                                                                                                    | `AbstractBaseDataFieldComponent<ButtonField>` or `AbstractButtonDefaultFieldComponent`                                                      |
| `stringCollection`                          | `StringCollectionField`                                                             | `Array<string>`                                            | `STRING_COLLECTION` = `string-collection-` | `string-collection-default`                                                                                                                                                                                                                         | `AbstractBaseDataFieldComponent<StringCollectionField>`                                                                                     |

Note the prefixes for camelCase types: `dateTime` → `date-time-`, `fileList` → `file-list-`, `userList` → `user-list-`,
`taskRef` → `task-ref-`, `caseRef` → `case-ref-`, `processRef` → `process-ref-`, `stringCollection` →
`string-collection-`. The three filter types share `filter-`; `enumeration_map` shares `enumeration-`; `multichoice_map`
shares `multichoice-`.

## Why the "errors" base classes

Several field types have an intermediate abstract class that knows how to turn the FormControl's validation errors into
a message — first the Petriflow-defined `validationMessage` of the matching validation, otherwise a translated default
(`dataField.validations.*` keys). Extending it means the template just does
`<mat-error *ngIf="dataField.isInvalid(formControlRef)">{{getErrorMessage()}}</mat-error>`.

| Class                                                       | Provides                                                                                                                                                                                                                                                                             | Constructor (in this order)                                                                                                              |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `AbstractTextErrorsComponent<T extends TextField>`          | `protected buildErrorMessage(field, formControlRef)` (required, minLength, maxLength, regex, telNumber, email). **Add your own** `getErrorMessage() { return this.buildErrorMessage(this.dataField, this.formControlRef); }` — that is what `AbstractSimpleTextFieldComponent` does. | `_translate: TranslateService`, portal data                                                                                              |
| `AbstractNumberErrorsComponent` (`<NumberField>`)           | `getErrorMessage()` (required, odd, even, positive, negative, decimal, inrange)                                                                                                                                                                                                      | `_translate: TranslateService`, portal data                                                                                              |
| `AbstractI18nErrorsComponent` (`<I18nField>`)               | `getErrorMessage()` (requiredI18n, translationRequired, translationOnly)                                                                                                                                                                                                             | `languageIconsService: LanguageIconsService`, `_translate: TranslateService`, portal data                                                |
| `AbstractDateDefaultFieldComponent` (`<DateField>`)         | `getErrorMessage()` (required, between, workday, weekend), locale sync of `DateAdapter` with `LanguageService`                                                                                                                                                                       | `_translate`, `_adapter: DateAdapter<any>`, `@Inject(MAT_DATE_LOCALE) _locale: string`, `_languageService: LanguageService`, portal data |
| `AbstractDateTimeDefaultFieldComponent` (`<DateTimeField>`) | same as date                                                                                                                                                                                                                                                                         | `_translate`, `_adapter: NgxMatDateAdapter<any>`, `@Inject(MAT_DATE_LOCALE) _locale`, `_languageService`, portal data                    |
| `AbstractBooleanDefaultFieldComponent` (`<BooleanField>`)   | `getErrorMessage()` (required, requiredTrue), `createValueLabel()`                                                                                                                                                                                                                   | `_translate: TranslateService`, portal data                                                                                              |

`AbstractTimeInstanceFieldComponent` (the real base of date/dateTime) is **not exported** from
`@netgrif/components-core`, so outside the monorepo extend `AbstractDateDefaultFieldComponent` /
`AbstractDateTimeDefaultFieldComponent` instead. Likewise `AbstractCaseRefBaseFieldComponent` and
`AbstractFileFieldDefaultComponent` are internal — outside the monorepo use `AbstractBaseDataFieldComponent<…>` or the
exported default abstracts.

For enumeration / multichoice / user / … there is no errors class; write a small `getErrorMessage()`. Every branch must
end in a non-empty text — custom Petriflow `validationMessage` if present, otherwise a translated default — never `''`
for an error that is actually set. Existing translation keys (core `assets/i18n/*.json`, `dataField.validations.*`):
`required`, `requiredTrue`, `enumeration` ("One of the options must be selected" — the default for enumeration
`wrongValue`, as in `AbstractEnumerationAutocompleteSelectFieldComponent`), `minLength`, `maxLength`, `pattern`,
`email`, `phone`, `odd`, `even`, `positive`, `negative`, `decimal`, `inrange`, `datePast`, `dateFuture`, `dateRange`,
`workday`, `weekend`, `requiredI18n`, `translationRequired`, `translationOnly`. Enumeration example:

```ts
public getErrorMessage(): string {
    if (this.formControlRef.hasError(EnumerationFieldValidation.REQUIRED)) {
        return this._translate.instant('dataField.validations.required');
    }
    if (this.formControlRef.hasError(EnumerationFieldValidation.WRONG_VALUE)) {
        const custom = this.dataField.validations?.find(v => v.validationRule.includes(EnumerationFieldValidation.WRONG_VALUE))?.validationMessage;
        return custom || this._translate.instant('dataField.validations.enumeration');
    }
    return '';
}
```

## Type-specific gotchas

- **text**: `FieldConverterService` creates `TextAreaField` only when `component.name` is one of `richtextarea`,
  `htmltextarea`, `editor`, `htmlEditor`; any custom name (e.g. `my_editor`) gives a plain `TextField`. Type your
  component with `TextField` unless you are re-registering one of those names. `password` gets special encoding of its
  value (base64) in the converter.
- **number**: the converter always sets a component (`{name:'default'}` if none). `NumberField._formatFilter` holds
  `formatFilter` from the model (currency/locale formatting) — see `NumberCurrencyFieldComponent` for formatting
  examples.
- **enumeration / multichoice**: options are in `dataField.choices: Array<{key, value}>`; the field value is the key
  (enumeration) or array of keys (multichoice). Choices can change at runtime from backend actions — subscribe to
  `dataField.updatedChoices` (Observable<void>) if you cache/derive anything from them. `dataField.fieldType` tells
  `enumeration` vs `enumeration_map`. `updateOn` strategy is `change`, so every `setValue` is sent to backend.
- **boolean**: `updateOn` is `change`.
- **button**: `ButtonField.getTypedComponentType()` always returns `button-default`, ignoring `component.name`. A new
  button look must either branch on `dataField.getComponentType()` inside a component that **re-registers
  `button-default`** (that's how `fab`/`minifab`/`icon` work in `AbstractButtonDefaultFieldComponent`), or the model
  would need changing. The value is a counter: a click is `formControlRef.setValue(this.dataField.value + 1)`.
- **date / dateTime**: value is a `moment` `Moment`. Use the material/ngx-mat date adapters (the components module
  provides `{provide: DateAdapter, useClass: CustomDateAdapter}`; provide it in your module too if you use
  `mat-datepicker`).
- **file / fileList**: upload/download goes through `TaskResourceService`/`FileFieldService`, not through the
  FormControl. Building one from `AbstractBaseDataFieldComponent` means re‑implementing that; prefer extending
  `AbstractFileDefaultFieldComponent`/`AbstractFileListDefaultFieldComponent` and only changing the template.
- **taskRef**: `AbstractTaskContentComponent.shouldResolveTaskRefData()` decides whether the referenced tasks' data are
  merged inline into the task form: always when the field has no `<component>`, and when it has one only if the
  component property `resolve_data="true"`. So a taskRef with `<component><name>my_view</name></component>` (without
  `resolve_data`) is **not** inlined and is rendered through the registry as `task-ref-my_view` — your component gets
  the task ids as value and must load/show them itself (see `TaskRefListFieldComponent`). `dashboard` has additional
  special handling in task content.
- **file / fileList / anything needing the task id**: the task id is not on the model; read it from the portal data:
  `dataFieldPortalData.additionalFieldProperties.taskId` (set by the field-component-resolver).
- **i18n**: `divider` / `plainText` property affect row height in the field-component-resolver (`isCustomHeight`).
- **processRef**: only registered by the builder module; a consumer app needs its own registration even for
  `process-ref-default`.
