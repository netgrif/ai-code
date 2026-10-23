# Describe a business process. Your AI assistant turns it into a running app.

**Netgrif AI Code Starter** runs the [Netgrif](https://netgrif.com) platform on your machine. Login, roles,
permissions, forms, task lists, the portal and the database already run. Your AI assistant writes only the business
process, as a [Petriflow](https://github.com/petriflow/petriflow) model, checks it and deploys it, and it becomes a
working application in the portal.

![docker compose starts Netgrif, the AI assistant turns a leave request brief into a process and deploys it after a yes, and the app runs in the portal](docs/media/demo.gif)

<sub>Start Netgrif with one command, hand your AI assistant the brief, approve its plan, and the app runs in the
portal.</sub>

## 1. Start Netgrif

You need [Docker Desktop](https://www.docker.com/products/docker-desktop/) and Git.

```bash
git clone https://github.com/netgrif/starter.git
cd starter/nae
docker compose up -d
```

Or open the folder in **IntelliJ IDEA** or **VS Code**, open `nae/docker-compose.yaml` and click the green ▶ next to
`services:`.

When `curl http://localhost:8080/manage/health` returns `UP`, open **http://localhost:4200** and sign in as
`super@netgrif.com`. The password is printed in `nae/nae-backend/logs/nae.log` on the first start.

## 2. Describe your business problem

Open the repository folder in your AI assistant: Claude Code, Codex, Cursor, GitHub Copilot or Gemini CLI. The rules
for the platform (`AGENTS.md`, `.agents/skills/`) and its two MCP servers (`.mcp.json`) are already in the repository,
so there is nothing to configure. Then tell it what your business needs, the way you would tell a colleague:

> We need an app for **[your process]**. **[Who]** starts it and fills in **[what]**.
> **[Who]** approves it, and if they send it back, **[what happens]**. After approval
> **[who]** does **[what]**. Everyone should see where each request is stuck.
> Build it on this platform and prove it runs in the engine before you tell me it is done.

A Word document, an e-mail or a diagram you already have works too.

The assistant writes the process into `processes/<app_name>/` and validates it. Before it deploys anything, creates
cases or test users, it shows you the plan and waits for your yes. Then open http://localhost:4200 and work in the
app. Ask for changes in plain words until the prototype is the app.

## What it is good for

**A good fit:** any process where people, steps, decisions and documents meet, inside a company or open to its
customers and partners:

- **Requests and approvals**, where someone asks, someone decides and everyone sees the state
- **Case handling**, where a case moves through several teams until it is resolved
- **Forms with a back office**, where a customer or partner fills in a form and staff process it
- **Contracts and documents**, from intake and review to signature and archive
- **Service desks and ticketing**, with queues, deadlines and escalation

Anything that is today a spreadsheet, an e-mail thread or a shared folder with rules nobody wrote down is a candidate.

**Not a good fit:** consumer mobile apps, games, marketing websites, design-first custom UIs, real-time analytics or
streaming data. The platform draws the screens from the process, so if the screen *is* the product, this is the wrong
tool.

## More

- **Without AI:** import [`processes/hello_world/hello_world.xml`](processes/hello_world/hello_world.xml) in the UI
  ("more" icon bottom left → **Workflow** → **+** → **Upload**), or model processes in the
  [Application Builder](https://builder.netgrif.cloud/).
- **The stack, ports and commands:** [nae/README.md](nae/README.md)
- **Processes and conventions:** [processes/README.md](processes/README.md)
- **Custom Java modules** (only when a process is not enough, needs Java 21 and Maven):
  [modules/README.md](modules/README.md)
- **What the AI assistant follows:** [AGENTS.md](AGENTS.md)
- **Shared portals with your company login, and Netgrif AI Chat for the people who use your apps:** that is
  Netgrif AI Suite Enterprise. [Contact Netgrif](https://netgrif.com/contact-us/).

## Licence

**NETGRIF Community License 2.0**: free for development, testing and other non-production use, source-available, not
open source. Production use needs a commercial licence. See [LICENSE.txt](LICENSE.txt).
