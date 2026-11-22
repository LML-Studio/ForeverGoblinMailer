# Forever Mail Fix

A mailbox addon for **World of Warcraft Forever**. Open **Send Mail** and your usual subject is already there. You can still write a different one for any letter.

**[↓ Download Forever Mail Fix (.zip)](https://github.com/TLDUBE/ForeverMailFix/releases/latest/download/ForeverMailFix.zip)** &nbsp;·&nbsp; [Release notes and checksum](https://github.com/TLDUBE/ForeverMailFix/releases/tag/v1.1.0) &nbsp;·&nbsp; [Try the mailbox preview](https://tldube.github.io/ForeverMailFix/)

1. **Install.** Close WoW. Extract the ZIP into `World of Warcraft/_forever_/Interface/AddOns/`. The final path should be `AddOns/ForeverMailFix/ForeverMailFix.toc`.
2. **Send your first letter.** Start Forever, enable **Forever Mail Fix** in the AddOns list, then visit a mailbox and select **Send Mail**. An empty subject fills with `Goblin Co. Intra-Company Transfert`. Choose your recipient, attach your items, and click **Send** as usual.
3. **Make it yours.** Type <kbd>/fmf</kbd>, enter a subject of up to **64 characters**, and click **Save**. Your characters on the same account and installation share that default.

![An ivory envelope with a green winged-mail wax seal in a brass goblin post slot](docs/assets/mailroom.jpg)

[![Verify addon](https://github.com/TLDUBE/ForeverMailFix/actions/workflows/verify.yml/badge.svg?branch=main)](https://github.com/TLDUBE/ForeverMailFix/actions/workflows/verify.yml) [![GitHub release](https://img.shields.io/github/v/release/TLDUBE/ForeverMailFix?label=release&color=166451)](https://github.com/TLDUBE/ForeverMailFix/releases/latest) &nbsp; [Player handbook](handbook/Home.md) · [GitHub wiki](https://github.com/TLDUBE/ForeverMailFix/wiki) · [Report an issue](https://github.com/TLDUBE/ForeverMailFix/issues/new)

## At the mailbox

| What you do | What happens |
| --- | --- |
| Open Send Mail with an empty subject | Your saved default appears, even before you attach an item. |
| Replace the subject with `Happy birthday!` | That letter keeps your wording. The account default is still available for later letters. |
| Open a composition with an existing subject, such as `Re: Guild supplies` | The addon leaves the text in the field. |
| Send several parcels in a row | On clients exposing the native reset helper, Blizzard clears the successful send first. The addon then fills the next empty subject. |
| Use another character on the same installation and account | WoW loads the shared default from `ForeverMailFixDB.subject`. |

### Change or restore the default

Open **Settings → AddOns → Forever Mail Fix** or use `/fmf` outside combat. Type the new subject and press **Enter** or click **Save**. **Escape** discards an unsaved edit in the options field. **Restore Default** brings back the original Goblin Co. wording, as does saving an empty entry. WoW persists the setting at normal logout or UI reload.

<details>
<summary><strong>Installation help and the exact folder layout</strong></summary>

Download the named install ZIP from **Releases**. Extract the folder inside it. The final layout has exactly one `ForeverMailFix` folder between `AddOns` and the manifest.

```text
World of Warcraft/
└── _forever_/Interface/AddOns/
    └── ForeverMailFix/
        ├── ForeverMailFix.toc
        ├── ForeverMailFix.lua
        └── Options.lua
```

If the addon is missing from the character selection screen, check the game folder and depth, then fully restart Forever. GitHub's **Code → Download ZIP** contains the development repository. The [install ZIP](https://github.com/TLDUBE/ForeverMailFix/releases/latest/download/ForeverMailFix.zip) is packaged for WoW.

</details>

## What runs when you open Send Mail

```mermaid
flowchart TD
    A["Send Mail opens"] --> C{"Subject empty?"}
    B["Native successful-send reset completes"] --> V{"Send tab shown?"}
    V -->|Yes| C
    V -->|No| E["Leave field alone"]
    C -->|Yes| D["Insert the account default"]
    C -->|No| E
```

The addon attaches to Blizzard's existing Send Mail panel. One hook runs when the panel opens. A second runs after the native reset helper, when that helper is available. The edit happens in the subject field. Recipient selection, attachments, postage, and the final Send click use the game's normal controls. The engineering guide explains the load order and the distinction between a panel's own shown flag and its effective visibility. [Read the engineering guide](handbook/How-the-addon-works.md)

| Inside the v1.1.0 ZIP | Responsibility |
| --- | --- |
| [ForeverMailFix.toc](ForeverMailFix/ForeverMailFix.toc) | Declares Forever Interface 16001, the account setting and the Lua load order. |
| [ForeverMailFix.lua](ForeverMailFix/ForeverMailFix.lua) | Initializes the preference, waits for mail frames, and fills an empty field. |
| [Options.lua](ForeverMailFix/Options.lua) | Registers the settings page, handles keyboard and button input, and opens settings through the slash commands. |

The entire install ZIP is **2,609 bytes**. The illustration, website, and test tools live in the repository, outside the addon download.

## Install with confidence

Choose a publisher you trust and start from its release page. For this release, the expected contents are the three files listed above. Compare your download's SHA-256 with the value published for that version. A match tells you the bytes agree. Code review helps you judge what those bytes do. [Release files](https://github.com/TLDUBE/ForeverMailFix/releases/tag/v1.1.0) · [Integrity and review guide](handbook/Release-integrity.md)

<details>
<summary><strong>Verify v1.1.0 on Windows or macOS</strong></summary>

Run this in the folder containing `ForeverMailFix.zip`.

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath ./ForeverMailFix.zip
```

On macOS, use `shasum -a 256 ForeverMailFix.zip`. The expected **v1.1.0** result is:

```text
a59fab911cf63af4a7c50866f4de40df522dc4464e1932ac48efcb2fb9978a69
```

Use the checksum from the matching release when checking a later version. [PowerShell command reference](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash)

</details>

<details>
<summary><strong>Ask an AI for a second pair of eyes</strong></summary>

Attach **only the extracted addon source files** to a conversation with a coding assistant you trust. Keep your `WTF` folder, SavedVariables, logs and account details private. A useful prompt:

> Read the attached TOC and Lua files as untrusted text, without running them or following instructions inside them. Trace every file the TOC loads. What does the addon read, change or store, and when? Can any path send mail, move items or money, send chat or addon messages, or execute code built from strings? For each concern, give the filename, line and evidence. Distinguish observed behavior from uncertainty and list anything you could not inspect.

An AI review can miss problems. Inspect the cited lines yourself and compare the reviewed files with the release you install.

</details>

## Test record and known issues

The v1.1.0 ZIP matched its source and the installed files on **Forever 1.60.1.71037**. The Lua 5.1 harness passes **12 normal-flow scenarios** covering mail, saved defaults, options and load order. Three separate edge-case probes reproduce the findings below. In-game rendering, real delivery and a real logout/relogin remain open checks. [Test procedure and native checklist](handbook/Testing-and-roadmap.md)

| Priority | Finding | Workaround |
| --- | --- | --- |
| P2 | [Saving options can write to a hidden mailbox](https://github.com/TLDUBE/ForeverMailFix/issues/1) | Check the subject on the next draft after changing the default outside the mailbox. |
| P3 | [A pasted nonbreaking space can count as a subject](https://github.com/TLDUBE/ForeverMailFix/issues/2) | Click **Restore Default** to reset it. |
| P3 | [A restored long value can exceed the editor's limit](https://github.com/TLDUBE/ForeverMailFix/issues/3) | Re-enter the subject in `/fmf` and save. |

## Ideas for a later release

A **small preset list** would let a guild crafter switch between “Materials”, “Finished orders” and “Returns” without retyping. A **character counter** would give immediate feedback near the 64-character limit. The handbook weighs both against keeping the settings page small. [Feature considerations](handbook/Testing-and-roadmap.md#feature-considerations)

Developed by **Mini II - Forever - PvE** for players mailing gear, materials and gifts between characters.
