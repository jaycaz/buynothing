# BuyNothing — Project Goal

## What This Is
An open source, distributed, AI-assisted commons for sharing and bartering.
Inspired by "buy nothing" communities — local, human, low-friction.
Not a marketplace. More like a communal closet that extends across your neighborhood.

## The Feeling
Things you own can easily flow into a shared tapestry of collective ownership.
All the friction of letting things come and go is gone. No pricing, no haggling,
no payment systems. Satisfaction of decluttering, warmth of community generosity,
practical cost savings. A zen sense that it all balances out over time.

## Core Experience: Toss & Whisper
1. **Toss** — point your camera at something, the app knows what it is, confirm, it's in the commons. Like dropping something into a basket.
2. **Whisper** — say what you need in plain language. The app quietly holds onto it.
3. **Nudge** — gentle suggestions connecting people. "Your neighbor has the bookshelf you mentioned. They could use kitchen stuff — you've got some to share."

## Design Principles
- **No grid, no marketplace feel.** Browsing is passive; things find their way to you. No scrollable product listings — items appear through nudges, not search.
- **Near-zero friction listing.** Camera → confirm → done. Under 10 seconds.
- **Warm, not transactional.** Nudges feel like a friend mentioning something, not a notification.
- **Privacy-first.** Matching intelligence lives on-device. No central server storing your stuff.
- **No payments.** Bartering and gifting only. Value roughly balances over time like a potluck.
- **Commons over trades.** Not strict 1:1 bartering — more like a potluck where everyone contributes and receives. As long as values are in the ballpark, the accounting is pointless.
- **Organic visual feel.** Background-removed objects floating in collage, not product photography. Items feel untethered from individual ownership.

## Current Prototype
SwiftUI iOS app. Claude vision API for item identification. Mock neighbor data for simulating the nudge loop. Proving out the core Toss & Whisper interaction.

## Technical Stack
- Native iOS, Swift/SwiftUI
- Claude API (vision) for item identification
- Local persistence (SwiftData or simple JSON)
- Modular architecture for future P2P/distributed expansion
