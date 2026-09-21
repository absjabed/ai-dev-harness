---
description: Ask a read-only question about the harness itself — usage, architecture, workflows, tuning, extension
argument-hint: <question about the harness>
allowed-tools: Read, Bash
disallowed-tools: Write, Edit, MultiEdit, NotebookEdit
---
@.ai/agents/harness-guide-agent.md

Question: $ARGUMENTS

You run **read-only** — answer the question following the persona above, citing the
files you read; change nothing. If the question is empty, ask the user what they want
to know about the harness.
