# TurneyApp Branding

Custom, geometric identity — **no emoji, no clipart**.

## Concept

The mark is a stylized **single-elimination bracket** converging from four seeds to a
single **champion node** (the gold diamond). It reads as both a tournament bracket and
an abstract "T", and works at any size from a 16px favicon to a hero banner.

## Files

| File | Use |
|------|-----|
| `logo-mark.svg` | Square emblem — app icon, avatar, favicon source |
| `logo-full.svg` | Mark + "TurneyApp" wordmark — splash, headers, README |
| (export) `app_icon.png` | Generated from `logo-mark.svg` for launcher icons |

## Palette

| Token | Hex | Role |
|-------|-----|------|
| Violet | `#7C3AED` | Primary brand |
| Violet deep | `#6D28D9` | Gradient mid |
| Sky | `#0EA5E9` | Secondary / accent |
| Cyan | `#22D3EE` | "App" wordmark accent |
| Gold | `#F59E0B` | Champion node / prize highlights |
| Ink | `#0B1020` | Dark background |

## Generating raster exports

The Flutter app renders the SVG directly via `flutter_svg`. For launcher icons /
favicon, export PNGs from `logo-mark.svg` (e.g. with `rsvg-convert` or Inkscape) and
run `flutter_launcher_icons`:

```bash
rsvg-convert -w 1024 -h 1024 branding/logo-mark.svg -o app/assets/icons/app_icon.png
cd app && dart run flutter_launcher_icons
```
