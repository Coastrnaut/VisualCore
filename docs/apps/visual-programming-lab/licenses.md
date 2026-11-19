# Visual Programming Lab — licenses and provenance (A23-P04, feature 169)

Everything Visual Programming Lab ships is code written for this repository. No image file, stored texture, font file,
model, sound file, generated asset or third-party asset is bundled. A person's own graphs are their own work and stay
on the device, in the experience's own storage.

| Content | Source | License |
|---|---|---|
| Example graphs `clouds`, `soft-gradient`, `mixed-clouds` (`Experience/LabExamples.swift`: nodes, parameters, positions and connections in Swift) | written for VisualCore (A23-P04) | original, the repository's license |
| Node kinds Time, Constant, Noise, Gradient, Mix, Blur and Output with their ports and parameter ranges (`Core/NodeLibrary.swift`) | written for VisualCore (A23-P01); names and numbers only | original, the repository's license |
| Preview operators `noise`, `gradient`, `mix`, `blur`, `output` (GLSL ES 3.00 fragment sources, `Experience/Operators.swift`) | written for VisualCore (A23-P03) over VisualCore's GLSL library `vc/` | original, the repository's license |
| Canvas grid (`Experience/GridScene.swift`, a VisualCore full-screen field pass) | written for VisualCore (A23-P02) | original, the repository's license |
| Graph file `a23.visual-graph`, saved-graph file `a23.saved-graph` and library index `a23.graph-library` formats; the committed sample `ExperienceTests/Fixtures/graph-sample.json` | written for VisualCore (A23-P01, A23-P04); written by the experience's own encoder | original, the repository's license |
| GLSL library `vc/` (hashes, gradient noise, fbm, colour) | VisualCore (`Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/`) | the repository's license |

Node boxes, ports and wires are native views drawn with the system's fonts. Nothing is downloaded.
