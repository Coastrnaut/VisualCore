# Research: A17-P01 (feature 124)

- **D1 Content as a JSON resource** (Q3): the data is reviewable as text, versioned and loaded by the pure core.
  *Alternative:* Swift literals (rejected: harder to review and to cite line by line).
- **D2 Sources** (Q2): Gray's Anatomy (1918) is public domain; Terminologia Anatomica names are terms (facts); the
  descriptions are original plain-language writing that cites Gray. No modern atlas text is used.
- **D3 Review status** (Q2): `not-reviewed`, with the sentence "Not reviewed by a clinician."; the review is an owner
  action recorded in the content-sources document.
- **D4 Mesh declarations** (Q4): the meshes are declared now and built in A17-P02 from `MeshShapes`, so the label
  fixture holds before any geometry exists.
- **D5 No experience yet** (Q5): there is nothing real to draw until the scene exists, so no registration and no
  placeholder.
- **D6 The root** (analyze 2026-11-16): the region holds 15 structures, the root `knee.joint` and its 14 joint
  parts. The root has no layer, no meshes and no label; it groups the parts as their parent.
- **D7 A pending core** (implement 2026-11-16): `scripts/check_experience_packages.py` refused the two core targets as
  belonging to no registered experience, which contradicts Q5. The check now allows exactly one case. That case is
  `<Name>Core` and `<Name>CoreTests` of a launch-scope catalog experience of the same package, when the experience is
  not registered yet and has no `<Name>Experience` or `<Name>ExperienceTests` target. Any other unregistered target
  is still `EXTRA_TARGET`. Three fixture tests cover it: a pending core passes, a pending core with an experience
  target fails, and a core of another package or outside the launch scope fails. *Alternative:* registering a
  candidate now (rejected: Q5; there is nothing real to draw before A17-P02).
