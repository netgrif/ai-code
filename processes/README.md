# Petriflow processes

This folder holds the [Petriflow](https://github.com/petriflow/petriflow) processes of your application. A process
describes data, tasks, roles and Groovy actions as a Petri net in XML, and runs on the Application Engine. For the
overall project, see the [main README](../README.md).

## Layout

One subfolder per application, one XML file per process, and a short `README.md` per application:

```
processes/
└── <app_name>/
    ├── README.md
    └── <process_name>.xml
```

Applications separate the business logic of the project. They are only a grouping: all deployed processes can reference
each other, regardless of application. The application `README.md` lists its processes, how they communicate, which
processes of other applications they use, and the order in which to deploy them.

The included example is [`hello_world/hello_world.xml`](hello_world/hello_world.xml). It asks for a name, builds a
greeting with an action, and then asks whether the user is done.

## Importing a process

Import processes after the engine has started (see [`../nae/README.md`](../nae/README.md)).

- **In the UI:** open the "more" icon (bottom left), choose the **Workflow** view, click **+**, select the XML file and
  click **Upload**.
- **With an AI agent:** through the `deploy_process` tool of the local NAE MCP server (see the main README).

Then create a case from the process and work through its tasks.

## Conventions

- Application names and process names are snake_case. The application folder is named after the application.
- The process `id` is `<app_name>/<process_name>` (for example `hello_world/hello_world`) and must be unique across the
  whole Application Engine deployment. The file is `processes/<app_name>/<process_name>.xml`.
- Keep the application `README.md` up to date when you add or change a process.
- Validate every change, for example with the Petriflow MCP tool `validate_process`.
- Keep actions short and use the Petriflow Action API. Logic that does not fit in a process belongs in a
  [module](../modules/README.md).
