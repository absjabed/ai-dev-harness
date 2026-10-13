# Docs

Everything needed to adopt the harness and understand what each part does.

| File | Read it when you want to… |
|---|---|
| [`index.html`](index.html) | Read the whole thing as one browsable page — open it in a browser, no build step |
| [`getting-started.md`](getting-started.md) | Take the template from clone to a working setup, and run your first feature |
| [`components.md`](components.md) | Look up any component: every command, persona, sub-agent, hook, workflow, template and where its output lands |
| [`portability.md`](portability.md) | Run the harness on a non-Claude agent — what travels, what doesn't, and how to make the guardrails tool-independent |

These four are the entry point. The deeper references live with the code they describe:

| Reference | Covers |
|---|---|
| [`../README.md`](../README.md) | The system overview and the condensed setup section |
| [`../AGENTS.md`](../AGENTS.md) | The method as instructions for any non-Claude agent |
| [`../COMMANDS.md`](../COMMANDS.md) | Every `/command`, who runs it, and what it produces |
| [`../.ai/CUSTOMIZATION.md`](../.ai/CUSTOMIZATION.md) | The 13 variability axes — which files and tokens each owns |
| [`../.ai/README.md`](../.ai/README.md) | The Knowledge Layer in detail |
| [`../.claude/README.md`](../.claude/README.md) | The Execution Layer in detail |
| [`../examples/fleetkeep/`](../examples/fleetkeep) | A complete worked example — the same template fully configured |

## Keeping these honest

`index.html` is hand-written, not generated: if you change `getting-started.md` or `components.md`,
update the matching section in the HTML in the same commit. All three describe real files — when you
add a command, a hook toggle or a sub-agent, they are part of the change (invariant 7 in
[`../.ai/workflows/harness-improvement.md`](../.ai/workflows/harness-improvement.md) already requires
the doc inventories to stay true).
