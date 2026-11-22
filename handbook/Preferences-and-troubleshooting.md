# Preferences and troubleshooting

| Control | Result |
| --- | --- |
| `/fmf` or `/forevermailfix` | Opens the game's addon settings outside combat. |
| **Default subject** | Lets you enter up to 64 characters using the native edit box. |
| **Save** or **Enter** | Stores the draft value as the account default. The next empty subject uses it. |
| **Escape** in the edit box | Discards the unsaved edit and displays the saved value. |
| **Restore Default** | Restores `Goblin Co. Intra-Company Transfert`. Saving a genuinely empty value also restores it. |

A manual edit to the subject **in the mailbox** affects that draft. Only saving through **options** changes the shared setting. WoW persists `ForeverMailFixDB.subject` for the account at normal logout or UI reload.

### The addon is missing from the list

Check the exact folder depth, the `_forever_` client folder and the presence of the TOC. Restart the client after installing a new addon folder. Download the named release asset if your extracted folder contains a website and tests. [Install and first use](Install-and-first-use.md)

### The subject did not change

Open **Send Mail** and inspect an empty draft. An existing subject, including a reply, is intentionally preserved. If the old default appears after editing it between mailbox visits, see the [hidden panel finding](https://github.com/TLDUBE/ForeverMailFix/issues/1). The recipient and item attachments do not decide which default is used.

### My default looks blank or is too long

A nonbreaking space copied on its own can look empty. **Restore Default**, then enter your desired text. For a manually restored long value, type the desired subject in the options page and save again. [Whitespace finding](https://github.com/TLDUBE/ForeverMailFix/issues/2) · [Length finding](https://github.com/TLDUBE/ForeverMailFix/issues/3)

### Settings did not open during combat

Wait for combat to end and type `/fmf` again. You can always navigate through **Settings → AddOns** if the native menu is available.

### Reporting a problem

Give the Forever build, addon version, whether the subject began empty, and the order of tab changes, setting changes, and sends. Use a harmless example subject. If you attach a screenshot, redact recipients, mail contents and character or account information you do not want to publish. [Open an issue](https://github.com/TLDUBE/ForeverMailFix/issues/new)
