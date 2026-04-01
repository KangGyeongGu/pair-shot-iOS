//
//  ShutterButton.swift
//  PairShot
//

import SwiftUI

// MARK: - ShutterButton

/// 현장 작업자용 대형 셔터 버튼.
///
/// - 최소 70pt 지름 (장갑 착용 시에도 탭 가능)
/// - 탭 시 내부 원이 수축 애니메이션
struct ShutterButton: View {
    let action: () -> Void

    @State private var isPressed: Bool = false

    private let outerDiameter: CGFloat = 80
    private let innerDiameter: CGFloat = 64

    var body: some View {
        Button {
            triggerCapture()
        } label: {
            ZStack {
                // 외부 링
                Circle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: outerDiameter, height: outerDiameter)

                // 내부 채운 원 — 누를 때 수축
                Circle()
                    .fill(Color.white)
                    .frame(
                        width: isPressed ? innerDiameter * 0.75 : innerDiameter,
                        height: isPressed ? innerDiameter * 0.75 : innerDiameter
                    )
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
        }
        .buttonStyle(.plain)
        // 최소 탭 영역 44pt 이상 보장 (실제로는 80pt이므로 충분)
        .frame(width: outerDiameter, height: outerDiameter)
        .contentShape(Circle())
    }

    // MARK: - Private

    private func triggerCapture() {
        isPressed = true
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPressed = false
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ShutterButton {}
    }
}
