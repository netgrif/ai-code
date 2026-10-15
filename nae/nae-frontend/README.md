# Frontend

Angular 17 application for your Netgrif Platform app, built on the
[`@netgrif/components`](https://github.com/netgrif/components) library. It shows cases and tasks of your processes and
handles login, navigation and user profiles. For the overall project, see the [main README](../../README.md).

## Requirements

- Node.js 22 or newer (current LTS recommended) and npm
- A running Application Engine (see [`../README.md`](../README.md))

## Commands

Install dependencies once:

```bash
npm install --legacy-peer-deps
```

| Command         | Purpose                                                            |
|-----------------|--------------------------------------------------------------------|
| `npm start`     | Development server at <http://localhost:4200>                      |
| `npm run build` | Production build into `dist/template-frontend`                     |
| `npm test`      | Unit tests with Karma (needs a browser)                            |
| `npm run lint`  | Lint                                                               |

## Configuration: `nae.json`

[`nae.json`](nae.json) is the central configuration of the frontend. It defines:

- **Backend addresses** (`providers`): the auth endpoints and the resource URLs, all `http://localhost:8080/api` by
  default. With `"autoResolveBackendUrl": true` the frontend uses `<current origin>/api` instead, which is useful when it
  is served behind the same host as the engine.
- **Views** (`views`): routes, the component behind each route, whether it is public or private, and its navigation
  entry.
- **Theme, languages** (`sk-SK`, `de-DE`, `en-US`) and **logging**.

## Adding a view

A view is wired in three places:

1. an entry in `views` in [`nae.json`](nae.json),
2. a registration in `src/app/template-frontend-view.service.ts`,
3. a declaration in `src/app/app.module.ts`.

The view service file states that it is managed by schematics (`create-view`). Prefer the schematic to editing it by
hand. Existing views in `src/app/views/` are good starting points. For example, `side-nav/cases/` shows how a case view
is configured through dependency injection tokens.

## Structure

```
src/
├── app/
│   ├── app.module.ts                      # imports of @netgrif/components modules, providers
│   ├── template-frontend-configuration.service.ts  # loads nae.json
│   ├── template-frontend-view.service.ts  # maps view ids to components
│   └── views/                             # login, dashboard, side navigation, profile, builder examples
├── assets/                                # images and static files
├── environments/
└── styles/themes/                         # Angular Material themes
```

The default language is set in `src/app/app.component.ts`.

## Before publishing your app

- Change `name` in `package.json` to the name of your application.
- Review the backend addresses in `nae.json`.
