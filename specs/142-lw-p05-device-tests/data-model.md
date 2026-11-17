# Data model: A19-P05 (feature 142)

- **Campaign row:** id LW-D1 to LW-D8; measurement; device (D1 reference iPhone on iOS 27, D2, D3 iPad on iPadOS
  26.5); procedure; threshold; status "pending device campaign".
- **`LaunchOptions` (automation only):**
  - `exportLimit(from arguments: [String]) -> Int?` reads `-lwExportLimit <n>` with n a positive integer, otherwise
    nil;
  - the presenter uses `min(context limit, n)`.
