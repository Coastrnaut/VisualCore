# Interactive Anatomy — content sources, licenses and review status

Feature 124 (A17-P01), task T-A17-106. This page records where the knee content of Interactive Anatomy (A17) comes from,
under which license each part is used, and its review status. The content itself is the bundled resource
`Packages/ExperiencesCreative/InteractiveAnatomy/Core/Content/knee-right.json` (schema 1, content version 1). The
validator `AnatomyContent.validate` refuses any source whose license is outside the allowed set.

## Allowed licenses

| License | Meaning | Used for |
|---|---|---|
| `public-domain` | The work is out of copyright | Gray's Anatomy, 20th edition (1918), cited by section |
| `facts` | Terms and facts, which are not copyrightable text | Terminologia Anatomica (1998) standard names |
| `original` | Written or made for this experience | Every description; all geometry (procedural code) |

Nothing else is allowed. No modern atlas, textbook, website or image is used, quoted or traced.

## Citations

| Citation id | Work | Section | License |
|---|---|---|---|
| `gray-1918-femur` | Anatomy of the Human Body, 20th edition (1918) | Osteology: The Femur | public-domain |
| `gray-1918-tibia` | Anatomy of the Human Body, 20th edition (1918) | Osteology: The Tibia | public-domain |
| `gray-1918-fibula` | Anatomy of the Human Body, 20th edition (1918) | Osteology: The Fibula | public-domain |
| `gray-1918-patella` | Anatomy of the Human Body, 20th edition (1918) | Osteology: The Patella | public-domain |
| `gray-1918-knee-joint` | Anatomy of the Human Body, 20th edition (1918) | Syndesmology: The Knee-joint | public-domain |
| `gray-1918-quadriceps` | Anatomy of the Human Body, 20th edition (1918) | Myology: The Quadriceps Femoris | public-domain |
| `ta-1998` | Terminologia Anatomica (1998) | Lower limb (standard names only) | facts |
| `original-descriptions` | Interactive Anatomy descriptions | All structures | original |

Every structure cites `ta-1998` for its standard name, `original-descriptions` for its description and the Gray
section where the structure is described.

## How the descriptions were written

Each description is original plain-language writing: one to three sentences of at most 400 characters about form,
position and connections only. No text was copied or paraphrased line by line from any source. Descriptions carry no
diagnostic, symptom or treatment statement; validation refuses the words diagnose, diagnosis, symptom, treatment,
treat, cure, injury advice and medical advice (reason `clinical-text`). Interactive Anatomy is educational, not medical.

## Geometry

The geometry license is `original`: every mesh is declared in the content (`mesh.<structure>.<part>` with a kind of
revolution, tube, extrusion or sphere) and built from procedural code in A17-P02. No scanned, purchased, generated or
hand-modelled mesh is used.

## Review status

| Field | Value |
|---|---|
| Status | `not-reviewed` |
| Reviewer | none |
| Date | none |
| Sentence shown | "Not reviewed by a clinician." |

**BLOCKED_OWNER_ACTION: clinical review.** A review by a qualified clinician is an owner action. Steps for the owner:
read every description in the content resource; record the reviewer's name and date; then the status may become
`reviewed` in a later content version (the review record is gap G-REVIEW, A17-P05). Until then the experience states
that the content is not reviewed by a clinician.
