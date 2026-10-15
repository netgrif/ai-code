# Code templates

Placeholders: `<Type>` model class (e.g. `TextField`), `<type>` folder prefix (e.g. `text`), `<name>` Petriflow
component name (e.g. `color_picker`), `<Name>` PascalCase (e.g. `ColorPicker`), `<prefix>` `ComponentPrefixes` member
(e.g. `TEXT`).

Match the surrounding code style: 4-space indentation, single quotes in new files, `protected` underscore-prefixed
injected services (`_translate`), `@Optional() @Inject(DATA_FIELD_PORTAL_DATA)` as the last constructor parameter.

## Contents

- A. Consumer app (component lives in an application using `@netgrif/components`)
- B. Inside the monorepo (core abstract + components concrete)
- C. Specs
- D. Overriding a built-in component

---

## A. Consumer app

Files: `src/app/data-fields/<name>-field/<name>-field.component.{ts,html,scss}` + a module (new `CustomDataFieldsModule`
or an existing app module).

### Component — generic field (`AbstractBaseDataFieldComponent`)

```ts
import {Component, Inject, OnDestroy, OnInit, Optional} from '@angular/core';
import {
    AbstractBaseDataFieldComponent,
    DATA_FIELD_PORTAL_DATA,
    DataFieldPortalData,
    EnumerationField,
    EnumerationFieldValidation
} from '@netgrif/components-core';
import {TranslateService} from '@ngx-translate/core';
import {Subscription} from 'rxjs';

@Component({
    selector: 'app-enumeration-<name>-field',
    templateUrl: './enumeration-<name>-field.component.html',
    styleUrls: ['./enumeration-<name>-field.component.scss']
})
export class Enumeration<Name>FieldComponent extends AbstractBaseDataFieldComponent<EnumerationField>
    implements OnInit, OnDestroy {

    protected _choicesSub: Subscription;

    constructor(protected _translate: TranslateService,
                @Optional() @Inject(DATA_FIELD_PORTAL_DATA) dataFieldPortalData: DataFieldPortalData<EnumerationField>) {
        super(dataFieldPortalData);
    }

    // subscriptions in ngOnInit: with @Input() usage dataField isn't set yet in the constructor
    ngOnInit(): void {
        this._choicesSub = this.dataField.updatedChoices.subscribe(() => {
            /* recompute derived state */
        });
    }

    get columns(): number {
        return this.checkPropertyInComponent('columns') ? parseInt(this.dataField.component.properties.columns, 10) : 2;
    }

    // tiles aren't a text input -> no [formControl] binding; commit with setValue (immediate, ignores updateOn)
    select(key: string): void {
        if (this.formControlRef.disabled) {
            return;
        }
        this.formControlRef.setValue(key);
        this.formControlRef.markAsTouched();
    }

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

    ngOnDestroy(): void {
        super.ngOnDestroy();
        this._choicesSub?.unsubscribe();
    }
}
```

Template — disabled through the element itself (keyboard too), not only CSS:

```html
<div class="tiles" role="radiogroup" [style.grid-template-columns]="'repeat(' + columns + ', minmax(0, 1fr))'">
    <mat-card *ngFor="let choice of dataField.choices"
              role="radio"
              [attr.aria-checked]="formControlRef.value === choice.key"
              [attr.aria-disabled]="formControlRef.disabled"
              [attr.tabindex]="formControlRef.disabled ? -1 : 0"
              [class.selected]="formControlRef.value === choice.key"
              (click)="select(choice.key)"
              (keydown.enter)="select(choice.key)">
        {{choice.value}}
    </mat-card>
</div>
<mat-hint *ngIf="hasHint() && !dataField.isInvalid(formControlRef)">{{dataField.description}}</mat-hint>
<mat-error *ngIf="dataField.isInvalid(formControlRef)">{{getErrorMessage()}}</mat-error>
```

### Component — field with an errors class (text example)

```ts
import {Component, Inject, Optional} from '@angular/core';
import {
    AbstractTextErrorsComponent,
    DATA_FIELD_PORTAL_DATA,
    DataFieldPortalData,
    TextField
} from '@netgrif/components-core';
import {TranslateService} from '@ngx-translate/core';

@Component({
    selector: 'app-text-<name>-field',
    templateUrl: './text-<name>-field.component.html',
    styleUrls: ['./text-<name>-field.component.scss']
})
export class Text<Name>FieldComponent extends AbstractTextErrorsComponent<TextField> {

    constructor(_translate: TranslateService,
                @Optional() @Inject(DATA_FIELD_PORTAL_DATA) dataFieldPortalData: DataFieldPortalData<TextField>) {
        super(_translate, dataFieldPortalData);
    }

    public getErrorMessage(): string {
        return this.buildErrorMessage(this.dataField, this.formControlRef);
    }
}
```

Number: `extends AbstractNumberErrorsComponent`, `super(_translate, dataFieldPortalData)`, `getErrorMessage()` inherited.
I18n: `extends AbstractI18nErrorsComponent`, `super(languageIconsService, _translate, dataFieldPortalData)`.
Date: `extends AbstractDateDefaultFieldComponent`,
`super(_translate, _adapter, _locale, _languageService, dataFieldPortalData)` with `_adapter: DateAdapter<any>`,
`@Inject(MAT_DATE_LOCALE) _locale: string`, `_languageService: LanguageService`.

### Module + registration

```ts
import {Injector, NgModule} from '@angular/core';
import {CommonModule} from '@angular/common';
import {ReactiveFormsModule} from '@angular/forms';
import {ComponentPortal} from '@angular/cdk/portal';
import {FlexLayoutModule} from '@ngbracket/ngx-layout';
import {
    ComponentPrefixes,
    ComponentRegistryService,
    MaterialModule,
    TranslateLibModule
} from '@netgrif/components-core';
import {Text<Name>FieldComponent} from './text-<name>-field/text-<name>-field.component';

@NgModule({
    declarations: [Text<Name>FieldComponent],
    imports: [CommonModule, ReactiveFormsModule, FlexLayoutModule, MaterialModule, TranslateLibModule]
})
export class CustomDataFieldsModule {
    constructor(registry: ComponentRegistryService) {
        registry.register(ComponentPrefixes.TEXT + '<name>',
            (injector: Injector) => new ComponentPortal<any>(Text<Name>FieldComponent, null, injector));
    }
}
```

Then add `CustomDataFieldsModule` to `imports` of `AppModule` **after** `DataFieldsComponentModule` (or into any eagerly
imported module). The NgModule constructor only runs if the module is instantiated, i.e. imported into the app's module
tree — a lazily loaded module registers only once its route is loaded.

Alternatively register directly in the `AppModule` constructor (in this project
`nae/nae-frontend/src/app/app.module.ts`), next to any existing `registry.register(...)` calls.

### Petriflow usage to give the user

```xml
<data type="text">
    <id>my_field</id>
    <title>My field</title>
    <component>
        <name>my_component</name>
        <property key="someProperty">value</property>
    </component>
</data>
```

Replace `my_component` with the `<name>` used in the registry key.

(The Petriflow XSD (`https://petriflow.com/petriflow.schema.xsd`) also accepts
`<properties><property key="…">…</property></properties>`, but the flat `<property>` form inside `<component>` is the
one used in practice.)

---

## B. Inside the monorepo

Follow the existing split — logic in core, view in components.

### 1. Core abstract —
`projects/netgrif-components-core/src/lib/data-fields/<type>-field/<name>-field/abstract-<name>-field.component.ts`

```ts
import {Component, Inject, Optional} from '@angular/core';
import {TranslateService} from '@ngx-translate/core';
import {AbstractTextErrorsComponent} from '../abstract-text-errors.component';
import {TextField} from '../models/text-field';
import {DATA_FIELD_PORTAL_DATA, DataFieldPortalData} from '../../models/data-field-portal-data-injection-token';

@Component({
    selector: 'ncc-abstract-<name>-field',
    template: ''
})
export abstract class Abstract<Name>FieldComponent extends AbstractTextErrorsComponent<TextField> {

    constructor(protected _translate: TranslateService,
                @Optional() @Inject(DATA_FIELD_PORTAL_DATA) dataFieldPortalData: DataFieldPortalData<TextField>) {
        super(_translate, dataFieldPortalData);
    }

    public getErrorMessage(): string {
        return this.buildErrorMessage(this.dataField, this.formControlRef);
    }
}
```

Inside core use **relative imports**, never `@netgrif/components-core`.
Export it: add `export * from './<type>-field/<name>-field/abstract-<name>-field.component';` to
`projects/netgrif-components-core/src/lib/data-fields/public-api.ts` near the other exports of that field type.
If the component name should be known in code, add it to the field's enum (e.g. `TextFieldComponent` in
`text-field/models/text-field.ts`).

### 2. Concrete —
`projects/netgrif-components/src/lib/data-fields/<type>-field/<name>-field/<name>-field.component.{ts,html,scss,spec.ts}`

```ts
import {Component, Inject, Optional} from '@angular/core';
import {
    Abstract<Name>FieldComponent,
    DATA_FIELD_PORTAL_DATA,
    DataFieldPortalData,
    TextField
} from '@netgrif/components-core';
import {TranslateService} from '@ngx-translate/core';

@Component({
    selector: 'nc-<name>-field',
    templateUrl: './<name>-field.component.html',
    styleUrls: ['./<name>-field.component.scss']
})
export class <Name>FieldComponent extends Abstract<Name>FieldComponent {

    constructor(_translate: TranslateService,
                @Optional() @Inject(DATA_FIELD_PORTAL_DATA) dataFieldPortalData: DataFieldPortalData<TextField>) {
        super(_translate, dataFieldPortalData);
    }
}
```

### 3. `projects/netgrif-components/src/lib/data-fields/data-fields.module.ts`

- import the component,
- add it to `declarations`,
- add the registration line into the constructor, grouped with the same field type, same formatting as the others:

```ts
registry.register("text-<name>", (injector: Injector) => new ComponentPortal<any>(<Name>FieldComponent, null, injector));
```

- if the template needs a module that isn't imported yet, add it to `imports`.

No change is needed in `netgrif-components/src/lib/data-fields/public-api.ts` (it exports only the module and the
template component).

### 4. Builder (optional)

If the component should be selectable in the form builder / modeler, check how component definitions are listed there
(`netgrif-components/src/lib/builder/…`, `edit-panel.component.ts`, `data-detail.component.ts` look up component
definitions with `properties`) and add the new one.

---

## C. Specs

Concrete component spec (monorepo) — wrap the component and give it model + FormControl through inputs:

```ts
describe('<Name>FieldComponent', () => {
    let component: <Name>FieldComponent;
    let fixture: ComponentFixture<TestWrapperComponent>;

    beforeEach(waitForAsync(() => {
        TestBed.configureTestingModule({
            imports: [MaterialModule, AngularResizeEventModule, TranslateLibModule, HttpClientTestingModule, NoopAnimationsModule],
            providers: [
                {provide: AuthenticationMethodService, useClass: MockAuthenticationMethodService},
                {provide: AuthenticationService, useClass: MockAuthenticationService},
                {provide: UserResourceService, useClass: MockUserResourceService},
                {provide: ConfigurationService, useClass: TestConfigurationService}
            ],
            declarations: [<Name>FieldComponent, TestWrapperComponent],
            schemas: [CUSTOM_ELEMENTS_SCHEMA]
        }).compileComponents();
        fixture = TestBed.createComponent(TestWrapperComponent);
        component = fixture.debugElement.children[0].componentInstance;
        fixture.detectChanges();
    }));

    it('should create', () => {
        expect(component).toBeTruthy();
    });

    afterEach(() => {
        TestBed.resetTestingModule();
    });
});

@Component({
    selector: 'nc-test-wrapper',
    template: '<nc-<name>-field [dataField]="field" [formControlRef]="formControl" [showLargeLayout]="label"></nc-<name>-field>'
})
class TestWrapperComponent {
    label = new WrappedBoolean();
    field = new TextField('', '', 'value', {optional: true, visible: true, editable: true, hidden: true});
    formControl = new FormControl();

    constructor() {
        this.field.registerFormControl(this.formControl);
    }
}
```

Core abstract spec: declare a tiny `TestXComponent extends Abstract<Name>FieldComponent` with `template: ''` and provide
`DATA_FIELD_PORTAL_DATA` via
`useValue: {dataField, formControlRef: new FormControl(), showLargeLayout: new WrappedBoolean()}` (see
`abstract-simple-text-field.component.spec.ts`). Test the logic (property parsing, error messages, value conversion).

---

## D. Overriding a built-in component

To change how e.g. every plain text field looks in one application, register your component under the existing key from
a module that is constructed **after** `DataFieldsComponentModule`:

```ts
registry.register('text-default', (injector: Injector) => new ComponentPortal<any>(MyTextFieldComponent, null, injector));
```

`ComponentRegistryService` is a `Map`; the last registration wins. Button can only be overridden this way
(`button-default`).
