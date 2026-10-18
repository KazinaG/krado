import Foundation
import CoreGraphics

public struct WindowSnapshot: Equatable, Sendable {
    public let position: CGPoint
    public let size: CGSize

    public init(position: CGPoint, size: CGSize) {
        self.position = position
        self.size = size
    }
}

public enum WindowMovement: Equatable, Sendable {
    case stationary
    case moving
    case resized

    public static func classify(
        initial: WindowSnapshot, current: WindowSnapshot,
        movementThreshold: CGFloat = KradoDefaults.movementThreshold,
        sizeTolerance: CGFloat = KradoDefaults.sizeTolerance
    ) -> WindowMovement {
        if abs(current.size.width - initial.size.width) > sizeTolerance
            || abs(current.size.height - initial.size.height) > sizeTolerance {
            return .resized
        }
        let distance = hypot(current.position.x - initial.position.x, current.position.y - initial.position.y)
        return distance >= movementThreshold ? .moving : .stationary
    }
}
