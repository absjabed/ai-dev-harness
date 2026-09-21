# UI/UX Standards (Universal)

Enterprise UI/UX standards every agent applies to interface work. **Stack- and value-agnostic** —
concrete values (exact colors, the radius scale, fonts) are never hardcoded here; they live in the
project's design tokens.

## First principles

- **Clarity over decoration.** Every element earns its place; remove anything that doesn't help
  the user complete the task. Clean, uncluttered, purposeful.
- **Consistency.** Reuse existing components, patterns, and tokens before inventing. The same
  action looks and behaves the same everywhere.
- **Hierarchy.** Guide the eye — one clear primary action per view; size, weight, color, and
  spacing express importance.
- **Feedback.** The system always responds to user action (hover, press, loading, success,
  error). Never leave the user guessing.
- **Forgiveness.** Make actions reversible where possible; confirm destructive ones; prevent
  errors before they happen.

## Design tokens

- Build **only** from the project's tokens (color, spacing, radius, typography, elevation,
  motion). Never introduce a one-off color or magic value — if a token is missing, raise it as a
  design decision.
- Reference tokens by **semantic role** (primary/action, surface, border, muted, destructive),
  not raw values, so theming and dark mode work automatically — never hardcoded values.

## Layout & grid

- Align to a consistent grid/columns; respect a max content width and consistent gutters.
- Group related content; use whitespace (not dividers alone) to separate groups.
- **Responsive, mobile-first:** design the small screen first, then enhance up the breakpoints.
  Content reflows; nothing critical is lost or clipped. Touch targets stay comfortable.

## Spacing

- Use a single spacing scale with a consistent base rhythm. Spacing is intentional and repeated,
  not arbitrary.
- More space between unrelated groups, less within a group (proximity communicates relationship).

## Typography

- Use the defined type scale and a clear hierarchy: distinct styles for page title, section
  heading, body, and secondary/caption text. Don't invent sizes.
- Optimize for reading: limited line length, adequate line-height, left-aligned body text,
  sentence case for most UI text. Don't communicate with weight/size alone — keep contrast.

## Color usage

- Color carries **meaning**: a primary/action color, neutrals for surfaces/text, and reserved
  semantic colors (success/warning/danger/info). Use them consistently.
- **Never rely on color alone** to convey state — pair with text, icon, or shape.
- Maintain sufficient text/UI contrast. Ensure every choice works in both light and dark themes.

## Elevation & surfaces

- Use a small, consistent set of elevation levels (flat → card → overlay → modal). Higher
  elevation = more focus/temporariness. Don't stack shadows arbitrarily.

## Interaction patterns

- **Affordance:** interactive things look interactive (and non-interactive things don't).
- **Immediate feedback:** hover/press states; optimistic or progress feedback for slow actions.
- **Loading:** prefer skeletons that mirror final layout over spinners for content; show progress
  for long operations; disable controls that would double-submit.
- **Forms:** label every field; validate helpfully (inline, on blur/submit) with clear field-level
  messages; preserve user input on error; disable submit while submitting; clearly mark required
  vs optional.
- **Destructive actions:** require confirmation, name the consequence, and make the safe choice
  the default.
- **Motion:** purposeful and quick; reinforce cause/effect and continuity, never block the user.
  Always honor reduced-motion preferences.

## Component states (the state matrix)

Every interactive component must define and visually distinguish all applicable states:

| State | Requirement |
|-------|-------------|
| **Default** | Resting appearance. |
| **Hover** | Clear pointer affordance. |
| **Active/pressed** | Visible response to press. |
| **Focus-visible** | A clear, high-contrast focus indicator for keyboard users (never removed). |
| **Disabled** | Visibly inactive, not focusable as an action, with a reason available. |
| **Loading** | In-progress affordance; prevents duplicate actions. |
| **Error** | Communicates the problem and the path to recovery. |
| **Empty** | Meaningful zero-state (what it is, why it's empty, what to do next). |
| **Selected/current** | Current selection or active navigation is unambiguous. |
| **Read-only** | Where applicable, distinct from disabled. |

## Content & voice

- Concise, plain, action-oriented language. Buttons name the action ("Save changes", not "OK").
- Be consistent with terminology and casing. Error/empty copy is helpful and human, never blaming
  or jargon-heavy.

## Definition of done (UI)

A UI change is done when it: is clean and consistent with existing patterns; uses only project
tokens (no hardcoded values); reuses existing component primitives where they fit; handles every
applicable state above; is fully keyboard-accessible and meets contrast; is responsive across
breakpoints; works in light and dark; and matches the approved design / reference material.
