import SwiftUI

struct GridOverlayView: View {
    var isGridEnabled: Bool

    var body: some View {
        if isGridEnabled {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let vx1 = width / 3.0
                let vx2 = width * 2.0 / 3.0
                let hy1 = height / 3.0
                let hy2 = height * 2.0 / 3.0

                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: vx1, y: 0))
                        path.addLine(to: CGPoint(x: vx1, y: height))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)

                    Path { path in
                        path.move(to: CGPoint(x: vx2, y: 0))
                        path.addLine(to: CGPoint(x: vx2, y: height))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: hy1))
                        path.addLine(to: CGPoint(x: width, y: hy1))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: hy2))
                        path.addLine(to: CGPoint(x: width, y: hy2))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        GridOverlayView(isGridEnabled: true)
    }
}
