# UA-F11 owner reviews (BLOCKED_OWNER_ACTION)

These items are owner-only (CLAUDE.md rule 6; spec FR-U11-090..092). The agent never performs them. Each stays
open in tasks.md (T-U11-037..039) and none blocks the UA-F11 gate. The owner records the result here with a date.

## 1. Legal review of licenses and App Store privacy answers (T-U11-037, FR-U11-090) — BLOCKED_OWNER_ACTION

1. Build the Release app: `python3 scripts/release_check.py --only app-release-build app-licenses app-privacy-manifest app-no-tracking`.
2. Read `docs/legal/third-party.json`, `docs/legal/THIRD_PARTY_NOTICES.md`, `docs/legal/lgpl-analysis.md` and the
   texts in `Build/DerivedData/release-VisualCore-Release-sim/Build/Products/Release-iphonesimulator/VisualCore.app/Licenses/`.
3. Read `privacy_answers` in `docs/release/metadata-inputs.json` ("data not collected", "no tracking", with the
   reports they come from).
4. In App Store Connect (owner sign-in only), App Privacy: answer "Data Not Collected" and no tracking, if the review
   agrees.
5. Record here: date, reviewer, approved or the changes requested. The agent never edits license texts.

## 2. Trademark and name clearance with the age rating (T-U11-038, FR-U11-091) — BLOCKED_OWNER_ACTION

1. Check the app name "VisualCore" and the 100 launch names (`docs/catalog/experience-catalog.json`, release
   `launch`) for trademark conflicts in the owner's markets.
2. Choose the age rating in App Store Connect.
3. Record here the result and any name that must change. A renamed experience keeps its id and concept (D-16).

## 3. Human distinctiveness review (T-U11-039, FR-U11-092, ADR-0009 D-17) — owner review, non-gating

1. Read `docs/legal/distinctiveness-matrix.md`. The six Round 2 close pairs come first, then the 20 highest scores.
2. Record any pair that feels too alike. The agent then redesigns the later experience inside its concept. It never
   merges, drops or replaces one.

## Record

| Date | Item | Reviewer | Result |
|---|---|---|---|
