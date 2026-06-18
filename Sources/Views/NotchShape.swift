import SwiftUI

/// The notch silhouette: a flat top edge (flush with the bezel) with small
/// concave fillets at the top corners that blend into the screen, and convex
/// rounded bottom corners — the iconic Dynamic-Island / MacBook-notch profile.
struct NotchShape: Shape {
    var topRadius: CGFloat = 10
    var bottomRadius: CGFloat = 13

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tr = min(topRadius, rect.height / 2)
        let br = min(bottomRadius, rect.height / 2, rect.width / 2)

        // Top-left outer corner, curving inward/down (concave) toward the body.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                       control: CGPoint(x: rect.minX + tr, y: rect.minY))
        // Down the left side.
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        // Bottom-left convex corner.
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                       control: CGPoint(x: rect.minX + tr, y: rect.maxY))
        // Across the bottom.
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        // Bottom-right convex corner.
        p.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                       control: CGPoint(x: rect.maxX - tr, y: rect.maxY))
        // Up the right side.
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        // Top-right concave fillet back out to the bezel.
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.closeSubpath()   // straight top edge between the two outer corners
        return p
    }
}
