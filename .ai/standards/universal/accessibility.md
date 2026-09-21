# Accessibility (Universal)

Accessibility is a requirement, not a nice-to-have — target **WCAG 2.1 Level AA**. Every agent
applies this checklist; the Reviewer agent enforces it.

## The four principles (POUR)

- **Perceivable** — information and UI must be presentable in ways users can perceive.
- **Operable** — all functionality works via keyboard and assistive tech, not just pointer.
- **Understandable** — content and operation are predictable and clear.
- **Robust** — works across browsers and assistive technologies.

## Semantics & structure

- Use **native semantic elements** first (`button`, `a`, `nav`, `main`, `header`, `ul/li`,
  `label`, headings). Reach for ARIA only when no native element fits — "no ARIA is better than
  bad ARIA."
- One `h1` per page; don't skip heading levels. Landmarks (`main`, `nav`, …) frame the page.
- Buttons do actions; links navigate. Don't swap them or make a `div` a fake control.

## Keyboard

- **Everything operable by keyboard**, in a logical order matching the visual flow. No keyboard
  traps.
- Provide a **visible focus indicator** at all times — never `outline: none` without an equal-or-
  better replacement. Manage focus on route changes, dialog open/close, and dynamic content.
- Support expected keys for the pattern (Enter/Space activate, Esc closes overlays, arrow keys in
  menus/tabs/listboxes). Offer a "skip to content" link for long headers.

## Forms

- Every control has a programmatically associated **label** (`<label for>` or `aria-label`).
- Mark required fields and describe constraints up front. Link error messages to their field
  (`aria-describedby`) and move focus to the first error.
- Don't rely on placeholder text as the only label.

## Color & contrast

- **Text contrast ≥ 4.5:1** (≥ 3:1 for large text ≥ 24px / 19px bold). **UI/graphical contrast ≥
  3:1** for control boundaries, icons, and focus indicators.
- **Never convey meaning by color alone** — add text, icon, or pattern.

## Images, media & icons

- Meaningful images get descriptive `alt`; decorative images get empty `alt`/`aria-hidden`.
- Icon-only controls need an accessible name. Captions/transcripts for audio/video.

## Motion & timing

- Honor **`prefers-reduced-motion`**: reduce/disable non-essential animation. Avoid content that
  flashes more than 3×/second.
- Don't impose tight time limits; if unavoidable, allow extension. Auto-updating/animated content
  is pausable.

## Dynamic content & assistive tech

- Announce important async updates with **live regions** (`aria-live`) — errors, toasts,
  loading→loaded transitions.
- Keep state in sync for AT: `aria-expanded`, `aria-selected`, `aria-checked`, `aria-current`,
  `aria-busy` reflect reality.
- When using an accessible component library, **don't strip its built-in accessibility props/
  roles** when wrapping or styling its primitives.

## Targets & zoom

- Adequate touch-target size and spacing. Layout remains usable at 200% zoom and reflows to
  narrow viewports without loss of content or function.

## How to verify

- **Keyboard-only pass** through the whole flow (tab order, focus visibility, Esc/arrows).
- **Automated check** (e.g. axe) — zero critical violations.
- **Contrast check** on text and UI boundaries.
- **Screen-reader smoke test** of the primary path (names, roles, states announced correctly).
