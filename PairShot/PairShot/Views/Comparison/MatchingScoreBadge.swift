import SwiftUI

struct MatchingScoreBadge: View {
    let score: Float?

    var body: some View {
        if let score {
            let grade = MatchingScoreService.grade(for: score)
            let percent = MatchingScoreService.percentMatch(for: score)
            let accent = Self.color(for: grade)
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text("\(percent)% 일치")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accent.opacity(0.15))
            .clipShape(Capsule())
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("분석 중...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
        }
    }

    private static func color(for grade: MatchingScoreService.MatchingGrade) -> Color {
        switch grade {
            case .excellent: .green
            case .good: .yellow
            case .retake: .red
        }
    }
}
