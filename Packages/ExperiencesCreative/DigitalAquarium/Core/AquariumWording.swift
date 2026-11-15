// AquariumWording — feature 071 (A09-P04) T-A09-404 (FR-A09-420, 421; research D4; clarification Q4). The words
// Digital Aquarium speaks about its tank, pure and host-free:
//   - ``AquariumWording/description(document:catalog:paused:)`` is the canvas description: "Digital Aquarium:
//     <habitat>, <n> fish of <k> species (<count> <name> and …), <plants>, <decor>, <food>, lighting <level>,
//     <swimming|paused>." It is the Phase 03 presenter text word for word, with each species' count added before its
//     name. Species are listed in order of first appearance; fish of species missing from the catalog are counted
//     together under "unknown".
//   - ``AquariumWordingState`` is the part of the tank whose changes are announced, and
//     ``AquariumWording/change(from:to:)`` gives the one change sentence between two states (priority: habitat, food
//     dropped, decoration added, decoration removed, paused or swimming). Food that is eaten is not announced.
import Foundation

/// The announced part of an aquarium: habitat, food and decor counts, and the motion state.
public struct AquariumWordingState: Equatable, Sendable {
    /// The starter habitat's id.
    public var habitatId: String
    /// The starter habitat's spoken name.
    public var habitatName: String
    /// The number of food pellets in the water.
    public var foodCount: Int
    /// The number of decor pieces.
    public var decorCount: Int
    /// Whether the motion is paused.
    public var paused: Bool

    /// Creates a state from all of its fields.
    public init(habitatId: String, habitatName: String, foodCount: Int, decorCount: Int, paused: Bool) {
        self.habitatId = habitatId; self.habitatName = habitatName
        self.foodCount = foodCount; self.decorCount = decorCount; self.paused = paused
    }
}

/// The spoken description of the aquarium and its change sentences.
public enum AquariumWording {
    /// The spoken names of the lighting levels 0, 1 and 2.
    public static let lightingNames = ["dim", "soft", "bright"]
    /// The name under which fish of species missing from the catalog are counted.
    public static let unknownSpecies = "unknown"

    /// The canvas description, for example "Digital Aquarium: Reef, 7 fish of 2 species (4 Orange striped fish and
    /// 3 Blue fish with yellow tail), 5 plants, 3 decorations, no food, lighting soft, swimming."
    /// - Parameters:
    ///   - document: The habitat document described.
    ///   - catalog: The catalog naming the habitat and the species.
    ///   - paused: Whether the motion is paused ("paused") or not ("swimming").
    public static func description(document: HabitatDocument, catalog: SpeciesCatalog, paused: Bool) -> String {
        let counts = speciesCounts(document, catalog: catalog)
        let species = counts.count == 1 ? "1 species" : "\(counts.count) species"
        let names = counts.map { "\($0.count) \($0.name)" }
        return "Digital Aquarium: \(habitatName(document, catalog: catalog)), \(fishWords(document.fish.count)) "
            + "of \(species) (\(joined(names))), \(plantWords(document.plants.count)), "
            + "\(decorWords(document.decor.count)), \(foodWords(document.food.count)), "
            + "lighting \(lightingName(document.lighting)), \(paused ? "paused" : "swimming")."
    }

    /// The announced state of `document`.
    /// - Parameters:
    ///   - document: The habitat document.
    ///   - catalog: The catalog naming the habitat.
    ///   - paused: Whether the motion is paused.
    public static func state(document: HabitatDocument, catalog: SpeciesCatalog, paused: Bool)
        -> AquariumWordingState {
        AquariumWordingState(habitatId: document.habitatId, habitatName: habitatName(document, catalog: catalog),
                             foodCount: document.food.count, decorCount: document.decor.count, paused: paused)
    }

    /// The change sentence from `old` to `new`, or nil when `old` is nil (the first state only sets the reference)
    /// or nothing announced changed. One sentence, by priority: "Habitat <name>" when the habitat id changed;
    /// "Food dropped" when the food count rose; "Decoration added" or "Decoration removed" when the decor count rose
    /// or fell; "Paused" or "Swimming" when the motion state changed. A falling food count (eaten or sunk) is silent.
    public static func change(from old: AquariumWordingState?, to new: AquariumWordingState) -> String? {
        guard let old else { return nil }
        if old.habitatId != new.habitatId { return "Habitat \(new.habitatName)" }
        if new.foodCount > old.foodCount { return "Food dropped" }
        if new.decorCount > old.decorCount { return "Decoration added" }
        if new.decorCount < old.decorCount { return "Decoration removed" }
        if new.paused != old.paused { return new.paused ? "Paused" : "Swimming" }
        return nil
    }

    // MARK: - Word helpers

    /// The name of `document`'s starter habitat ("Aquarium" for an index outside the catalog's habitats).
    public static func habitatName(_ document: HabitatDocument, catalog: SpeciesCatalog) -> String {
        let habitats = catalog.habitats
        return habitats.indices.contains(document.habitatIndex) ? habitats[document.habitatIndex].name : "Aquarium"
    }

    /// The species of `document` with their fish counts, in order of first appearance; fish of species missing from
    /// the catalog are counted together under ``unknownSpecies``, placed where the first of them appears.
    public static func speciesCounts(_ document: HabitatDocument, catalog: SpeciesCatalog)
        -> [(name: String, count: Int)] {
        var names: [String] = []
        var counts: [String: Int] = [:]
        for fish in document.fish {
            let name = catalog.species(id: fish.speciesId)?.name ?? unknownSpecies
            if counts[name] == nil { names.append(name) }
            counts[name, default: 0] += 1
        }
        return names.map { (name: $0, count: counts[$0] ?? 0) }
    }

    /// "1 fish" or "7 fish".
    public static func fishWords(_ count: Int) -> String { "\(count) fish" }

    /// "1 plant" or "5 plants".
    public static func plantWords(_ count: Int) -> String { count == 1 ? "1 plant" : "\(count) plants" }

    /// "1 decoration" or "4 decorations".
    public static func decorWords(_ count: Int) -> String { count == 1 ? "1 decoration" : "\(count) decorations" }

    /// "no food", "1 food pellet" or "3 food pellets".
    public static func foodWords(_ count: Int) -> String {
        switch count {
        case 0: return "no food"
        case 1: return "1 food pellet"
        default: return "\(count) food pellets"
        }
    }

    /// The spoken name of the lighting level `level` ("soft" for a level outside 0…2).
    public static func lightingName(_ level: Int) -> String {
        lightingNames.indices.contains(level) ? lightingNames[level] : lightingNames[1]
    }

    /// The names joined with commas and "and": "A", "A and B", "A, B and C" ("" for none).
    public static func joined(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
