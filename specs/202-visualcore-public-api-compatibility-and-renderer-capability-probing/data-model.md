# Data model: R02-F02

`RenderCapabilities` (Codable, all new fields optional; missing keys decode as nil): see research R1.

`RendererRecord` (Codable, JSON in `environment.renderer`): `gl_version`, `glsl_version`, `renderer`, `vendor`,
`egl_version` (strings, optional); `max_texture_size`, `max_samples`, `max_draw_buffers`, `max_color_attachments`,
`missing_entry_points`, `generation` (ints, optional); `floor_findings` ([string], optional). Unknown keys ignored.

`FloorFinding`: `name`, `minimum`, `reported`.
