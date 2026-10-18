import Foundation
import Testing
@testable import KradoCore

@Suite("Window movement inference")
struct WindowMovementTests {
    @Test("Position and size thresholds", arguments: [
        MovementCase(dx: 0, dy: 0, dw: 0, dh: 0, expected: .stationary),
        MovementCase(dx: 2.99, dy: 0, dw: 0, dh: 0, expected: .stationary),
        MovementCase(dx: 3, dy: 0, dw: 0, dh: 0, expected: .moving),
        MovementCase(dx: -3, dy: 0, dw: 0, dh: 0, expected: .moving),
        MovementCase(dx: 0, dy: -3, dw: 0, dh: 0, expected: .moving),
        MovementCase(dx: 2.2, dy: 2.2, dw: 0, dh: 0, expected: .moving),
        MovementCase(dx: 20, dy: 30, dw: 2, dh: -2, expected: .moving),
        MovementCase(dx: 0, dy: 0, dw: 3, dh: 0, expected: .resized),
        MovementCase(dx: 30, dy: 0, dw: 2.01, dh: 0, expected: .resized),
        MovementCase(dx: 0, dy: 30, dw: 0, dh: -2.01, expected: .resized),
        MovementCase(dx: 0, dy: 0, dw: 2, dh: 2, expected: .stationary),
    ])
    func movement(test: MovementCase) {
        let initial = WindowSnapshot(position: CGPoint(x: -1000, y: -400), size: CGSize(width: 800, height: 600))
        let current = WindowSnapshot(
            position: CGPoint(x: initial.position.x + test.dx, y: initial.position.y + test.dy),
            size: CGSize(width: initial.size.width + test.dw, height: initial.size.height + test.dh)
        )
        #expect(WindowMovement.classify(initial: initial, current: current) == test.expected)
    }

    @Test("Thresholds can be adjusted without AX")
    func customThresholds() {
        let initial = WindowSnapshot(position: .zero, size: CGSize(width: 800, height: 600))
        let current = WindowSnapshot(position: CGPoint(x: 4, y: 0), size: CGSize(width: 801, height: 600))
        #expect(WindowMovement.classify(initial: initial, current: current, movementThreshold: 5) == .stationary)
        #expect(WindowMovement.classify(initial: initial, current: current, sizeTolerance: 0.5) == .resized)
    }
}

struct MovementCase: Sendable {
    let dx: CGFloat
    let dy: CGFloat
    let dw: CGFloat
    let dh: CGFloat
    let expected: WindowMovement
}
