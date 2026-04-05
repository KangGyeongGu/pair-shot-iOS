import SwiftUI

@MainActor
struct HeatmapView: View {
    let beforeURL: URL
    let afterURL: URL

    @State private var result: HeatmapService.HeatmapResult?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("변화 감지 중...")
                    .tint(.white)
                    .foregroundStyle(.white)
            } else if let message = errorMessage {
                Text(message)
                    .foregroundStyle(.secondary)
            } else if let result {
                ZStack(alignment: .bottom) {
                    Image(decorative: result.heatmapCGImage, scale: 1.0)
                        .resizable()
                        .scaledToFit()

                    Text("\(Int(result.changeRatio * 100))% 면적 변화")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .task(id: "\(beforeURL.path)|\(afterURL.path)") {
            isLoading = true
            result = nil
            errorMessage = nil
            do {
                result = try await HeatmapService.generateHeatmap(beforeURL: beforeURL, afterURL: afterURL)
            } catch {
                errorMessage = "히트맵 생성 실패"
            }
            isLoading = false
        }
    }
}
