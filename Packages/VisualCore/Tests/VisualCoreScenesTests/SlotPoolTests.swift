// SlotPoolTests — feature 055 (A07-P02) T-A07-202 (FR-A07-201; gap G-SEGMENTSTREAM).
import Testing
@testable import VisualCoreScenes

@Test func slotPoolMakesEverythingUpFrontAndNeverGrows() {
    var made: [Int] = []
    var pool = SlotPool(capacity: 3) { i -> String in made.append(i); return "e\(i)" }
    #expect(made == [0, 1, 2])
    #expect(pool.capacity == 3)
    #expect(pool.available == 3)
    #expect(pool.acquire() == 0)
    #expect(pool.acquire() == 1)
    #expect(pool.acquire() == 2)
    #expect(pool.acquire() == nil, "exhausted")
    #expect(pool.available == 0)
    #expect(pool.capacity == 3)
}

@Test func slotPoolReusesLowestReleasedSlot() {
    var pool = SlotPool(capacity: 4) { $0 }
    for _ in 0..<4 { _ = pool.acquire() }
    pool.release(2)
    pool.release(1)
    #expect(pool.available == 2)
    #expect(pool.acquire() == 1)
    #expect(pool.acquire() == 2)
    #expect(pool.acquire() == nil)
}

@Test func slotPoolIgnoresInvalidAndDoubleRelease() {
    var pool = SlotPool(capacity: 2) { $0 }
    pool.release(0)   // never acquired
    pool.release(-1)
    pool.release(7)
    #expect(pool.available == 2)
    #expect(pool.acquire() == 0)
    pool.release(0)
    pool.release(0)
    #expect(pool.available == 2)
    let zero = SlotPool(capacity: 0) { $0 }
    #expect(zero.capacity == 0)
    #expect(zero.available == 0)
}

@Test func slotPoolSubscriptMutatesElements() {
    var pool = SlotPool(capacity: 2) { _ in [Int]() }
    let s = pool.acquire()!
    pool[s].append(42)
    pool[s] = pool[s] + [7]
    #expect(pool[s] == [42, 7])
    #expect(pool[1].isEmpty)
}

@Test func windowAndPoolReuseSlotsWithoutGrowth() throws {
    let capacity = 8
    var window = try #require(SegmentWindow(behind: 1, ahead: 5, capacity: capacity))
    var pool = SlotPool(capacity: capacity) { _ in -1 }   // element = piece index held
    var slotOf: [Int: Int] = [:]
    var maxSlotUsed = -1
    var distance = 0.0
    var step = 0
    while distance < 300 {
        let s = window.advance(to: distance, pieceLength: 1.5)
        for i in s.toRetire {
            let removed = slotOf.removeValue(forKey: i)
            let slot = try #require(removed)
            pool.release(slot)
        }
        for i in s.toBuild {
            let acquired = pool.acquire()
            let slot = try #require(acquired, "pool never exhausted")
            pool[slot] = i
            slotOf[i] = slot
            maxSlotUsed = max(maxSlotUsed, slot)
        }
        #expect(Set(slotOf.keys) == Set(window.live))
        #expect(pool.capacity - pool.available == window.live.count)
        for (i, slot) in slotOf { #expect(pool[slot] == i) }
        step += 1
        distance += 0.4
    }
    #expect(maxSlotUsed < 7, "window of 7 pieces only ever uses slots 0...6: retired slots are reused")
    #expect(pool.capacity == capacity)
    #expect(step > 100)
}
