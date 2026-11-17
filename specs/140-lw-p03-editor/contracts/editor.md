# Contract: Living Wallpapers editor (A19-P03)

- **Colours:**
  - each slot edit changes the drawn picture;
  - `preset.reset` returns the preset's pixels exactly;
  - an out-of-range component or a wrong value count is refused and changes nothing;
  - a scene or preset change clears the edit.
- **Schemas:**
  - a stored schema-1 snapshot restores as schema 2 with `custom` 0;
  - a schema-1 project decodes with `customColors` nil;
  - newer schemas are refused;
  - the registry's migration check passes with the schema-1 example.
- **Notice:** for limits of 2048, 4096 and 8192, every template above the limit gets a notice with its size, the
  limit and the offered size, and every fitting template gets none. With a limit of 0 the notice is "Open a picture to
  export it."
- **Result line:** the line names the format, the read-back width × height and "sRGB".
- **Help:** it is reachable from the editor and the result. The platform scan and `scan-help-claims.sh` pass.
- **Accessibility:**
  - every control has a non-empty label with its value;
  - one announcement per export outcome;
  - at accessibility-five no control is wider than the canvas.
