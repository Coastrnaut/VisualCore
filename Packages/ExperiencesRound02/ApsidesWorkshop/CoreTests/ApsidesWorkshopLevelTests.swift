// ApsidesWorkshopLevelTests — feature 471 (R02-G18-01) T-R02G1801-002 (FR-R02G1801-001, 002, 009, 013;
// SC-R02G1801-001, 005). The level's rules (every range and rule refused by name: id, difficulty, period, planets and
// their centres, radii and distance from the star, targets, sectors, bands, reversed bands, duplicates, the starting
// orbit, the budget, a starting orbit that already wins), its words, and the stored form (round trip, damaged, edited,
// newer and older forms refused). Explicit types, plain loops.
import Foundation
import Testing
@testable import ApsidesWorkshopCore

@Suite struct ApsidesWorkshopLevelTests {
    /// The winning orbit of the sample: size 24, eccentricity 0.25, periapsis at 0°.
    static let winning = ApsidesWorkshopOrbit(size: 24, eccentricity: 5, direction: 0)

    /// A small valid level: one target, the periapsis in sector 0 at 18.00 … 18.00 units (a(20 − k) = 360); the
    /// starting orbit points its periapsis at 90° (sector 2), so it does not win at load.
    static func sample(orbit: ApsidesWorkshopOrbit = ApsidesWorkshopOrbit(size: 24, eccentricity: 5, direction: 6),
                       planets: [ApsidesWorkshopPlanet] = [], targets: [ApsidesWorkshopTarget]? = nil,
                       period: Int = 24, budget: Int = 3) throws -> ApsidesWorkshopLevel {
        let defaultTargets: [ApsidesWorkshopTarget] = [ApsidesWorkshopTarget(kind: .periapsis, sector: 0, low: 360,
                                                                             high: 360)]
        return try ApsidesWorkshopLevel(id: "sample", seed: 0, difficulty: 1, period: period, planets: planets,
                                        targets: targets ?? defaultTargets, orbit: orbit, budget: budget)
    }

    /// The reason payload of a level refusal, or "none".
    static func refusal(_ build: () throws -> ApsidesWorkshopLevel) -> String {
        do {
            _ = try build()
            return "none"
        } catch let error as ApsidesWorkshopError {
            if case .level(let name) = error { return name }
            return error.reasonCode
        } catch {
            return "other"
        }
    }

    @Test func aValidLevelBuildsAndRoundTrips() throws {
        let level: ApsidesWorkshopLevel = try Self.sample()
        let data: Data = level.encoded()
        let decoded: ApsidesWorkshopLevel = try ApsidesWorkshopLevel.decode(data)
        #expect(decoded == level && decoded.fingerprint == level.fingerprint)
        let json: ApsidesWorkshopLevel = try JSONDecoder().decode(ApsidesWorkshopLevel.self, from: data)
        #expect(json == level)
        #expect(level.encoded() == data)
        #expect(level.fingerprint.count == 64)
    }

    @Test func theWinningOrbitWinsAndTheStartDoesNot() throws {
        let level: ApsidesWorkshopLevel = try Self.sample()
        #expect(!level.startReport.wins)
        #expect(level.startReport.failure == .apsisSector(target: 0, sector: 2))
        #expect(ApsidesWorkshopSky.report(level, orbit: Self.winning).wins)
    }

    @Test func aStartingOrbitThatWinsIsRefused() {
        #expect(Self.refusal { try Self.sample(orbit: Self.winning) } == "already won")
    }

    @Test func everyRangeIsRefusedByName() {
        let planet = ApsidesWorkshopPlanet(x: 40, y: 40, radius: 2)
        #expect(Self.refusal { try ApsidesWorkshopLevel(id: "Bad Id", seed: 0, difficulty: 1, period: 24,
                                                         planets: [], targets: [.sweep(sector: 0, low: 0, high: 10)],
                                                         orbit: Self.winning, budget: 1) } == "id")
        #expect(Self.refusal { try ApsidesWorkshopLevel(id: "a", seed: 0, difficulty: 6, period: 24, planets: [],
                                                         targets: [.sweep(sector: 0, low: 0, high: 10)],
                                                         orbit: Self.winning, budget: 1) } == "difficulty")
        #expect(Self.refusal { try Self.sample(period: 25) } == "period")
        #expect(Self.refusal { try Self.sample(period: 14) } == "period")
        #expect(Self.refusal { try Self.sample(period: 98) } == "period")
        #expect(Self.refusal { try Self.sample(planets: Array(repeating: planet, count: 7)) } == "planets")
        #expect(Self.refusal { try Self.sample(planets: [ApsidesWorkshopPlanet(x: 65, y: 0, radius: 2)]) }
                == "planet centre")
        #expect(Self.refusal { try Self.sample(planets: [ApsidesWorkshopPlanet(x: 40, y: 0, radius: 9)]) }
                == "planet radius")
        #expect(Self.refusal { try Self.sample(planets: [ApsidesWorkshopPlanet(x: 4, y: 0, radius: 2)]) }
                == "planet over star")
        #expect(Self.refusal { try Self.sample(targets: []) } == "targets")
        #expect(Self.refusal { try Self.sample(targets: [.sweep(sector: 8, low: 0, high: 10)]) } == "target sector")
        #expect(Self.refusal { try Self.sample(targets: [.sweep(sector: 1, low: 0, high: 1001)]) } == "target band")
        #expect(Self.refusal { try Self.sample(targets: [.sweep(sector: 1, low: 20, high: 10)]) }
                == "target band reversed")
        #expect(Self.refusal { try Self.sample(targets: [.sweep(sector: 1, low: 0, high: 0),
                                                         .sweep(sector: 1, low: 0, high: 0)]) } == "targets duplicate")
        #expect(Self.refusal { try Self.sample(orbit: ApsidesWorkshopOrbit(size: 4, eccentricity: 0, direction: 0)) }
                == "orbit")
        #expect(Self.refusal { try Self.sample(budget: 0) } == "budget")
        #expect(Self.refusal { try Self.sample(budget: 25) } == "budget")
    }

    @Test func aPlanetJustClearOfTheStarIsAccepted() {
        // (radius + star radius)² = 16; 3² + 3² = 18 > 16.
        let clear: String = Self.refusal { try Self.sample(planets: [ApsidesWorkshopPlanet(x: 3, y: 3, radius: 2)]) }
        #expect(clear != "planet over star")
    }

    @Test func orbitValidityFollowsItsTwoInequalities() {
        #expect(ApsidesWorkshopOrbit(size: 12, eccentricity: 15, direction: 0).isValid)   // 12 · 5 = 60
        #expect(!ApsidesWorkshopOrbit(size: 11, eccentricity: 15, direction: 0).isValid)  // 55 < 60
        #expect(ApsidesWorkshopOrbit(size: 40, eccentricity: 12, direction: 0).isValid)   // 40 · 32 = 1280
        #expect(!ApsidesWorkshopOrbit(size: 41, eccentricity: 12, direction: 0).isValid)  // 1312 > 1280
        #expect(!ApsidesWorkshopOrbit(size: 24, eccentricity: 16, direction: 0).isValid)
        #expect(!ApsidesWorkshopOrbit(size: 24, eccentricity: 0, direction: 24).isValid)
        #expect(!ApsidesWorkshopOrbit(size: 7, eccentricity: 0, direction: 0).isValid)
    }

    @Test func theWordsNameSectorsTargetsAndProgress() throws {
        let level: ApsidesWorkshopLevel = try Self.sample(targets: [
            .sweep(sector: 2, low: 150, high: 200),
            ApsidesWorkshopTarget(kind: .periapsis, sector: 0, low: 120, high: 140)])
        #expect(level.sectorName(3) == "sector 3")
        #expect(ApsidesWorkshopLevel.shareWords(184) == "18.4 %")
        #expect(ApsidesWorkshopLevel.distanceWords(131) == "6.55 units")
        #expect(ApsidesWorkshopLevel.distanceWords(120) == "6.00 units")
        #expect(level.orbitDescription(Self.winning) == "size 24, eccentricity 0.25, periapsis at 0°")
        let report: ApsidesWorkshopReport = level.startReport
        let sweep: String = level.targetDescription(0, report: report, orbit: level.orbit)
        #expect(sweep.hasPrefix("sector 2 swept ") && sweep.hasSuffix(", needs 15.0 % to 20.0 %"))
        let apsis: String = level.targetDescription(1, report: report, orbit: level.orbit)
        #expect(apsis == "periapsis in sector 2 at 18.00 units, needs sector 0 at 6.00 units to 7.00 units")
        let progress: String = level.progressDescription(report: report, orbit: level.orbit, actionsLeft: 1)
        #expect(progress.contains("of 2 targets met in order") && progress.hasSuffix("1 action left"))
    }

    @Test func damagedEditedNewerAndOlderFormsAreRefused() throws {
        let level: ApsidesWorkshopLevel = try Self.sample()
        let text: String = String(decoding: level.encoded(), as: UTF8.self)
        func decode(_ s: String) -> String {
            do {
                _ = try ApsidesWorkshopLevel.decode(Data(s.utf8))
                return "accepted"
            } catch {
                return error.reasonCode
            }
        }
        #expect(decode("{") == "r02-g18.malformed")
        #expect(decode(text.replacingOccurrences(of: "\"budget\":3", with: "\"budget\":4")) == "r02-g18.malformed")
        #expect(decode(text.replacingOccurrences(of: "\"budget\":3", with: "\"budget\":30")) == "r02-g18.malformed")
        #expect(decode(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")) == "r02-g18.newer-schema")
        #expect(decode(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")) == "r02-g18.malformed")
        #expect(decode(text.replacingOccurrences(of: "\"fingerprint\"", with: "\"print\"")) == "r02-g18.malformed")
        #expect(decode(text) == "accepted")
    }

    @Test func fixturesBuildAndTheirKnownOrbitsWin() {
        let fixtures: [ApsidesWorkshopFixture] = ApsidesWorkshopFixture.all(count: 200)
        var wins: Int = 0
        for fixture in fixtures {
            if ApsidesWorkshopSky.report(fixture.level, orbit: fixture.winning).wins
                && !fixture.level.startReport.wins { wins += 1 }
        }
        #expect(wins == fixtures.count)
    }
}
