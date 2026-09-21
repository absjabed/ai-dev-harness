# Coding Principles (Universal)

Language-agnostic principles every agent applies to every change.

- **Clarity over cleverness.** Code is read ~10× more than it's written. Optimize for the
  next reader.
- **One thing per function.** A function should do one thing and do it well; if you need "and"
  to describe it, split it.
- **Name for what things ARE, not what they DO.** Nouns for variables/values, verbs for
  functions. Names should make comments unnecessary.
- **Error handling is not optional.** Every error is handled or explicitly propagated. No
  silent catches, no ignored return values.
- **Tests are not optional.** Untested code is broken code you haven't found yet. Business
  logic ships with tests.
- **No magic numbers or strings.** Use named constants with intent-revealing names.
- **Prefer explicit over implicit.** Make dependencies, effects, and control flow visible.
- **Comments explain WHY, not WHAT.** The code shows what; comments capture rationale,
  trade-offs, and non-obvious constraints.
- **Small, focused modules with clear boundaries.** Low coupling, high cohesion.
- **Dependency injection over global state.** Pass dependencies in; don't reach out to
  singletons from deep in the logic (e.g. services should receive their data-access
  dependencies rather than importing them directly).
- **Leave it cleaner than you found it**, but keep refactors separate from behavior changes.
