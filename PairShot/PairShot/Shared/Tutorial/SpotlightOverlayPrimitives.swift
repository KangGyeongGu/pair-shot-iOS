import SwiftUI

struct SpotlightDimmedMask: View {
    let containerSize: CGSize
    let cutout: CGRect
    let cornerRadius: CGFloat
    let opacity: Double

    var body: some View {
        let shape = SpotlightHoleShape(cutout: cutout, cornerRadius: cornerRadius)
        Color.black.opacity(opacity)
            .frame(width: containerSize.width, height: containerSize.height)
            .mask(shape.fill(style: FillStyle(eoFill: true)))
            .contentShape(shape, eoFill: true)
    }
}

struct SpotlightHoleShape: Shape {
    let cutout: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addPath(Path(roundedRect: cutout, cornerRadius: cornerRadius))
        return path
    }
}
