import Foundation

/// This reflection is its own inverse, including screens above/below/left of the main display.
public func flipY(_ rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: mainScreenHeight - rect.maxY, width: rect.width, height: rect.height)
}

public func flipY(_ point: CGPoint, mainScreenHeight: CGFloat) -> CGPoint {
    CGPoint(x: point.x, y: mainScreenHeight - point.y)
}
