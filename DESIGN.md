# Design — "Trail Adventure"

Visual system for CampConnect (Flutter, Material 3). Single source: `lib/core/theme/app_theme.dart`.

## Color

Strategy: **committed** — the warm canvas + forest green carry the identity; sunset orange is the action accent; the kid's team color is the only dynamic color.

### Light ("daylight trail")

| Token | Hex | Role |
|---|---|---|
| canvas | `#FAF3E5` | scaffold background (sun-bleached canvas, tinted toward brand hue) |
| surface | `#FFFFFF` | cards, sheets |
| surfaceTint2 | `#F2E9D8` | secondary panels, chips, nav bar fill |
| ink | `#26302A` | primary text |
| inkMuted | `#57604F` | secondary text (≥4.5:1 on canvas) |
| forest (primary) | `#2E5339` | app bars accents, primary buttons, active nav |
| forestContainer | `#D9E9D2` / on `#1C3A25` | tonal buttons, badges |
| sunset (tertiary/accent) | `#C75B1E` | FABs, CTAs, highlights (white text passes 4.5:1) |
| sunsetBright | `#E8712D` | large display accents, icons only |
| sunsetContainer | `#FBDFC9` / on `#7A3410` | soft highlight fills |
| emergencyRed | `#BA2D22` | ONLY emergency features |

### Dark ("campfire night")

canvas `#161C17`, surface `#1F261F`, surfaceTint2 `#283128`, ink `#E7EAE1`, inkMuted `#A9B2A4`, primary `#A6D3AA` (on `#12351D`), primaryContainer `#2B4A33`, sunset accent `#F09B5F` (on `#4A2408`), sunsetContainer `#6B3312`, emergency `#F2887C`.

## Typography

**Nunito** (bundled, Latin-Ext for ș ț ă ő ű) — one family, four weights:

- Display / headline: ExtraBold 800, tight-ish (-0.5 letterSpacing on display)
- Title: Bold 700
- Body: Regular 400, 16/1.5
- Label / buttons: SemiBold 600 (wt700 for buttons)

Scale ratio ~1.2 (product register). No display fonts in labels/data.

## Shape

- Cards: 20 (hero cards 24)
- Buttons: 16; primary CTA may be stadium
- Inputs: 14, filled style (no outline box), subtle border on focus only
- Sheets / dialogs: 28 top radius
- Nav bar indicator: pill

## Components

- **AppBar**: transparent over canvas, left-aligned ExtraBold title, no elevation.
- **Cards**: flat (elevation 0), solid fills, no drop shadows; hierarchy via fill tint (white on canvas / tint2 panels).
- **Hero card**: kid home team card — solid team color fill, big type, stat pill. The only place a big color block is allowed besides emergency.
- **NavigationBar**: surface fill, pill indicator in forestContainer, active icon forest; labels always shown (kids).
- **Buttons**: Filled = forest; the single per-screen CTA may be sunset. Tonal = forestContainer. Destructive = emergencyRed, emergency features only.
- **Empty states**: icon in tonal circle + one-line invitation + CTA. Never bare "nothing here".
- **Guide temperature**: same tokens; guides get white/tint2 panels, forest accents, denser lists — orange only on the primary action of a screen.

## Motion

150–250 ms, ease-out. State changes only (nav transitions, expand, snackbar). No page-load choreography. Respect reduced motion.

## Bans

Red outside emergency · gradients on containers (hero card is solid) · drop shadows as decoration · dark-gamified styling · more than one sunset-filled element per screen.
