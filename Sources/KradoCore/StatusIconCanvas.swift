import CoreGraphics

/// Whole-point square canvas for the redrawn menu status symbols.
public enum StatusIconCanvas {
    public static func side(baseWidth: Double, baseHeight: Double, factor: Double) -> Double {
        (max(baseWidth, baseHeight) * factor).rounded()
    }

    public static func drawRect(side: Double, baseWidth: Double, baseHeight: Double) -> CGRect {
        let scale = side / max(baseWidth, baseHeight)
        let w = baseWidth * scale, h = baseHeight * scale
        return CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h)
    }
}
