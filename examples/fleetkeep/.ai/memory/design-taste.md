# Design Taste Log

This file is append-only and maintained automatically. The Designer agent reads it before
proposing designs (bias toward approved patterns, away from rejected ones) and appends an entry
after every approval loop.
Format each entry: `YYYY-MM-DD | Pattern/choice | approved|rejected | Why (user's words if given)`

## Entries

<!-- Example (delete once you have real entries):
- 2026-01-01 | Dense card grid on dashboard | rejected | "too busy — one clear metric per row"
-->
- 2026-02-20 | Compliance RAG as a label-bearing pill (colour + text + icon), never colour alone | approved | Transport managers print the dashboard in greyscale for depot noticeboards, and the accessibility rule made the printed version legible too
- 2026-03-05 | Amber (#F2A007) with white text on the overdue counter | rejected | Fails AA at 2.9:1; replaced with the dark foreground on amber. Bias away from white-on-amber anywhere in this product
- 2026-04-02 | Full-width fluid layout for the compliance dashboard and vehicle register, centred 1440px everywhere else | approved | These two screens are dense tables that managers scan across; the rest of the product reads better constrained
- 2026-04-24 | A second attention animation on the job-card queue badge | rejected | User's words: "one thing pulsing is a warning, two things pulsing is noise" — fk-pulse-overdue stays the only decorative animation
- 2026-05-19 | Mobile-first walkaround check with 44px targets and camera capture, rather than a scaled-down desktop form | approved | Drivers use it one-handed in a yard, often in gloves
