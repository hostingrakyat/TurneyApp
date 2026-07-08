# ProTourney Branding

Custom, geometric identity — **no emoji, no clipart**.

## Concept

The mark is a stylized **tournament bracket** rising from four seeds to a single
**champion diamond** (gold, with a soft glow) on a maroon **squircle**. It reads
as a bracket and a trophy at once, and holds up from a 16px favicon to a hero
banner.

## Files

| File | Use |
|------|-----|
| `logo-mark.svg` | Square emblem — app icon, avatar, favicon source, in-app logo mark |
| `logo-full.svg` | Self-contained banner (mark + "ProTourney" wordmark) for the README / docs |
| `app/assets/icons/app_icon.png` | 1024px raster of the mark, consumed by `flutter_launcher_icons` |

The Flutter app renders `logo-mark.svg` at runtime via `flutter_svg` and draws the
"ProTourney" wordmark as real text (see `app/lib/shared/widgets/app_logo.dart`),
so the in-app lockup never depends on SVG `<text>`.

## Palette (maroon)

| Token | Hex | Role |
|-------|-----|------|
| Maroon | `#9E1B32` | Primary brand |
| Maroon deep | `#6E1422` | Gradient end / icon corners |
| Crimson | `#B91C3B` | Gradient start / accent |
| White-pink | `#F5E9EC` | Sub-accent / "Tourney" wordmark |
| Gold | `#F1B24A` | Champion diamond / prize highlights |
| Ink | `#120A0D` | Dark app background |

(These mirror `AppColors` in `app/lib/core/theme.dart`, where the field names
`violet`/`sky`/`cyan` are kept for stability but hold the maroon values above.)

## Regenerating the launcher icon

After editing `branding/logo-mark.svg`, re-rasterize the 1024px PNG with the
bundled headless-Chromium script, then let `flutter_launcher_icons` fan it out:

```bash
bash tool/render_icon.sh                 # writes app/assets/icons/app_icon.png
cd app && dart run flutter_launcher_icons # regenerates Android + web icons
```

CI runs `flutter_launcher_icons` on the committed PNG, so **commit the
regenerated `app_icon.png`** whenever the mark changes.
