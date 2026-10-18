import Testing
@testable import KradoCore

@Suite("Drag span accumulation")
struct SpanAccumulatorTests {
    let first = GridSpan(columns: 0..<1, rows: 0..<1)
    let last = GridSpan(columns: 3..<4, rows: 1..<2)

    @Test func union() {
        let boundary = GridSpan(columns: 1..<3, rows: 0..<2)
        #expect(first.union(boundary) == GridSpan(columns: 0..<3, rows: 0..<2))
        #expect(first.union(last) == GridSpan(columns: 0..<4, rows: 0..<2))
        #expect(boundary.union(first) == first.union(boundary))
        #expect(boundary.union(boundary) == boundary)
    }

    @Test func shiftDownAndUp() {
        var state = SpanAccumulator<Int>()
        #expect(state.update(screenID: 1, hit: first, shift: false, option: false) == first)
        #expect(state.update(screenID: 1, hit: last, shift: true, option: false) == last)
        #expect(state.update(screenID: 1, hit: first, shift: true, option: false) == first.union(last))
        #expect(state.update(screenID: 1, hit: first, shift: false, option: false) == first)
        #expect(state.span == nil)
        #expect(state.update(screenID: 1, hit: last, shift: true, option: false) == last)
    }

    @Test func nilHitAndScreenChange() {
        var state = SpanAccumulator<Int>()
        #expect(state.update(screenID: 1, hit: nil, shift: true, option: false) == nil)
        #expect(state.update(screenID: 1, hit: first, shift: true, option: false) == first)
        #expect(state.update(screenID: 1, hit: nil, shift: true, option: false) == first)
        #expect(state.update(screenID: nil, hit: nil, shift: true, option: false) == first)
        #expect(state.update(screenID: 2, hit: nil, shift: true, option: false) == nil)
        #expect(state.update(screenID: 2, hit: last, shift: true, option: false) == last)
        #expect(state.update(screenID: 1, hit: first, shift: true, option: false) == first)
        #expect(state.update(screenID: 1, hit: nil, shift: false, option: false) == nil)
    }

    @Test func optionPrecedenceAndResume() {
        var state = SpanAccumulator<Int>()
        #expect(state.update(screenID: 1, hit: first, shift: true, option: false) == first)
        #expect(state.update(screenID: 1, hit: last, shift: true, option: true) == nil)
        #expect(state.span == nil && state.screenID == nil)
        #expect(state.update(screenID: 1, hit: last, shift: true, option: false) == last)
        #expect(state.update(screenID: 1, hit: first, shift: false, option: true) == nil)
        #expect(state.update(screenID: 1, hit: first, shift: false, option: false) == first)
        state.reset()
        #expect(state.span == nil && state.screenID == nil)
    }
}
