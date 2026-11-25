# How the addon works

## Identity and data

The address book is scoped by realm and faction. Preview 3 reads the public realm ID, the native realm ID or the server component of a valid player GUID, alongside available realm-name APIs. It reuses a uniquely matched existing table, preserving memberships, personal reserves, item overrides and delivery holds. Missing identifiers or ambiguous saved networks leave dispatch unavailable. The **Mail network** line exposes the selection. [Forever connection API](https://github.com/Gethe/wow-ui-source/blob/d9c22e32cb240afb82bb2ecefbb78ef935333f59/Interface/AddOns/Blizzard_APIDocumentationGenerated/ConnectionDocumentation.lua#L22) · [Camelot friends frame](https://github.com/Gethe/wow-ui-source/blob/d9c22e32cb240afb82bb2ecefbb78ef935333f59/Interface/AddOns/Blizzard_FriendsFrame/Camelot/FriendsFrame.lua#L386)

Registration binds a role to the logged-in character’s GUID and native full mailing name. Forever’s Camelot UI joins the first name and surname using the client’s separator. Both the registration control and the outgoing preview display that address. The only saved table is `ForeverGoblinMailerDB`. [Forever naming source](https://github.com/Gethe/wow-ui-source/blob/c01a87b549bbc19e0f284c1616d18654c91297de/Interface/AddOns/Blizzard_FrameXMLUtil/Camelot/NameUtil.lua)

The ingredient index joins `SkillLineAbility.Spell` to `SpellReagents.SpellID` for the profession skill lines. Only positive reagent IDs with a positive consumed count are admitted. The 1.60.1.71091 snapshot contains **589 distinct ingredients** and **1,084 ingredient–profession links**. The data came from the build’s three DB2 files and its matching enUS hotfix cache. The release carries numeric ingredient IDs and role names. Each bag scan uses client item metadata. [Generator](https://github.com/LML-Studio/ForeverGoblinMailer/blob/main/tools/build_recipes.py) · [Generated index](https://github.com/LML-Studio/ForeverGoblinMailer/blob/main/ForeverGoblinMailer/Recipes.lua)

| Decoded table | SHA-256 used for this build |
| --- | --- |
| SkillLine | `0a6fd95fa157cd0b3c1b00da55cad527d389398bcc6172e460459f6dcc94b7cd` |
| SkillLineAbility | `ff55ddaf9769371cab81898ca019196ea4c694e1d5148d216674112d3d4ebafd` |
| SpellReagents | `8c094f008ad07e72423713742add5e85a537b8baf9ef92c153e38d6d45588a06` |

## Routing precedence

```mermaid
flowchart TD
    S["One carried-bag stack"] --> T{"Transfer checks pass?"}
    T -->|No| H["Hold and display reason"]
    T -->|Yes| O{"Saved item rule?"}
    O -->|Keep| H
    O -->|Destination| D{"Other registered recipient?"}
    O -->|Automatic| F{"Material family or recipe?"}
    F -->|Resolved role| D
    F -->|Ambiguous material| H
    F -->|Eligible sale stock| Q{"Unit quote meets floor?"}
    Q -->|Yes| D
    Q -->|Missing or low| H
    D -->|Yes| P["Group by character and split at attachment limit"]
    D -->|No| H
```

This follows **Route my bags** on the main. **Materials to main** uses a separate return branch that honors Keep and auction reservations. [Routing source](https://github.com/LML-Studio/ForeverGoblinMailer/blob/v2.0.0-preview.3/ForeverGoblinMailer/Routing.lua#L42)

## From bag to recipient

1. Read the backpack and equipped carried bags. Hold locked, bound, loot-containing, quest, refundable, equipment-set and unresolved stacks. Identify the physical slot, GUID, item variant and quantity.
2. Apply the player’s item rule. Familiar material families take priority, followed by recipe use. For a shared recipe ingredient, all registered candidates must point to one character to route automatically. A free choice remains visible in the held list.
3. For eligible remaining goods, obtain an optional Auctionator unit price and compare with the floor. The per-item Auction rule works independently.
4. Group by receiving character, in the order encountered, and split at the native attachment limit. Every included stack and excluded reason appears in the review.
5. At dispatch, require a clean draft. Re-read each reviewed bag slot immediately before attaching, then check the exact native recipient, subject, body, money, COD and attachment variant/count before submission.
6. Quote postage and check the balance again after populating the money field. Each client-accepted parcel reduces the run’s spending budget. A different quote, insufficient balance or mismatched stack stops the queue.

For gold-only reviews, the dispatcher calculates the transferable copper before creating a parcel. Wallet and draft updates refresh the offer. A changed amount discovered on approval requires another click, and the final native wallet and postage readback still applies. Real item letters can proceed at zero gold surplus when their postage is covered.

## Delivery and recovery

```mermaid
stateDiagram-v2
    [*] --> Review
    Review --> Attach: Player approves or enrolled auto-return expires
    Attach --> Submit: Native readback matches
    Attach --> Stopped: Draft or item changed
    Submit --> Attach: Send success and parcels remain
    Submit --> Accepted: Final send success
    Submit --> Hold: Missing confirmation or failure
    Hold --> Review: Player reconciles delivery
```

A single in-flight parcel waits for `MAIL_SEND_SUCCESS`. The more general `MAIL_SUCCESS` can accompany inbox operations. A 30-second timeout ends the queue and leaves a delivery hold. WoW saves the hold with normal SavedVariables writes. Blizzard owns any secure confirmation dialog. [Native mail frame](https://github.com/Gethe/wow-ui-source/blob/c01a87b549bbc19e0f284c1616d18654c91297de/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua) · [Mail events](https://github.com/Gethe/wow-ui-source/blob/c01a87b549bbc19e0f284c1616d18654c91297de/Interface/AddOns/Blizzard_APIDocumentationGenerated/MailInfoDocumentation.lua) · [Secure transfer API](https://github.com/Gethe/wow-ui-source/blob/c01a87b549bbc19e0f284c1616d18654c91297de/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecureTransferDocumentation.lua)

## Runtime layout

| File | Responsibility |
| --- | --- |
| Roster.lua | Scope, names, character roles and the auction floor |
| Recipes.lua | Generated profession-ingredient membership |
| Routing.lua | Precedence, material families, parcel grouping and money arithmetic |
| Mailbox.lua | Read the native bags, cursor, compose fields, attachment list and postage |
| DeliveryCheck.lua | Optional, bounded local comparison of marked outbound letters and matching native inbox entries |
| Dispatch.lua | Countdown, review, guarded execution, acknowledgement and recovery |
| DeskKit.lua | Reusable native icon rows, text measurement, edit fields, color palettes and tooltips |
| DeskPages.lua | Six navigable pages, explicit role and rule editing, gold ledger and receipt views |
| Panel.lua | Docking, scale, scrolling, drag placement, countdown and action footer |
| Mailroom.tga | Branded postal illustration rendered in the native header |
