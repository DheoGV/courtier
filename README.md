# Courtier

Padel score & ranking app for iOS (SwiftUI). Enter any number of players, pick Americano, Mexicano or Fix Partner, play as many rounds as you like, score each match as rally points (11 / 21) or tennis race-to-N, and follow a live leaderboard.

## Requirements

- Xcode 26+ (iOS 17 deployment target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` is generated from `project.yml` and not committed

```bash
brew install xcodegen
xcodegen generate
open Courtier.xcodeproj
```

## Structure

```
Courtier/
  App/            App entry, splash, root view, custom tab bar, router
  DesignSystem/   Tokens (colours, radius, spacing), typography, crown mark, shared components
  Models/         Session / round / match models, scoring rules, scheduler, standings, store (JSON)
  Features/
    Setup/        "Atur Turnamen": players (paste a list), format, scoring, courts, rounds, estimate
    Schedule/     "Babak n / N": courts, sit-outs, next action, add round / next Mexicano round
    Score/        Rally scorer (+/−, quick final score) and tennis race scorer (15-30-40, quick results)
    Leaderboard/  Podium + table, share as text
  Resources/      Asset catalog (app icon, launch logo)
CourtierTests/    Scoring, scheduler and standings tests
design/
  padel-score.pen Source design (open with pen.dev): theme "Courtier — Elegan", brand board, app icon
```

## Rules implemented

| Area | Logic |
|---|---|
| Americano | Partners and opponents rotate. With everyone playing and N divisible by 4, the circle method gives every pair exactly one round together over N−1 rounds; otherwise 400 random pairings are tried and the one with the fewest repeated partners/opponents wins. |
| Mexicano | Round 1 random; each next round is built from the standings after the previous one finishes: 1+4 vs 2+3 per court (1+3 vs 2+4 if that would repeat last round's partners). |
| Fix Partner | Teams in entry order (1&2, 3&4, …; "Acak urutan" reshuffles). Opponents rotate, minimising repeat meetings. Standings per team. |
| Sit-outs | Players beyond `courts × 4` rest; whoever rested least, then longest ago, rests next. |
| Rally 11 / 21 | Race to target; with deuce a 2-point lead is needed up to the cap (11 → 15, 21 → 30). |
| Tennis race | 0-15-30-40 per game, golden point or advantage; first team to N games wins (valid results for N=3: 3–0, 3–1, 3–2). |
| Leaderboard | Default: match wins → point/game difference → head-to-head → win rate. Optional classic Americano: total points (resting players get the round average) → wins → difference → head-to-head. |
| Duration | rounds × minutes per match (default 10). |

Rounds are unlimited: "Tambah babak" adds one at any time.

## Fonts

Bundled in `Courtier/Resources/Fonts/` from [google/fonts](https://github.com/google/fonts) under the SIL Open Font License (licence files alongside): Playfair Display (titles, scores), Jost (UI) and Marcellus (wordmark). Playfair Display and Jost are variable fonts; `Typography.swift` sets their weight on the `wght` axis and turns on lining figures for Playfair so score digits sit on the baseline. If a font file is missing, the app falls back to New York / SF Pro.
