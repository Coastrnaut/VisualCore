# Contract: Shader Studio editor, inspector and textures (A22-P03)

- **Editor:**
  - the editor shows the document with tokens coloured by `SyntaxPalette`;
  - the gutter shows lines 1…n, with a marker on each line in the person's file that carries a diagnostic;
  - the diagnostics list orders entries from outside the source first, then by line;
  - choosing an entry selects its line's start.
- **Edits and Run:** edits only call `setSource`. Run and ⌘R send `shader.run`.
- **Oversized projects:** a project past a limit gives "Refused: <code>". `compileCount` and
  `ResourceRegistry.compileCount` are unchanged, and the preview's pixels are byte-identical.
- **Inspector:** a row per live uniform, and Reset sends the defaults; values are clamped.
- **Textures:**
  - each `texture.set` choice changes the `texture-mix` picture, giving three different pictures;
  - after a context loss the picture is the same;
  - a project without texture inputs draws as in A22-P02.
- **Snapshot:** a restore gives the same template, values and textures. An A22-P02 snapshot without `textures`
  restores as `[0, 1]`.
- **Interface (`d3`):**
  - open the editor, type an error, run, see the marked line, fix and run again;
  - change a uniform in the inspector.
