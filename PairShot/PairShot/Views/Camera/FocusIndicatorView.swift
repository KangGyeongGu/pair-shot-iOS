import SwiftUI

struct FocusIndicatorView: View {
    let exposureBias: Float
    let exposureBiasMax: Float
    let isDraggingExposure: Bool
    var scale: CGFloat = 1.0
    var opacity: CGFloat = 1.0

    private let size: CGFloat = 70
    private let tickLen: CGFloat = 10
    private let barHeight: CGFloat = 160

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ZStack {
                Rectangle()
                    .strokeBorder(Color.yellow, lineWidth: 1)
                    .frame(width: size, height: size)

                // 상단 변 → 내부로 향하는 세로선
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 1, height: tickLen)
                    .offset(y: -size / 2 + tickLen / 2)
                // 하단 변
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 1, height: tickLen)
                    .offset(y: size / 2 - tickLen / 2)
                // 좌측 변
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: tickLen, height: 1)
                    .offset(x: -size / 2 + tickLen / 2)
                // 우측 변
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: tickLen, height: 1)
                    .offset(x: size / 2 - tickLen / 2)
            }

            // 노출 컨트롤 (해 아이콘 + 바)
            ZStack {
                // 바 (드래그 중에만 표시)
                if isDraggingExposure {
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: 1, height: barHeight)
                        .transition(.opacity)
                }

                // 해 아이콘 (항상 표시, bias에 따라 이동, 바 범위 내 제한)
                let maxOffset = barHeight / 2 - 12
                let biasNorm = CGFloat(exposureBias / max(exposureBiasMax, 1.0))
                let sunOffset = max(-maxOffset, min(-biasNorm * maxOffset, maxOffset))
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.yellow)
                    .offset(y: sunOffset)
            }
            .frame(width: 22, height: barHeight)
            .animation(.easeOut(duration: 0.15), value: isDraggingExposure)
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }
}
