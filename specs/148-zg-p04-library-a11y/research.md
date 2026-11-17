# Research: A20-P04 (feature 148)

- **D1 Library (clarification Q1):** one file per garden in `ExperienceStorage` with a counter index, as Fractal
  Explorer's bookmarks. Alternatives: `NamedLibrary` (rejected: its files sit outside the experience's storage and
  quota); all gardens in one file (rejected: one damaged byte would lose every garden).
- **D2 Bound (Q2):** an arithmetic byte bound on the encoded history, checked by a fixture; no wall-clock measure.
- **D3 Accessibility (Q3):** the ImageRenderer layout check of A19-P03 at `.accessibility5`.
- **D4 Still (Q4):** the session's still renderer and the share sheet, as Generative Art Studio; the registration's
  `photo-library-add` keeps `app-usage-descriptions` exact.
- **D5 Opening (Q5):** a restore through the shell, so the digest equals the opened document and the history restarts.
