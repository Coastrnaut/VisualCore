// MicroscopicAuroraLevelTests — feature 481 (R02-G19-01) T-R02G1901-002 (FR-R02G1901-001, 002, 009, 013;
// SC-R02G1901-001, 005). The level's rules (every range and rule refused by name: id, difficulty, radius, length, the
// swarm rules, swimmers outside or too fast, the stencil's size, duplicates and outside cells, threshold, coverage,
// coherence, the wells' slots, cells and strengths, the budget, an incoherent start, starting wells that already win),
// its words, and the stored form (round trip, damaged, edited, newer and older forms refused). Explicit types, plain
// loops.
import Foundation
import Testing
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraLevelTests {
    /// The first fixture, the base of every refusal case.
    static let base: MicroscopicAuroraFixture = MicroscopicAuroraFixture.all(count: 1)[0]

    /// A copy of the base level with some values changed.
    static func variant(id: String? = nil, difficulty: Int? = nil, radius: Int? = nil, length: Int? = nil,
                        rules: MicroscopicAuroraSwarmRules? = nil, swimmers: [MicroscopicAuroraSwimmer]? = nil,
                        stencil: [MicroscopicAuroraCell]? = nil, threshold: Int? = nil, coverage: Int? = nil,
                        coherence: Int? = nil, wells: [MicroscopicAuroraWell?]? = nil,
                        budget: Int? = nil) throws -> MicroscopicAuroraLevel {
        let l: MicroscopicAuroraLevel = base.level
        return try MicroscopicAuroraLevel(id: id ?? l.id, seed: l.seed, difficulty: difficulty ?? l.difficulty,
                                          radius: radius ?? l.radius, length: length ?? l.length,
                                          rules: rules ?? l.rules, swimmers: swimmers ?? l.swimmers,
                                          stencil: stencil ?? l.stencil, threshold: threshold ?? l.threshold,
                                          coverage: coverage ?? l.coverage, coherence: coherence ?? l.coherence,
                                          wells: wells ?? l.wells, budget: budget ?? l.budget)
    }

    /// Rules equal to the base's except the named values.
    static func rules(rho: Int? = nil, sigma: Int? = nil, kappa: Int? = nil, weight: Int? = nil,
                      acceleration: Int? = nil, speed: Int? = nil) -> MicroscopicAuroraSwarmRules {
        let r: MicroscopicAuroraSwarmRules = base.level.rules
        return MicroscopicAuroraSwarmRules(neighbourRadius: rho ?? r.neighbourRadius,
                                           separationRadius: sigma ?? r.separationRadius,
                                           coherenceRadius: kappa ?? r.coherenceRadius,
                                           separationWeight: weight ?? r.separationWeight,
                                           alignmentWeight: r.alignmentWeight, cohesionWeight: r.cohesionWeight,
                                           maxAcceleration: acceleration ?? r.maxAcceleration,
                                           maxSpeed: speed ?? r.maxSpeed)
    }

    /// The reason payload of a level refusal, or "none".
    static func refusal(_ build: () throws -> MicroscopicAuroraLevel) -> String {
        do {
            _ = try build()
            return "none"
        } catch let error as MicroscopicAuroraError {
            if case .level(let name) = error { return name }
            return error.reasonCode
        } catch {
            return "other"
        }
    }

    @Test func aValidLevelBuildsAndRoundTrips() throws {
        let level: MicroscopicAuroraLevel = Self.base.level
        let data: Data = level.encoded()
        let decoded: MicroscopicAuroraLevel = try MicroscopicAuroraLevel.decode(data)
        #expect(decoded == level && decoded.fingerprint == level.fingerprint)
        let json: MicroscopicAuroraLevel = try JSONDecoder().decode(MicroscopicAuroraLevel.self, from: data)
        #expect(json == level)
        #expect(level.encoded() == data)
        #expect(level.fingerprint.count == 64)
        #expect(level.stencil == level.stencil.sorted())
    }

    @Test func theWinningWellsWinAndTheStartDoesNot() {
        for fixture in MicroscopicAuroraFixture.all(count: 20) {
            #expect(!fixture.level.startReport.wins)
            let wells: [MicroscopicAuroraWell] = fixture.winning.compactMap { $0 }
            let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(fixture.level, wells: wells)
            #expect(report.wins && report.coverage == 1000 && report.groups == 1)
        }
    }

    @Test func startingWellsThatWinAreRefused() {
        #expect(Self.refusal { try Self.variant(wells: Self.base.winning) } == "already won")
    }

    @Test func everyRangeIsRefusedByName() {
        let l: MicroscopicAuroraLevel = Self.base.level
        let outside = MicroscopicAuroraSwimmer(position: MicroscopicAuroraPoint(x: 0, y: 0),
                                               velocity: MicroscopicAuroraPoint(x: 0, y: 0))
        let fast = MicroscopicAuroraSwimmer(position: l.swimmers[0].position,
                                            velocity: MicroscopicAuroraPoint(x: l.rules.maxSpeed + 1, y: 0))
        let corner = MicroscopicAuroraCell(row: 0, column: 0)
        let cases: [(String, () throws -> MicroscopicAuroraLevel)] = [
            ("id", { try Self.variant(id: "Bad Id") }),
            ("difficulty", { try Self.variant(difficulty: 6) }),
            ("radius", { try Self.variant(radius: 5) }),
            ("radius", { try Self.variant(radius: 12) }),
            ("length", { try Self.variant(length: 119) }),
            ("length", { try Self.variant(length: 481) }),
            ("neighbour radius", { try Self.variant(rules: Self.rules(rho: 7, sigma: 1)) }),
            ("separation radius", { try Self.variant(rules: Self.rules(rho: 2, sigma: 3)) }),
            ("coherence radius", { try Self.variant(rules: Self.rules(kappa: 9)) }),
            ("weight", { try Self.variant(rules: Self.rules(weight: 9)) }),
            ("acceleration", { try Self.variant(rules: Self.rules(acceleration: 1)) }),
            ("speed", { try Self.variant(rules: Self.rules(speed: 49)) }),
            ("swimmers", { try Self.variant(swimmers: Array(l.swimmers.prefix(3))) }),
            ("swimmer outside", { try Self.variant(swimmers: [outside] + l.swimmers.dropFirst()) }),
            ("swimmer speed", { try Self.variant(swimmers: [fast] + l.swimmers.dropFirst()) }),
            ("stencil", { try Self.variant(stencil: Array(l.stencil.prefix(3))) }),
            ("stencil duplicate", { try Self.variant(stencil: l.stencil + [l.stencil[0]]) }),
            ("stencil outside", { try Self.variant(stencil: l.stencil + [corner]) }),
            ("threshold", { try Self.variant(threshold: 0) }),
            ("threshold", { try Self.variant(threshold: 65) }),
            ("coverage", { try Self.variant(coverage: 499) }),
            ("coverage", { try Self.variant(coverage: 1001) }),
            ("coherence", { try Self.variant(coherence: 1) }),
            ("coherence", { try Self.variant(coherence: l.swimmers.count + 1) }),
            ("wells", { try Self.variant(wells: [nil, nil]) }),
            ("well outside", { try Self.variant(wells: [MicroscopicAuroraWell(cell: corner, strength: 1,
                                                                              sense: .clockwise), nil, nil]) }),
            ("well strength", { try Self.variant(wells: [MicroscopicAuroraWell(cell: l.stencil[0], strength: 5,
                                                                               sense: .clockwise), nil, nil]) }),
            ("wells share a cell", { try Self.variant(wells: [MicroscopicAuroraWell(cell: l.stencil[0], strength: 1,
                                                                                    sense: .clockwise),
                                                              MicroscopicAuroraWell(cell: l.stencil[0], strength: 2,
                                                                                    sense: .clockwise), nil]) }),
            ("budget", { try Self.variant(budget: 0) }),
            ("budget", { try Self.variant(budget: 25) }),
        ]
        for (name, build) in cases {
            #expect(Self.refusal(build) == name, "expected \(name)")
        }
    }

    @Test func anIncoherentStartIsRefused() {
        let l: MicroscopicAuroraLevel = Self.base.level
        var apart: [MicroscopicAuroraSwimmer] = []
        for (i, s) in l.swimmers.enumerated() {
            let x: Int = MicroscopicAuroraDish.centre + (i % 2 == 0 ? -2000 : 2000)
            apart.append(MicroscopicAuroraSwimmer(position: MicroscopicAuroraPoint(x: x, y: MicroscopicAuroraDish.centre),
                                                  velocity: s.velocity))
        }
        let rules: MicroscopicAuroraSwarmRules = Self.rules(kappa: 2)
        #expect(Self.refusal { try Self.variant(rules: rules, swimmers: apart, coherence: l.swimmers.count) }
            == "start incoherent")
    }

    @Test func theStoredFormRefusesDamage() throws {
        let data: Data = Self.base.level.encoded()
        let text: String = String(decoding: data, as: UTF8.self)
        func code(_ text: String) -> String {
            do {
                _ = try MicroscopicAuroraLevel.decode(Data(text.utf8))
                return "none"
            } catch {
                return error.reasonCode
            }
        }
        #expect(code("{") == "r02-g19.malformed")
        #expect(code(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")) == "r02-g19.newer-schema")
        #expect(code(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")) == "r02-g19.malformed")
        let budget: Int = Self.base.level.budget
        let edited: String = text.replacingOccurrences(of: "\"budget\":\(budget)",
                                                       with: "\"budget\":\(budget == 12 ? 11 : budget + 1)")
        #expect(edited != text)
        #expect(code(edited) == "r02-g19.malformed")
        #expect(code(text.replacingOccurrences(of: "\"threshold\":\(Self.base.level.threshold)",
                                               with: "\"threshold\":0")) == "r02-g19.malformed")
    }

    @Test func everythingIsNamedInWords() {
        let l: MicroscopicAuroraLevel = Self.base.level
        let well = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 7, column: 12), strength: 3,
                                         sense: .counterclockwise)
        #expect(l.wellDescription(1, well: well) == "well 2 at row 7, column 12, strength 3, counterclockwise")
        #expect(l.wellDescription(0, well: nil) == "well 1 empty")
        #expect(MicroscopicAuroraLevel.coverageWords(850) == "85.0 %")
        #expect(l.failureDescription(.exit(swimmer: 2, tick: 41)) == "swimmer 3 leaves the dish at tick 41")
        #expect(l.failureDescription(.connectedness(cell: MicroscopicAuroraCell(row: 9, column: 4)))
            == "row 9, column 4 is not joined to the pattern")
        let report: MicroscopicAuroraReport = l.startReport
        let words: String = l.progressDescription(report: report, wells: l.wells, actionsLeft: 1)
        #expect(words.contains("stencil ") && words.contains("playing now would fail") && words.hasSuffix("1 action left"))
    }
}
