---
description: Serve the agent knowledge base (.ai/) as a local MkDocs documentation site at http://localhost:8000
allowed-tools: Bash
disallowed-tools: Write, Edit, MultiEdit, NotebookEdit
---

Spin up the local documentation portal for the FleetKeep agent knowledge base.

## Steps

1. Check if `mkdocs` is installed:
   ```bash
   mkdocs --version 2>/dev/null || echo "not installed"
   ```

2. If not installed, install it:
   ```bash
   pip install mkdocs-material
   ```

3. Verify `mkdocs.yml` exists at the repo root (it maps `.ai/` to a navigable site).

4. Start the server:
   ```bash
   mkdocs serve
   ```

This opens a live-reload documentation site at **http://localhost:8000** containing:
- All architecture context files (with Mermaid diagrams rendered visually)
- Standards and coding principles
- Workflow playbooks
- Agent role definitions
- Output templates

The site auto-reloads when any `.ai/*.md` file changes. Press Ctrl+C to stop.

**Note:** This is a local dev tool only — no deployment or CI integration.
