// AmbientControls — feature 132 T-A18-203 (FR-A18-202, FR-A18-207; G-OVERLAY; clarification Q2). The native controls
// of Ambient Clock, modelled on Interactive Anatomy's: the hour-cycle menu (`hour-cycle`: System, 12-hour, 24-hour),
// the seconds toggle (`seconds`) and the date toggle (`date`), which send `clock.format [cycle, seconds, date]`; the
// motion toggle (`motion` → `theme.motion [0 / 1]`) and the speed slider (`speed` → `theme.speed [0.25…2]`). Each
// sends only when its value changes, reads the presenter's mirror, has an accessible label, value and hint, and the
// identifier `experience.a18.ambient-clock.<name>` (`ExperienceActionPort.identifier`).
//
// Feature 133 (A18-P03) T-A18-304, T-A18-306 (FR-A18-301, FR-A18-304, FR-A18-305; G-THEMES/G-FAVOURITES): the theme
// menu (`theme`: the four names of `ThemeCatalog.themes` → `theme.select [0…3]`) and the palette menu (`palette`: the
// theme's three palette names → `theme.palette [0…2]`); then, when the presenter has favourites (the app always
// gives it the experience storage's `favourites.json`), the favourites: a name field (`favourite-name`), a Save
// button (`favourite-save`, saving what the controls show through `AmbientFavourites.save(name:preset:)` and showing
// a refusal's sentence) and one Apply button per favourite (`favourite-<index>`, in list order, applying it through
// `AmbientFavourites.apply(id:port:)`); the sentence of a file problem is shown above the list.
//
// Feature 134 (A18-P04) T-A18-404/406 (FR-A18-401, FR-A18-403, FR-A18-406, FR-A18-407; G-NIGHT/G-MOTION/
// G-SCREENCARE/G-AWAKE; clarifications Q2, Q3): the night-mode menu (`night-mode`: Off, On, Scheduled →
// `night.mode [0…2]`), the window's start and end steppers (`night-start`, `night-end`: 15-minute steps over the day,
// shown as HH:MM → `night.window [start, end]`), the night dim slider (`night-dim` → `night.dim [0.3…1]`), the reduced
// motion toggle (`reduce-motion` → `motion.reduce [0 / 1]`) and the keep-awake toggle (`keep-awake`, "Keep the screen
// on while the clock is open" → `screen.keepAwake [0 / 1]`). Every send of a control and every favourite applied or
// saved first calls `AmbientPresenter.noteAction()`, which ends the idle dim (the ticks never do).
import AmbientClockCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The native controls of Ambient Clock (see the file header).
struct AmbientControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: AmbientMirror
    /// The presenter the format goes through.
    let presenter: AmbientPresenter
    /// The saved favourites; nil only for a presenter made without storage (tests), and the section is then not shown.
    let favourites: AmbientFavourites?
    /// The name typed for the next favourite.
    @State private var favouriteName = ""
    /// The sentence of the last save (a refusal or "Saved <name>."), shown under the Save button.
    @State private var saveMessage: String?

    /// The titles of the hour cycles, by index: "System", "12-hour", "24-hour".
    static let hourCycleTitles = ["System", "12-hour", "24-hour"]

    /// The titles of the night modes, by index: "Off", "On", "Scheduled".
    static let nightModeTitles = ["Off", "On", "Scheduled"]
    /// The step of the night window's steppers, minutes.
    static let windowStep = 15

    /// A minute of the day (wrapped into 0…1439) as "HH:MM": 1,320 → "22:00", 420 → "07:00".
    static func minuteWords(_ minute: Int) -> String {
        let m = ((minute % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    /// The night dim in words: "Night dim 50 percent".
    static func dimWords(_ dim: Double) -> String {
        "Night dim " + String(format: "%.0f", dim * 100) + " percent"
    }

    /// The speed in words: "Speed 1.25 times".
    static func speedWords(_ speed: Double) -> String {
        "Speed " + String(format: "%.2f", speed) + " times"
    }

    /// The controls.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Ambient Clock").font(.headline).accessibilityAddTraits(.isHeader)
            hourCyclePicker
            toggle("Seconds", name: "seconds", isOn: mirror.showSeconds, hint: "Shows the seconds") { on in
                sendFormat(showSeconds: on)
            }
            toggle("Date", name: "date", isOn: mirror.showDate, hint: "Shows the date below the time") { on in
                sendFormat(showDate: on)
            }
            toggle("Motion", name: "motion", isOn: mirror.motion, hint: "Moves the background slowly") { on in
                send("theme.motion", [on ? 1 : 0])
            }
            speedSlider
            themePicker
            palettePicker
            nightModePicker
            windowStepper("Night starts", name: "night-start", minute: mirror.nightStart,
                          hint: "Sets when scheduled night mode begins") { minute in
                send("night.window", [Double(minute), Double(mirror.nightEnd)])
            }
            windowStepper("Night ends", name: "night-end", minute: mirror.nightEnd,
                          hint: "Sets when scheduled night mode ends") { minute in
                send("night.window", [Double(mirror.nightStart), Double(minute)])
            }
            nightDimSlider
            toggle("Reduce motion", name: "reduce-motion", isOn: mirror.reduceMotion,
                   hint: "Keeps the background still and the clock in place") { on in
                send("motion.reduce", [on ? 1 : 0])
            }
            toggle("Keep the screen on while the clock is open", name: "keep-awake", isOn: mirror.keepAwake,
                   hint: "Stops the screen from turning off while the clock is shown") { on in
                send("screen.keepAwake", [on ? 1 : 0])
            }
            if let favourites { favouritesSection(favourites) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The names of the four themes, by index.
    static var themeTitles: [String] { ThemeCatalog.themes.map(\.name) }

    /// The names of the three palettes of theme `theme` (clamped), by index.
    static func paletteTitles(theme: Int) -> [String] {
        ThemeCatalog.themes[min(max(theme, 0), ThemeCatalog.themes.count - 1)].palettes.map(\.name)
    }

    /// The theme menu (sends `theme.select` when the choice changes).
    private var themePicker: some View {
        let titles = Self.themeTitles
        let current = min(max(mirror.theme, 0), titles.count - 1)
        return menu("Theme", name: "theme", titles: titles, current: current,
                    hint: "Chooses the moving background") { index in
            send("theme.select", [Double(index)])
        }
    }

    /// The palette menu of the current theme (sends `theme.palette` when the choice changes).
    private var palettePicker: some View {
        let titles = Self.paletteTitles(theme: mirror.theme)
        let current = min(max(mirror.palette, 0), titles.count - 1)
        return menu("Palette", name: "palette", titles: titles, current: current,
                    hint: "Chooses the colours of the background") { index in
            send("theme.palette", [Double(index)])
        }
    }

    /// The night-mode menu (sends `night.mode` when the choice changes).
    private var nightModePicker: some View {
        let titles = Self.nightModeTitles
        let current = min(max(mirror.nightMode, 0), titles.count - 1)
        return menu("Night mode", name: "night-mode", titles: titles, current: current,
                    hint: "Dims the background and warms the colours: off, always or on a schedule") { index in
            send("night.mode", [Double(index)])
        }
    }

    /// A stepper titled `title` over the minutes of the day in steps of `windowStep`, wrapping at midnight, showing
    /// HH:MM, calling `change` with the new minute.
    private func windowStepper(_ title: String, name: String, minute: Int, hint: String,
                               change: @escaping @MainActor (Int) -> Void) -> some View {
        let words = Self.minuteWords(minute)
        return Stepper {
            Text(verbatim: title + " " + words).font(.body).fixedSize(horizontal: false, vertical: true)
        } onIncrement: {
            change((minute + Self.windowStep) % 1440)
        } onDecrement: {
            change((minute - Self.windowStep + 1440) % 1440)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: words))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// The night dim slider, 0.3…1 (sends `night.dim` when the value changes).
    private var nightDimSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Self.dimWords(mirror.nightDim)).font(.body)
            Slider(value: Binding(get: { mirror.nightDim },
                                  set: { value in
                                      guard value != mirror.nightDim else { return }
                                      send("night.dim", [value])
                                  }),
                   in: NightPolicy.dimRange)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Night dim"))
                .accessibilityValue(Text(verbatim: Self.dimWords(mirror.nightDim)))
                .accessibilityHint(Text(verbatim: "Sets how bright the background stays at night"))
                .accessibilityIdentifier(port.identifier("night-dim"))
        }
    }

    /// Notes a person's action on the presenter (ending the idle dim), then sends `control` with `values`.
    @discardableResult
    private func send(_ control: String, _ values: [Double]) -> ActionResult {
        presenter.noteAction()
        return port.send(control, values)
    }

    /// A menu titled `title` with the identifier name `name` over `titles`, calling `send` only when the choice
    /// changes.
    private func menu(_ title: String, name: String, titles: [String], current: Int, hint: String,
                      send: @escaping @MainActor (Int) -> Void) -> some View {
        Picker(selection: Binding(get: { current },
                                  set: { index in
                                      guard index != current else { return }
                                      send(index)
                                  })) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, text in
                Text(verbatim: text).tag(index)
            }
        } label: {
            Text(verbatim: title)
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: titles.indices.contains(current) ? titles[current] : ""))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// The favourites: the name field, the Save button with its message and one Apply button per favourite.
    private func favouritesSection(_ favourites: AmbientFavourites) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Favourites").font(.headline).accessibilityAddTraits(.isHeader)
            TextField(text: $favouriteName) { Text(verbatim: "Favourite name") }
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Favourite name"))
                .accessibilityHint(Text(verbatim: "Names the favourite to save; empty gives a numbered name"))
                .accessibilityIdentifier(port.identifier("favourite-name"))
            Button {
                saveFavourite(favourites)
            } label: {
                Text(verbatim: "Save favourite").frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Save favourite"))
            .accessibilityHint(Text(verbatim: "Saves the theme, palette, speed and motion as a favourite"))
            .accessibilityIdentifier(port.identifier("favourite-save"))
            if let saveMessage {
                Text(verbatim: saveMessage).font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(favourites.problems.enumerated()), id: \.offset) { _, problem in
                Text(verbatim: problem.sentence).font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(favourites.entries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    presenter.noteAction()
                    favourites.apply(id: entry.id, port: port)
                } label: {
                    Text(verbatim: entry.name).frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel(Text(verbatim: "Apply " + entry.name))
                .accessibilityValue(Text(verbatim: Self.presetWords(entry.preset)))
                .accessibilityHint(Text(verbatim: "Applies this favourite's theme, palette, speed and motion"))
                .accessibilityIdentifier(port.identifier("favourite-\(index)"))
            }
        }
    }

    /// A preset in words: "Wave Field, Deep Sea, speed 1.00 times, moving" (or "still").
    static func presetWords(_ preset: ThemePreset) -> String {
        let theme = ThemeCatalog.themes[min(max(preset.theme, 0), ThemeCatalog.themes.count - 1)]
        let palette = ThemeCatalog.palette(theme: preset.theme, palette: preset.palette)
        return theme.name + ", " + palette.name + ", " + speedWords(preset.speed).lowercased() + ", "
            + (preset.motion ? "moving" : "still")
    }

    /// Saves what the controls show under the typed name; on success the field is cleared.
    private func saveFavourite(_ favourites: AmbientFavourites) {
        presenter.noteAction()
        guard let preset = presenter.currentPreset else {
            saveMessage = "The current theme cannot be saved."
            return
        }
        switch favourites.save(name: favouriteName, preset: preset) {
        case .success(let entry):
            saveMessage = "Saved " + entry.name + "."
            favouriteName = ""
        case .failure(let refusal):
            saveMessage = refusal.sentence
        }
    }

    /// The hour-cycle menu (sends `clock.format` when the choice changes).
    private var hourCyclePicker: some View {
        let current = min(max(mirror.hourCycle, 0), Self.hourCycleTitles.count - 1)
        return Picker(selection: Binding(get: { current },
                                         set: { cycle in
                                             guard cycle != mirror.hourCycle else { return }
                                             sendFormat(hourCycle: cycle)
                                         })) {
            ForEach(Array(Self.hourCycleTitles.enumerated()), id: \.offset) { index, title in
                Text(verbatim: title).tag(index)
            }
        } label: {
            Text(verbatim: "Hour cycle")
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Hour cycle"))
        .accessibilityValue(Text(verbatim: Self.hourCycleTitles[current]))
        .accessibilityHint(Text(verbatim: "Chooses the system, 12-hour or 24-hour clock"))
        .accessibilityIdentifier(port.identifier("hour-cycle"))
    }

    /// The speed slider, 0.25…2 (sends `theme.speed` when the value changes).
    private var speedSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Self.speedWords(mirror.speed)).font(.body)
            Slider(value: Binding(get: { mirror.speed },
                                  set: { value in
                                      guard value != mirror.speed else { return }
                                      send("theme.speed", [value])
                                  }),
                   in: AmbientCore.speedRange)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: "Speed"))
                .accessibilityValue(Text(verbatim: Self.speedWords(mirror.speed)))
                .accessibilityHint(Text(verbatim: "Sets how fast the background moves"))
                .accessibilityIdentifier(port.identifier("speed"))
        }
    }

    /// A toggle titled `title` with the identifier name `name`, calling `send` only when the choice changes.
    private func toggle(_ title: String, name: String, isOn: Bool, hint: String,
                        send: @escaping @MainActor (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn },
                             set: { on in
                                 guard on != isOn else { return }
                                 send(on)
                             })) {
            Text(verbatim: title).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: isOn ? "On" : "Off"))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// Sends `clock.format` with the mirror's format, changed by the given values.
    private func sendFormat(hourCycle: Int? = nil, showSeconds: Bool? = nil, showDate: Bool? = nil) {
        presenter.noteAction()
        presenter.setFormat(hourCycle: hourCycle ?? mirror.hourCycle, showSeconds: showSeconds ?? mirror.showSeconds,
                            showDate: showDate ?? mirror.showDate, port: port)
    }
}
