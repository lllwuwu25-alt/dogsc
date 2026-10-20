import SwiftUI

struct DogSCCornerRadii {
    var topLeading: CGFloat = 0
    var bottomLeading: CGFloat = 0
    var bottomTrailing: CGFloat = 0
    var topTrailing: CGFloat = 0
}

struct DogSCUnevenRoundedRectangle: InsettableShape {
    var cornerRadii: DogSCCornerRadii
    var style: RoundedCornerStyle = .continuous
    private var insetAmount: CGFloat = 0

    init(cornerRadii: DogSCCornerRadii, style: RoundedCornerStyle = .continuous) {
        self.cornerRadii = cornerRadii
        self.style = style
    }

    init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0,
         bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0,
         style: RoundedCornerStyle = .continuous) {
        self.init(cornerRadii: DogSCCornerRadii(topLeading: topLeadingRadius,
            bottomLeading: bottomLeadingRadius, bottomTrailing: bottomTrailingRadius,
            topTrailing: topTrailingRadius), style: style)
    }

    func inset(by amount: CGFloat) -> Self {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard bounds.width > 0, bounds.height > 0 else { return Path() }
        let limit = min(bounds.width, bounds.height) / 2
        let tl = min(max(cornerRadii.topLeading - insetAmount, 0), limit)
        let tr = min(max(cornerRadii.topTrailing - insetAmount, 0), limit)
        let bl = min(max(cornerRadii.bottomLeading - insetAmount, 0), limit)
        let br = min(max(cornerRadii.bottomTrailing - insetAmount, 0), limit)
        if #available(macOS 14.0, *) {
            return UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
                topLeading: tl, bottomLeading: bl, bottomTrailing: br, topTrailing: tr),
                style: style).path(in: bounds)
        }
        var path = Path()
        path.move(to: CGPoint(x: bounds.minX + tl, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - tr, y: bounds.minY))
        path.addQuadCurve(to: CGPoint(x: bounds.maxX, y: bounds.minY + tr),
                          control: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY - br))
        path.addQuadCurve(to: CGPoint(x: bounds.maxX - br, y: bounds.maxY),
                          control: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + bl, y: bounds.maxY))
        path.addQuadCurve(to: CGPoint(x: bounds.minX, y: bounds.maxY - bl),
                          control: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY + tl))
        path.addQuadCurve(to: CGPoint(x: bounds.minX + tl, y: bounds.minY),
                          control: CGPoint(x: bounds.minX, y: bounds.minY))
        path.closeSubpath()
        return path
    }
}
