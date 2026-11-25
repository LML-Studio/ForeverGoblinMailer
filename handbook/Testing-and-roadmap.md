# Testing and roadmap

## Reproduce the release checks

From the tagged checkout run `lua5.1 tests/run.lua` and `python tools/verify_package.py`. GitHub Actions uses the same entry points. The 37 scenarios include every page, unavailable action tooltips, receipt reconciliation, preserved reserves, adjustable countdowns, and small-screen fitting. Offline snapshots run the real Lua frame tree with the build’s font and icons. The fixture supplies synthetic character identities, wallet balances, bags, cursor contents, native compose controls and timed server responses. [CI runs](https://github.com/LML-Studio/ForeverGoblinMailer/actions/workflows/verify.yml) · [Test scenarios](https://github.com/LML-Studio/ForeverGoblinMailer/blob/main/tests/run.lua)

| Covered offline | Native acceptance still needed |
| --- | --- |
| Full-name enrollment, realm/faction scoping, shared roles, self-mail prevention | Actual surname address delivery between two enrolled characters |
| Recipe graph, overrides, uncached items, per-unit auction floor and missing quotes | Actual Forever bag metadata and cached Auctionator prices |
| Stack identity, attachment readback, multi-parcel limits, draft/COD interference | Real clicks, cursor behavior, server pacing and secure transfer dialogs |
| One-gold boundary, changed final postage, lower live balance, cancellations and timeout holds | Before/after balances and inventory receipts on both actual characters |
| Mailbox launcher, review/send controls and slash settings in a fixture | In-game panel fit, input, scale and coexistence with other mailbox addons |

## Open work

| Priority | Item | Value | Effort |
| --- | --- | --- | --- |
| P1 | [Verify end-to-end Forever delivery](https://github.com/LML-Studio/ForeverGoblinMailer/issues/5) | 5/5 | 2/5 |
| P2 | [Expose auction-quote freshness](https://github.com/LML-Studio/ForeverGoblinMailer/issues/6) | 4/5 | 3/5 |
| P3 | [Offer a refresh when cold item data arrives](https://github.com/LML-Studio/ForeverGoblinMailer/issues/7) | 3/5 | 2/5 |

Value measures player impact. Effort estimates implementation or verification cost, with 1 the smallest and 5 the largest. Native transfer validation takes priority because it gates the usable release. The historical subject-prefill reports remain discoverable on the v1 issue timeline. [All issues](https://github.com/LML-Studio/ForeverGoblinMailer/issues?q=is%3Aissue)

A future convenience worth exploring is a **keep quantity per ingredient** for crafting on the current character. The existing Keep rule reserves every copy of a selected item ID. A partial-stack reserve would also need safe stack splitting and a preview of exactly what stays behind.
