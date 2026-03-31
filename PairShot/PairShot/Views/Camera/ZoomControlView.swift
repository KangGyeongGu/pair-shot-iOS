//
//  ZoomControlView.swift
//  PairShot
//

import SwiftUI

// MARK: - ZoomControlView

/// 줌 배율 버튼 가로 행 + 핀치 제스처 지원.
///
/// - 사용 가능한 배율 목록을 버튼으로 나열한다.
/// - 선택된 배율 버튼은 노란색으로 하이라이트된다.
/// - `onZoomChanged`: 배율이 변경될 때 호출되는 콜백
struct ZoomControlView: View {
    var availableFactors: [CGFloat]
    var currentFactor: CGFloat
    var onZoomChanged: (CGFloat) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(availableFactors, id: \.self) { factor in
                ZoomButton(
                    factor: factor,
                    isSelected: isSelected(factor),
                    onTap: { onZoomChanged(factor) }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Private

    private func isSelected(_ factor: CGFloat) -> Bool {
        abs(currentFactor - factor) < 0.05
    }
}

// MARK: - ZoomButton

private struct ZoomButton: View {
    let factor: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(displayLabel(for: factor))
                .font(.system(size: 13, weight: isSelected ? .bold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.yellow : Color.white)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func displayLabel(for factor: CGFloat) -> String {
        // 0.5x, 1x, 2x, 3x 형식으로 표시
        if factor < 1.0 {
            String(format: "%.1fx", factor)
        } else if factor == floor(factor) {
            "\(Int(factor))x"
        } else {
            String(format: "%.1fx", factor)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            ZoomControlView(
                availableFactors: [0.5, 1.0, 2.0, 3.0],
                currentFactor: 1.0,
                onZoomChanged: { _ in }
            )
            .padding(.bottom, 20)
        }
    }
}
