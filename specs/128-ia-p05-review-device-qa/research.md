# Research: A17-P05 (feature 128)

- **D1 A separate review record** (Q1). Reviewing must never edit the reviewed text. The record therefore lives beside
  the pack and is bound to its content version, so a content change makes an old review invalid.
- **D2 Editorial, not clinical** (Q2). The engineer can check text against the cited public-domain sources. A
  clinical review needs a qualified person and stays BLOCKED_OWNER_ACTION. The record's kinds keep the two apart, and
  validation refuses a clinical entry without a named reviewer.
- **D3 A failing record degrades, it does not block** (plan: lifecycle). The content stays usable and every part shows
  the not-reviewed label, which is the safe default.
- **D4 The VoiceOver fixture at the experience level** (Q5). The list's actions and row model are what VoiceOver
  operates, so driving all 14 parts through them without pointer events proves the fixture without a device. The UI
  test of the real list comes in A17-P06.
- **D5 Stricter entry rules, as built** (converge 2026-11-16). A review entry may name only one of the 14 parts, not
  the root `knee.joint`, which has no text of its own to review. Its sources must be among that part's own
  citations, because a review checks the text against what the text cites. The record also offers `isISODate`,
  `entries(for:)` and `maxBytes`, which is 65,536 bytes (`too-large` above it).
