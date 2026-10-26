# Describe a business process. Your AI assistant turns it into a running app.

**Netgrif AI Code** is the whole [Netgrif](https://netgrif.com) platform on your machine, prepared for any AI coding
assistant. You describe what the business needs; the assistant generates a complete Netgrif application in
[Petriflow](https://petriflow.org/#/) (workflow, data, forms, roles, actions and the menu), checks it and runs it.
Login, the portal, task lists and the database are already there. If you need more, extend it with your own Java
modules, or with your own Angular frontend through the
[frontend starter](https://github.com/netgrif/nae-frontend-application-starter).

**All you need is [Docker](https://www.docker.com/products/docker-desktop/) and any AI coding assistant.** Everything
else runs in containers: no Java, Node or database to install.

[![A Word brief goes to any AI coding assistant, it builds the onboarding app with roles, forms and demo users, HR, the manager and IT work in it at localhost:4200, and the next prototype is one sentence away](docs/media/demo.gif)](https://youtu.be/LpdUfdaEqT4)

<sub>HR's Word document goes to the AI assistant as it is. A few minutes later HR raises a request, the manager approves
it and IT ticks off the accounts. A change is one sentence, and the same files go to your server.
[Watch the narrated walkthrough on YouTube](https://youtu.be/LpdUfdaEqT4)</sub>

## Get started

**1. Make it your own.** This repository is a template. Click **Use this template → Create a new repository** at the
top of this page and name it after your application, for example `onboarding-app`.

**2. Start Netgrif.** Clone your new repository, start Docker and run:

```bash
git clone https://github.com/<your-account>/<your-app>.git
cd <your-app>
docker compose up -d
```

The first start downloads the images (the engine, the frontend, the databases) and takes a few minutes; later starts
take seconds. Netgrif runs at **http://localhost:4200** once `curl http://localhost:8080/manage/health` returns `UP`. Log in as
`admin`; its password is set in [`docker-compose.yaml`](docker-compose.yaml)
(`netgrif.engine.security.auth.admin-password`). Change it there before you share the machine with anyone.

**3. Describe what the business needs.** Open the folder in any AI coding assistant: Claude Code, Codex, Cursor,
GitHub Copilot, Gemini CLI or any other. There is nothing to configure. Hand it a Word document, an e-mail or a diagram you
already have, or tell it the way you would tell a colleague:

> We need an app for **[your process]**. **[Who]** starts it and fills in **[what]**.
> **[Who]** approves it, and if they send it back, **[what happens]**. After approval
> **[who]** does **[what]**. Everyone should see where each request is stuck.
> Build it on this platform and prove it runs in the engine before you tell me it is done.

The assistant writes the application into `processes/<app_name>/`, validates it, shows you the plan and deploys it
after your yes. Then it tells you where to sign in.

**4. Use it, update it if needed.** Work in the app and ask for changes in plain words. Each change is a new version;
running cases keep theirs. The last prototype is the app.

**5. Deploy it to your server.** The application is the set of files in `processes/<app_name>/`. Deploy them to your
company's Netgrif portal: upload them in its **Workflow** view, or let the assistant deploy them after your yes.
Production use needs a commercial licence: see [Licence and production use](#licence-and-production-use).

## What it is good for

Netgrif is the tool for when you need **processes, tasks and an overview of anything that goes on**: who does what,
in which order, with which data, and where each thing stands right now. In a large company, a small team, a school,
a municipality, a club or a one-off event alike.

**A good fit:** any process where people, steps, decisions and documents meet, inside an organisation or open to its
customers, members and partners:

- **Requests and approvals**, where someone asks, someone decides and everyone sees the state: leave, purchases,
  expenses, access rights
- **Case handling**, where a case moves through several people or teams until it is resolved: complaints, claims,
  incidents
- **Forms with a back office**, where a customer, citizen or member fills in a form and staff process it:
  applications, registrations, orders
- **Records and registers** of anything you need to manage over time: assets, equipment, vehicles, members,
  suppliers, inspections and their renewals

<details>
<summary><strong>More examples</strong></summary>

- **Contracts and documents**, from intake and review to signature and archive
- **Service desks and ticketing**, with queues, deadlines and escalation
- **Onboarding and offboarding**, where HR, managers and IT each tick off their part
- **Projects, events and recurring work**, from a team's checklist to the preparation of a conference or a season of a
  sports club
- **Orchestration** of people and existing systems into one task list

</details>

Anything that is today a spreadsheet, an e-mail thread or a shared folder with rules nobody wrote down is a candidate.

**Not a good fit:** consumer mobile apps, games, marketing websites, design-first custom UIs, real-time analytics or
streaming data. The platform draws the screens from the model, so if the screen *is* the product, this is the wrong
tool.

## What it is made of

| Part | What it does | Where |
|---|---|---|
| **Application Engine** (`netgrif/application-engine-with-mcp:7.0.3`) | The backend: interprets Petriflow, REST API, and the engine MCP the assistant deploys and tests with, at `localhost:8080` | [`docker-compose.yaml`](docker-compose.yaml) |
| **Frontend** (`netgrif/application-engine-frontend:7.0.3`) | The portal your users work in, at `localhost:4200` | [`docker-compose.yaml`](docker-compose.yaml) |
| **Petriflow MCP** (`netgrif/petriflow-mcp:1.0.0`) | Petriflow knowledge and validation for the assistant, at `localhost:3000` | [`docker-compose.yaml`](docker-compose.yaml) |
| **MongoDB, Elasticsearch, Redis** | Data, search and cache | [`docker-compose.yaml`](docker-compose.yaml) |
| **Rules for the assistant** | How to build, check and test a Netgrif application, and when to ask you | [`AGENTS.md`](AGENTS.md), [`.agents/skills/`](.agents/skills/), [`.mcp.json`](.mcp.json) |
| **Your application** | The Petriflow files the assistant writes, one folder per application (with a `hello_world` example) | [`processes/`](processes/README.md) |
| **Your modules** (optional) | Java code the engine loads at start | [`modules/`](modules/README.md) |

More about the stack, ports and commands: [nae/README.md](nae/README.md).

## Licence and production use

This repository is under the **NETGRIF Community License 2.0**: source-available, not open source, for
**development and testing only**. See [LICENSE.txt](LICENSE.txt).

To run your applications in production in your company, you need a **commercial licence** for the Netgrif platform.

- **Buy a commercial licence now:** [contact our sales team](https://netgrif.com/contact-us/), they will be happy to
  help.
- **Prefer to buy it yourself?** We are building a customer portal where you will buy Netgrif commercial licences on
  your own. [Join the waiting list](https://netgrif.com/licence-waiting-list/) and we will let you know when it opens.
