# Install and first use

**[Download ForeverMailFix.zip](https://github.com/TLDUBE/ForeverMailFix/releases/latest/download/ForeverMailFix.zip)**. The current release is **v1.1.0**, prepared for **WoW Forever**, interface **16001**.

1. Completely exit the game. Open the folder containing your Forever installation. On Windows or macOS, the relevant path ends in `World of Warcraft/_forever_`.
2. Extract the archive. Copy its **ForeverMailFix** folder to `_forever_/Interface/AddOns/`. If you extracted the ZIP directly into AddOns, the folder is already in place.
3. Check that `ForeverMailFix.toc`, `ForeverMailFix.lua`, and `Options.lua` sit together at `AddOns/ForeverMailFix/`. A second folder with the same name inside the first prevents WoW from finding the manifest.
4. Launch Forever. At character selection, open **AddOns** and enable **Forever Mail Fix** for the characters you want to use it.
5. At a mailbox, click **Send Mail**. Look for `Goblin Co. Intra-Company Transfert` in an empty subject. Try typing over it on one draft. You can check the prefill without sending any items.

**First customization.** Type `/fmf` outside combat. Set a subject such as `Guild bank materials`, click **Save**, then open an empty composition. You can also use **Settings → AddOns → Forever Mail Fix**.

### Updating

Use the newest named ZIP on [Releases](https://github.com/TLDUBE/ForeverMailFix/releases). With the client closed, replace the installed addon folder with the extracted one. WoW stores the preference separately from these three files. If you want a copy of your current preference, note the subject in `/fmf` first.

### Disabling or removing

Disable **Forever Mail Fix** in the AddOns list to stop its hooks on the next load. To remove the addon files, exit WoW and remove only `AddOns/ForeverMailFix/`. **Restore Default** in the options page resets the subject while keeping the addon installed.

[Preferences and troubleshooting](Preferences-and-troubleshooting.md) · [Verify a download](Release-integrity.md)
