# Testing and roadmap

The v1.1.0 release targets Forever Interface 16001. The install ZIP was compared with the source and the three installed files on **1.60.1.71037**. On November 22, 2026 the shipped source ran in a Lua 5.1 fixture with **12 passing normal-flow cases** and **three failing exploratory cases**. Real rendering, native persistence, and the end-to-end mailbox flow still need confirmation on a live client.

### Repeat the checks

From the repository root, use Python 3 and Lua 5.1:

```sh
python3 tools/verify_package.py
lua5.1 tests/run.lua
lua5.1 tests/run.lua --probe
```

The Python helper verifies the checksum, ZIP inventory and CRC, compares every file to source, and checks the TOC. The normal Lua run exercises first compose, nonempty drafts and replies, reset order, a hidden send tab, delayed APIs, absent reset support, a simulated reload, initial option values, keyboard actions, invalid saved data, combat and legacy routing. The probe command checks desired behavior at three known boundaries and intentionally exits with a failure count on this release. Fixing a probe should move its scenario into the normal suite. CI runs the package and normal-flow commands. [GitHub Actions](https://github.com/TLDUBE/ForeverMailFix/actions/workflows/verify.yml)

### Findings and triage

Scores use two 1–5 scales. **Value** estimates player benefit using impact and frequency. **Effort** estimates implementation and verification cost, from a small localized change (1) to broad integration work (5). Weighted score = 2 × value + (6 − effort). P1 is 14–15, P2 is 10–13, and P3 is 3–9. A proven critical safety or data-loss problem would override the numeric band as P0.

| Finding | Value | Effort | Score | Priority |
| --- | ---: | ---: | ---: | --- |
| [Hidden mailbox receives a subject after saving](https://github.com/TLDUBE/ForeverMailFix/issues/1) | 4 | 2 | 12 | P2 |
| [Nonbreaking-space paste looks blank](https://github.com/TLDUBE/ForeverMailFix/issues/2) | 2 | 2 | 8 | P3 |
| [Restored oversized default crosses the UI boundary](https://github.com/TLDUBE/ForeverMailFix/issues/3) | 2 | 2 | 8 | P3 |

### Native acceptance

Use your own test character and a non-sensitive subject. Record the product/build, addon version, scenario, and what you actually observed. A second tester can verify all but actual delivery without sending mail.

- [ ] Open the mailbox → Send Mail. Check the initial subject before adding an item.
- [ ] Attach and remove an item. Confirm your manually typed subject survives. Open a reply and inspect the native reply subject.
- [ ] Save a new default. Close and reopen the mailbox with an empty draft. Repeat after a normal logout and on a second character on the same account.
- [ ] Check the settings layout, keyboard controls, visible credit and UTF-8 text at your normal UI scale.
- [ ] When you choose to send a real parcel, verify the value on the next draft after a successful send.
- [ ] Check the hidden-parent sequence from issue #1 and record whether the native close/open sequence exposes it.

### Feature considerations

These are proposals for a future version. Each keeps the player's final **Send** click.

| Idea | Who benefits | What to validate first |
| --- | --- | --- |
| Two or three named subject presets | Players alternating between materials, crafted orders and gifts | Can switching take one action while the default page stays simple? |
| A character counter beside the field | Players writing long or multilingual subjects | Does it agree with the native 64-character boundary for accented and non-Latin scripts? |
| Optional per-character override | A player using one default for a bank alt and another for a crafter | Is the active scope clear, and can the player return to the account default easily? |

The first candidate is **named presets** if players frequently retype the same few subjects. The counter is the smaller alternative if boundary feedback is the more common complaint.

[Discuss an idea or report a bug](https://github.com/TLDUBE/ForeverMailFix/issues/new) · [Player handbook](Home.md)
