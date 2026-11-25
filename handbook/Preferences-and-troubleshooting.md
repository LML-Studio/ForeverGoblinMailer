# Preferences and troubleshooting

## Address book and item rules

Use **Setup** on the character you are enrolling. The name comes from Forever’s full-name helper and includes the native surname separator. Enrolling again updates the selected role. **Remove** releases a role held by the current character after a second click. The Dispatch page shows all enrolled destinations.

For shared ingredients, paste an item link or enter a numeric item ID in **Item rule**, select a profession, **Auction alt**, or **Keep in bags**, then **Save rule**. Choose **Automatic** to remove that override. Rules apply to all matching item IDs on the same realm and faction. One character can own more than one profession. An item already on its destination character stays there.

## Auction stock

The default floor is **5 gold per unit**. Change it under **Auction floor per item (gold)**. Auctionator supplies an optional cached item-link quote for eligible weapons, armor, recipes and miscellaneous items. A stack of twenty items valued at 30s each stays under a 5g per-unit floor. A missing quote holds the item. For a specific collectible or item outside those groups, set an explicit Auction rule. Check your market before mailing stock. [Quote-age tracking](https://github.com/LML-Studio/ForeverGoblinMailer/issues/6)

## Gold and optional material returns

| Alt setting | Opening a mailbox | Choosing Materials to main |
| --- | --- | --- |
| Automatic gold on, materials off | Gold only after eight seconds | Reviewed materials with surplus on the final letter |
| Automatic gold on, materials on | Materials and surplus after eight seconds | The same batch can be reviewed first |
| Automatic gold off | Waits for a mailbox action | Reviewed materials only. **Gold to main** is available separately. |

The one-gold reserve also applies to postage on material-only letters. At exactly 1g there is no postage available for another parcel. If you plan to send materials, combine them with the gold trip, or choose **Materials to main** during the countdown. **Keep** and explicit **Auction** rules are respected on the return. Gold-only mail will send the surplus after actual postage.

## What to do when a parcel stops

| Panel message or symptom | What to check |
| --- | --- |
| No active route buttons | Check your current character’s role, enrolled main, realm and faction. Close combat and reopen the mailbox. |
| No address / choose a profession rule | Enroll the destination on that character, or assign the shared material by item ID. |
| Item data pending | Wait for the tooltip to load and run the review again. |
| Current draft is in use | Finish or clear your own draft. A reply, COD, money, cursor item or existing attachment prevents starting. |
| Stack changed or pickup refused | Check the bag slot, cursor and native draft. Rebuild the review after clearing the draft. |
| Insufficient postage | Add funds or reduce the shipment. The sender keeps at least one gold on every profession-alt parcel. |
| Unconfirmed send | Inspect the original sender, native draft and recipient inbox. Allow for delivery delay. Only after reconciling the parcel, use **Setup → Clear delivery hold** twice and start a fresh review. |

Closing the mailbox or entering combat cancels the remaining queue. Native attachments already moved to a draft may still be present. A server-accepted parcel is already on its way.
