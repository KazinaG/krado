/// State for one moving drag. Option cancels the accumulated selection; releasing it
/// while Shift remains held begins a new selection at the current hit.
public struct SpanAccumulator<ScreenID: Equatable> {
    public private(set) var screenID: ScreenID?
    public private(set) var span: GridSpan?

    public init() {}

    public mutating func reset() {
        screenID = nil
        span = nil
    }

    public mutating func update(screenID: ScreenID?, hit: GridSpan?, shift: Bool, option: Bool) -> GridSpan? {
        guard !option else { reset(); return nil }
        guard shift else { reset(); return hit }
        if let screenID, self.screenID != screenID {
            self.screenID = screenID
            span = nil
        }
        if let hit { span = span.map { $0.union(hit) } ?? hit }
        return span
    }
}
