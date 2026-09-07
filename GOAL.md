# BuyNothing — Project Goal

## What This Is
An open source, AI-assisted tool for community engagement — a digital commons for
sharing and bartering, and the first of what could be several ways AI quietly
supports how communities take care of each other.
Inspired by "buy nothing" communities — local, human, low-friction.
Not a marketplace. More like a communal closet that extends across your neighborhood.

## The Feeling
Things you own can easily flow into a shared tapestry of collective ownership.
All the friction of letting things come and go is gone. No pricing, no haggling,
no payment systems. Satisfaction of decluttering, warmth of community generosity,
practical cost savings. A zen sense that it all balances out over time.

## The Idea
Bartering and freely sharing what you own should be far easier than it is today —
easy enough that you discover exchanges with a neighbor or friend you never would
have thought to look for. You catalog the things you'd be glad to give away, and
the connections and trade suggestions surface on their own. Make that easy enough,
and currency becomes unnecessary in a lot of everyday exchanges.

AI is the quiet mechanism behind that, not the point of the product. It should feel
like an invisible helper — present in what it makes effortless, never in a badge,
a chat window, or a feature you have to notice.

## Core Experience
1. **Catalog, effortlessly** — point your camera at something, and it's in the
   commons. No forms, no required fields. If you want to say more, it's a quick
   line dropped in like a comment, not structured data entry — the app should
   recognize what it can on its own and only ask you to fill the gaps.
2. **Showcase, delightfully** — photos are intelligently segmented and cleaned up
   so items are presented well without any editing effort on your part. This
   is where craft matters most: it should feel like a well-kept shop window, not
   a phone camera roll.
3. **Discover, spontaneously** — the app surfaces connections and trade
   suggestions you wouldn't have thought to look for yourself: "your neighbor has
   the bookshelf you mentioned, and could use kitchen stuff — you've got some to
   share." Browsing is passive; things find their way to you.

## Design Principles
- **No grid, no marketplace feel.** Browsing is passive; things find their way to you. No scrollable product listings — items appear through suggestions, not search.
- **Near-zero friction listing.** Camera → confirm → done. Under 10 seconds. No fields to fill in beyond what you feel like saying.
- **AI as invisible helper.** It should do work you'd notice by its absence, not announce itself. If a feature only works by making the AI visible, reconsider it.
- **Warm, not transactional.** Suggestions feel like a friend mentioning something, not a notification.
- **Privacy-first.** Matching intelligence lives on-device. No central server storing your stuff.
- **No payments.** Bartering and gifting only. Value roughly balances over time like a potluck.
- **Commons over trades.** Not strict 1:1 bartering — more like a potluck where everyone contributes and receives. As long as values are in the ballpark, the accounting is pointless.
- **Organic visual feel.** Background-removed objects floating in collage, not product photography. Items feel untethered from individual ownership.

## Current Prototype
SwiftUI iOS app. Claude vision API for item identification. Mock neighbor data for simulating the discovery/suggestion loop. Proving out low-friction cataloging plus intelligent photo segmentation and cleanup.

## Technical Stack
- Native iOS, Swift/SwiftUI
- Claude API (vision) for item identification
- Local persistence (SwiftData or simple JSON)
- Modular architecture for future P2P/distributed expansion
