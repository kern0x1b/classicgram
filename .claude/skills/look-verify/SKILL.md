---
name: look-verify
description: Use before claiming a screenshot proves a UI change works, or when judging a chat-bubble/plate/avatar layout by eye. Covers running scripts/check-bubble-geometry.py, the nearest-neighbor-only zoom rule, and known false failures the script reports.
---

# Look verify

"Looks fine" is not a check. Two visual defects have shipped in one day after a reviewer approved
screenshots by eye alone. Every screenshot-based claim needs the mechanical check below run
against it, not just a glance.

## Run the checker

```
python3 scripts/check-bubble-geometry.py /path/to/screenshot.png
```

It floods the image for bubble-colored regions (white incoming, pale-green outgoing, tolerance
`FILL_MATCH_TOLERANCE`), then for each bubble reports:

- **tail / side / bottom_curve** — whether the bubble has its corner tail and a curved (not
  square-cut) bottom edge, and which side the tail is on.
- **avatar** — for chats with avatars (auto-detected from whether incoming bubbles sit indented at
  least `HAS_AVATARS_MIN_INSET_PX`), whether an avatar was found aligned to the bubble's bottom and
  not overlapping it.
- **plate** — whether the timestamp plate was found **outside** the bubble and NOT found inside
  it. This directly encodes the settled decision that the plate lives outside the bubble; a `FAIL`
  here means either the plate migrated inside, or nothing was found outside at all.

Exit code `0` means every bubble in the screenshot passed every check that applies to it; `1`
means at least one bubble failed or no bubbles were found at all. Treat a nonzero exit as a real
failure to investigate, not noise — read which specific line failed (tail / avatar / plate /
indent) before deciding it's a false positive.

## Known false failures

- **No bubbles found** on a screen that is not a chat view (e.g. a settings screen, a modal
  picker) — the script only understands chat bubbles; running it against unrelated screens
  produces "no bubbles found" and should not be read as a defect.
- **Avatar `[SKIP]`** in an avatarless chat (channel with hidden authorship, or a chat style where
  avatars are off) is expected, not a failure — the `has_avatars` heuristic already accounts for
  this, and the printed `[SKIP]` line, not `[FAIL]`, is what confirms it correctly recognized the
  case.
- **A single stray small region** flagged as a tiny near-white artifact rather than a real bubble
  — `MIN_BUBBLE_W`/`MIN_BUBBLE_H` filter most of these, but a very large plate or sticker
  background can still occasionally slip through the size filter; cross-check by eye against the
  actual screenshot before treating a single odd region as a real defect.

## Zooming a screenshot for close inspection

**Nearest-neighbor only.** A smoothed/bilinear resize blurs bubble tails and plate edges enough to
erase them from the image — this produced a false regression report once, where a real tail was
read as missing purely because the resize algorithm smoothed it away. In Python/Pillow:

```python
img.resize((img.width * 4, img.height * 4), Image.NEAREST)
```

Never `Image.LANCZOS`, `Image.BICUBIC`, or any smoothing filter for a screenshot you are about to
judge — only for a screenshot you are about to show a human as a nicer-looking picture, which is a
different task from verification.

## What to inspect on a bubble, by eye, in addition to the script

The script checks tail/curve/avatar/plate geometry; it does not check color correctness, text
rendering, or content. When looking at a bubble screenshot, additionally check:

- Bubble fill color matches the theme (white incoming / pale green outgoing) — not a leftover
  color from an unrelated feature.
- Text does not clip against the bubble's rounded corners or the tail.
- The plate's own background (its rounded pill, separate from the bubble) does not overlap the
  bubble edge it sits beside.
- For photo/sticker/round-video/large-emoji messages, confirm the plate sits on the image or
  wallpaper as appropriate, per the settled decision in the project's memory — this script's
  "outside/inside" check does not distinguish which surface the plate is drawn on, only whether it
  is inside the text bubble.

## Authority order when a look question needs settling

1. The 2013 original app (`../iTgLegacy-notes/design-reference/` screenshots, or the archived source
   under `../telegram-original-run` if present as a sibling checkout) — for how it should *look*.
2. The modern Telegram-iOS client (`../Telegram-iOS` if present as a sibling checkout) — for how a
   feature should *behave*.
3. This project's own existing code — lowest authority of the three; only wins when neither
   reference has an equivalent screen or the modern client's answer conflicts with the 2013 look.

Do not treat a screenshot from the modern client as proof of what the *look* should be — it is the
behavior authority, not the look authority. The reverse mistake (copying 2013 layout for a
behavior question TDLib now handles differently) is equally wrong.
