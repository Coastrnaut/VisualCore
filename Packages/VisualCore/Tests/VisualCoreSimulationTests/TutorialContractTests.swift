// TutorialContractTests — feature 224 (R02-F24) T-R02F24-005 (FR-R02F24-004, 005, 006; SC-R02F24-003). 100 seeded
// contracts driven by seeded event scripts against a reference model written here; unmatched, late and foreign events;
// skip and restart; the stored form round trip byte for byte; damaged, foreign and newer stored forms; every refusal of
// the initialisers with its reason code.
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite("TutorialContract")
struct TutorialContractTests {

    // MARK: - Helpers

    private static let identities: [String] = ["level-a", "level-b", "level-c"]

    private static func randomCondition(_ random: inout SeededRandom) -> TutorialCondition {
        let kind: Int = random.int(0...4)
        switch kind {
        case 0: return .move
        case 1: return .moves(random.int(1...4))
        case 2: return .solve
        case 3: return .solveLevel(identities[random.int(0...2)])
        default: return .acknowledge
        }
    }

    private static func randomEvent(_ random: inout SeededRandom) -> TutorialEvent {
        let kind: Int = random.int(0...4)
        switch kind {
        case 0, 1: return .moved
        case 2: return .solved(identities[random.int(0...2)])
        case 3: return .solved("level-other")
        default: return .acknowledged
        }
    }

    private static func makeContract(_ random: inout SeededRandom, index: Int) throws -> TutorialContract {
        let count: Int = random.int(1...8)
        var steps: [TutorialContractStep] = []
        for s in 0..<count {
            let step = try TutorialContractStep(
                id: "step-\(s)", textKey: "tutorial.\(index).\(s)", condition: randomCondition(&random))
            steps.append(step)
        }
        return try TutorialContract(id: "contract-\(index)", steps: steps)
    }

    /// The reference model: what the progress should be after each event, written independently of the type.
    private struct Model {
        var step: Int = 0
        var moves: Int = 0
        var completed: [String] = []
        var finished: Bool = false

        mutating func apply(_ event: TutorialEvent, _ contract: TutorialContract) -> Bool {
            if finished { return false }
            let condition: TutorialCondition = contract.steps[step].condition
            var met: Bool = false
            if event == .moved {
                moves += 1
                if condition == .move { met = true }
                if case .moves(let n) = condition, moves >= n { met = true }
            }
            if case .solved(let identity) = event {
                if condition == .solve { met = true }
                if condition == .solveLevel(identity) { met = true }
            }
            if event == .acknowledged, condition == .acknowledge { met = true }
            if !met { return false }
            completed.append(contract.steps[step].id)
            step += 1
            moves = 0
            finished = step == contract.steps.count
            return true
        }
    }

    private static func simple() throws -> TutorialContract {
        let a = try TutorialContractStep(id: "move", textKey: "t.move", condition: .move)
        let b = try TutorialContractStep(id: "three", textKey: "t.three", condition: .moves(3))
        let c = try TutorialContractStep(id: "solve", textKey: "t.solve", condition: .solveLevel("level-a"))
        let d = try TutorialContractStep(id: "ack", textKey: "t.ack", condition: .acknowledge)
        return try TutorialContract(id: "intro", steps: [a, b, c, d])
    }

    private static func rewrite(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func expectMalformed(_ data: Data, _ contract: TutorialContract) {
        var refusal: ContentError? = nil
        do {
            _ = try TutorialContractProgress.decode(data, for: contract)
        } catch {
            refusal = error
        }
        let isMalformed: Bool
        if case .malformed = refusal { isMalformed = true } else { isMalformed = false }
        #expect(isMalformed, "expected malformed, got \(String(describing: refusal))")
        #expect(refusal?.reasonCode == "r2-f24.malformed")
    }

    // MARK: - Seeded scripts

    @Test("100 seeded event scripts advance exactly as the reference model")
    func seededScripts() throws {
        var random = SeededRandom(seed: 2_024)
        var advances: Int = 0
        var finishedCount: Int = 0
        for index in 0..<100 {
            let contract: TutorialContract = try Self.makeContract(&random, index: index)
            var progress = TutorialContractProgress(contract: contract)
            var model = Model()
            let length: Int = random.int(1...60)
            for _ in 0..<length {
                let event: TutorialEvent = Self.randomEvent(&random)
                let before: Int = progress.step
                let predicted: Bool = model.apply(event, contract)
                let advanced: Bool = progress.apply(event, in: contract)
                #expect(advanced == predicted)
                #expect(progress.step == model.step)
                #expect(progress.movesInStep == model.moves)
                #expect(progress.completed == model.completed)
                #expect(progress.finished == model.finished)
                #expect(progress.skipped.isEmpty)
                if !advanced { #expect(progress.step == before) } else { advances += 1 }
            }
            if progress.finished {
                finishedCount += 1
                #expect(progress.currentStep(in: contract) == nil)
            } else {
                #expect(progress.currentStep(in: contract) == contract.steps[progress.step])
            }
            // Byte-for-byte round trip of every script's final progress.
            let data: Data = progress.encoded()
            let decoded: TutorialContractProgress = try TutorialContractProgress.decode(data, for: contract)
            #expect(decoded == progress)
            #expect(decoded.encoded() == data)
        }
        #expect(advances > 100)
        #expect(finishedCount > 0)
    }

    // MARK: - Unmatched, late and foreign events

    @Test("Unmatched events do not advance but moves are counted")
    func unmatchedEvents() throws {
        let contract: TutorialContract = try Self.simple()
        var progress = TutorialContractProgress(contract: contract)
        let advanced1: Bool = progress.apply(.acknowledged, in: contract)
        #expect(advanced1 == false)
        let advanced2: Bool = progress.apply(.solved("level-a"), in: contract)
        #expect(advanced2 == false)
        #expect(progress.step == 0)
        let advanced3: Bool = progress.apply(.moved, in: contract)
        #expect(advanced3 == true)
        #expect(progress.step == 1)
        #expect(progress.movesInStep == 0)
        let advanced4: Bool = progress.apply(.moved, in: contract)
        #expect(advanced4 == false)
        let advanced5: Bool = progress.apply(.acknowledged, in: contract)
        #expect(advanced5 == false)
        let advanced6: Bool = progress.apply(.moved, in: contract)
        #expect(advanced6 == false)
        #expect(progress.movesInStep == 2)
        let advanced7: Bool = progress.apply(.moved, in: contract)
        #expect(advanced7 == true)
        #expect(progress.step == 2)
        // A move on a solve step counts but does not advance; a different level does not advance.
        let advanced8: Bool = progress.apply(.moved, in: contract)
        #expect(advanced8 == false)
        #expect(progress.movesInStep == 1)
        let advanced9: Bool = progress.apply(.solved("level-b"), in: contract)
        #expect(advanced9 == false)
        let advanced10: Bool = progress.apply(.solved("level-a"), in: contract)
        #expect(advanced10 == true)
        #expect(progress.movesInStep == 0)
        #expect(progress.step == 3)
        let advanced11: Bool = progress.apply(.acknowledged, in: contract)
        #expect(advanced11 == true)
        #expect(progress.finished)
        #expect(progress.completed == ["move", "three", "solve", "ack"])
    }

    @Test("Events after the end and for another contract are ignored")
    func lateAndForeignEvents() throws {
        let contract: TutorialContract = try Self.simple()
        let other = try TutorialContract(
            id: "other", steps: [try TutorialContractStep(id: "move", textKey: "t.move", condition: .move)])
        var progress = TutorialContractProgress(contract: contract)
        let advanced12: Bool = progress.apply(.moved, in: other)
        #expect(advanced12 == false)
        #expect(progress.movesInStep == 0)
        progress.skip(in: other)
        #expect(progress.step == 0)
        #expect(progress.skipped.isEmpty)
        #expect(progress.currentStep(in: other) == nil)

        progress.skip(in: contract)
        progress.skip(in: contract)
        progress.skip(in: contract)
        progress.skip(in: contract)
        #expect(progress.finished)
        let ended: TutorialContractProgress = progress
        let events: [TutorialEvent] = [.moved, .solved("level-a"), .acknowledged]
        for event in events {
            let advanced13: Bool = progress.apply(event, in: contract)
            #expect(advanced13 == false)
        }
        progress.skip(in: contract)
        #expect(progress == ended)
    }

    // MARK: - Skip and restart

    @Test("Skip advances and is recorded; restart returns to the start")
    func skipAndRestart() throws {
        let contract: TutorialContract = try Self.simple()
        var progress = TutorialContractProgress(contract: contract)
        let advanced14: Bool = progress.apply(.moved, in: contract)
        #expect(advanced14 == true)
        let advanced15: Bool = progress.apply(.moved, in: contract)
        #expect(advanced15 == false)
        progress.skip(in: contract)
        #expect(progress.step == 2)
        #expect(progress.movesInStep == 0)
        #expect(progress.completed == ["move"])
        #expect(progress.skipped == ["three"])

        // Resume: the saved position reopens identically.
        let saved: Data = progress.encoded()
        var resumed: TutorialContractProgress = try TutorialContractProgress.decode(saved, for: contract)
        #expect(resumed == progress)
        let advanced16: Bool = resumed.apply(.solved("level-a"), in: contract)
        #expect(advanced16 == true)
        resumed.skip(in: contract)
        #expect(resumed.finished)
        #expect(resumed.completed == ["move", "solve"])
        #expect(resumed.skipped == ["three", "ack"])
        let finishedData: Data = resumed.encoded()
        let reopened: TutorialContractProgress = try TutorialContractProgress.decode(finishedData, for: contract)
        #expect(reopened == resumed)
        #expect(reopened.encoded() == finishedData)

        resumed.restart()
        #expect(resumed == TutorialContractProgress(contract: contract))
        #expect(resumed.currentStep(in: contract)?.id == "move")
    }

    // MARK: - Stored form

    @Test("Stored form refusals: foreign, out of range, inconsistent, tampered, newer")
    func storedFormRefusals() throws {
        let contract: TutorialContract = try Self.simple()
        var progress = TutorialContractProgress(contract: contract)
        progress.apply(.moved, in: contract)
        progress.skip(in: contract)
        let data: Data = progress.encoded()

        let other = try TutorialContract(id: "other", steps: contract.steps)
        Self.expectMalformed(data, other)
        Self.expectMalformed(try Self.rewrite(data) { $0["step"] = 5 }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["step"] = -1 }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["finished"] = true }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["movesInStep"] = -1 }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["completed"] = ["three"] }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["completed"] = ["move", "three"] }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["skipped"] = ["move"] }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["completed"] = ["solve"] }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0["schema"] = 0 }, contract)
        Self.expectMalformed(try Self.rewrite(data) { $0.removeValue(forKey: "skipped") }, contract)
        Self.expectMalformed(Data("not json".utf8), contract)

        // A finished form with an unfinished flag at the last step.
        var done = TutorialContractProgress(contract: contract)
        for _ in 0..<4 { done.skip(in: contract) }
        Self.expectMalformed(try Self.rewrite(done.encoded()) { $0["finished"] = false }, contract)

        let newerData: Data = try Self.rewrite(data) { $0["schema"] = 2 }
        var newer: ContentError? = nil
        do {
            _ = try TutorialContractProgress.decode(newerData, for: contract)
        } catch {
            newer = error
        }
        #expect(newer == .newerSchema(2))
        #expect(newer?.reasonCode == "r2-f24.newer-schema")
        #expect(TutorialContractProgress.schema == 1)
        #expect(String(decoding: data, as: UTF8.self).contains("\"schema\":1"))
    }

    // MARK: - Initialiser refusals

    private static func stepRefusal(_ id: String, _ key: String, _ condition: TutorialCondition) -> ContentError? {
        do {
            _ = try TutorialContractStep(id: id, textKey: key, condition: condition)
            return nil
        } catch {
            return error
        }
    }

    private static func contractRefusal(_ id: String, _ steps: [TutorialContractStep]) -> ContentError? {
        do {
            _ = try TutorialContract(id: id, steps: steps)
            return nil
        } catch {
            return error
        }
    }

    @Test("Step and contract refusals carry their reason codes")
    func initRefusals() throws {
        let longKey = String(repeating: "k", count: 129)
        let maxKey = String(repeating: "k", count: 128)
        #expect(Self.stepRefusal("Bad", "k", .move) == .tutorial("stepID"))
        #expect(Self.stepRefusal("", "k", .move) == .tutorial("stepID"))
        #expect(Self.stepRefusal("a--b", "k", .move) == .tutorial("stepID"))
        #expect(Self.stepRefusal("ok", "", .move) == .tutorial("textKey"))
        #expect(Self.stepRefusal("ok", longKey, .move) == .tutorial("textKey"))
        #expect(Self.stepRefusal("ok", maxKey, .move) == nil)
        #expect(Self.stepRefusal("ok", "k", .moves(0)) == .tutorial("condition"))
        #expect(Self.stepRefusal("ok", "k", .moves(1_001)) == .tutorial("condition"))
        #expect(Self.stepRefusal("ok", "k", .moves(1)) == nil)
        #expect(Self.stepRefusal("ok", "k", .moves(1_000)) == nil)
        #expect(Self.stepRefusal("ok", "k", .solveLevel("")) == .tutorial("condition"))
        #expect(Self.stepRefusal("ok", "k", .solveLevel(longKey)) == .tutorial("condition"))
        #expect(Self.stepRefusal("ok", "k", .solveLevel(maxKey)) == nil)
        #expect(Self.stepRefusal("ok", "k", .moves(0))?.reasonCode == "r2-f24.tutorial")

        let step = try TutorialContractStep(id: "a", textKey: "k", condition: .move)
        #expect(Self.contractRefusal("Intro", [step]) == .tutorial("id"))
        #expect(Self.contractRefusal("intro", []) == .tutorial("steps"))
        #expect(Self.contractRefusal("intro", [step, step]) == .tutorial("duplicateStep"))
        var many: [TutorialContractStep] = []
        for i in 0..<65 {
            many.append(try TutorialContractStep(id: "s\(i)", textKey: "k", condition: .acknowledge))
        }
        #expect(Self.contractRefusal("intro", many) == .tutorial("steps"))
        many.removeLast()
        #expect(Self.contractRefusal("intro", many) == nil)
        #expect(TutorialContract.maxSteps == 64)
    }

    @Test("Codable contracts re-validate on decode")
    func codableRevalidates() throws {
        let contract: TutorialContract = try Self.simple()
        let data: Data = try JSONEncoder().encode(contract)
        let back: TutorialContract = try JSONDecoder().decode(TutorialContract.self, from: data)
        #expect(back == contract)

        let badStep = Data(#"{"id":"Bad","textKey":"k","condition":{"move":{}}}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(TutorialContractStep.self, from: badStep)
        }
        let badMoves = Data(#"{"id":"ok","textKey":"k","condition":{"moves":{"_0":0}}}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(TutorialContractStep.self, from: badMoves)
        }
        let goodStep = Data(#"{"id":"ok","textKey":"k","condition":{"moves":{"_0":2}}}"#.utf8)
        let decodedStep: TutorialContractStep = try JSONDecoder().decode(TutorialContractStep.self, from: goodStep)
        #expect(decodedStep.condition == .moves(2))
        let duplicate = Data(
            #"{"id":"intro","steps":[{"id":"a","textKey":"k","condition":{"move":{}}},{"id":"a","textKey":"k","condition":{"move":{}}}]}"#
                .utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(TutorialContract.self, from: duplicate)
        }
    }
}
