import SwiftUI

/// 3x3 rule-of-thirds grid drawn on top of the camera preview.
/// Uses a single `Path` so SwiftUI does one draw pass per frame.
struct GridOverlay: View {
    /// Number of vertical/horizontal interior lines. Always 2 for a rule-of-thirds grid;
    /// kept as a property so previews/tests can vary it without touching the layout math.
    var divisions: Int = 3

    var lineColor: Color = .white.opacity(0.45)
    var lineWidth: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                var path = Path()
                let interiorCount = max(divisions - 1, 0)
                guard interiorCount > 0 else { return }

                for index in 1 ... interiorCount {
                    let fraction = CGFloat(index) / CGFloat(divisions)

                    // Vertical line
                    let xPos = size.width * fraction
                    path.move(to: CGPoint(x: xPos, y: 0))
                    path.addLine(to: CGPoint(x: xPos, y: size.height))

                    // Horizontal line
                    let yPos = size.height * fraction
                    path.move(to: CGPoint(x: 0, y: yPos))
                    path.addLine(to: CGPoint(x: size.width, y: yPos))
                }

                context.stroke(
                    path,
                    with: .color(lineColor),
                    lineWidth: lineWidth
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        GridOverlay()
    }
}
