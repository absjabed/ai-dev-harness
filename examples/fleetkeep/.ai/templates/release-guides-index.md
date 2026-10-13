<!-- Seed for docs/release/README.md — the index and convention of record for the project's
     deployment guides. The release agent creates docs/release/README.md from this file (minus this
     comment) the first time it writes a guide, then only ever adds or updates rows in ## Guides.
     Used only when the deployment guide is switched on (project-config.md → Release deliverables).
     If the Word copy is off, the agent drops the "Word" column and the "Word (.docx) version"
     section when it creates the file. -->
# Release guides

One guide per release, documenting **what ships, how to deploy it, how to verify it, and how to roll
back** — written for whoever performs the deployment, not for the developers who built it.

## How to use

1. Each release gets a folder `docs/release/<version>/` holding `deployment-guide-<version>.md` (the
   version in every filename keeps a copied file identifiable anywhere). The skeleton is
   `.ai/templates/deployment-guide.md`; `/workflows:release` creates and fills it.
2. **Artifacts the engineer runs** (scripts, config files) go alongside the guide in that folder,
   version-named the same way. If an artifact has a canonical home in the repo, the guide says the
   bundled copy is a snapshot.
3. Keep it concrete — real environment and pipeline names, real click-steps. Never paste a secret
   (connection strings, keys, passwords); use `<placeholders>`.
4. Keep the guide updated as the release rolls out (tick the environment matrix). Later updates by
   the release agent **merge** into the file — they never overwrite human edits.
5. Regenerate the Word version (below) whenever the Markdown changes, and commit both together.

## Guides

| Release | Target branch | Headline | Guide | Word |
|---------|---------------|----------|-------|------|

## Word (.docx) version

The `.docx` is **generated from the Markdown**, so the Markdown is the single source of truth:

```bash
python .claude/scripts/md-to-docx.py docs/release/<version>/deployment-guide-<version>.md --org "<company>" --color "<#primary>"
# writes deployment-guide-<version>.docx next to it; -o <path> writes elsewhere, -q is quiet
```

Requires Python 3 with `python-docx` and `markdown-it-py` (`pip install python-docx markdown-it-py`).
Word itself is **not** needed to generate the file, so it also runs on a build agent.

> ⚠ **Never edit the `.docx` in Word.** A `.docx` cannot be diffed in git, so a manual edit is
> invisible to review and is silently lost the next time anyone regenerates. Edit the `.md`, re-run
> the command, and commit both files together. The generated document says so on its first page.

The converter handles headings, tables, `- [ ]` checklists, `>` callouts, fenced code, nested lists,
links and images, and adds a title page, a Word contents list, page numbers, and a page break before
each appendix.

**Screenshots** are committed image files referenced from the Markdown, so they are reviewed in git
like any other change — never pasted into the `.docx`. Put them in `docs/release/<version>/img/`;
paths resolve relative to the Markdown file. A missing image is a **warning**, not a failure: the
converter still exits 0, so read its output.

## Conventions

- One folder per release: `docs/release/<version>/`. Patch releases may use `<version>-hotfixN/`.
- Roll out in the order section 1.3 of the guide names, verifying one target end to end first.
