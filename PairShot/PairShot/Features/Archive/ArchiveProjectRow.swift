import SwiftUI

/// Audit-D — extracted from ``ArchiveView`` so that file stays under the
/// 250-line cap from `.claude/refs/swiftui-patterns.md`.
///
/// Two surfaces:
/// - ``ProjectRow`` — single row in the project list. Renders the title,
///   updated date, and the three count badges. Combined into a single
///   VoiceOver utterance so screen-reader users hear "프로젝트 X, 페어 N,
///   완료 M, 합성 K" instead of every badge separately (Audit-C).
/// - ``CountBadge`` — small pill used by the row for pair / completed /
///   composited counts.
///
/// Pure presentation; no SwiftData or environment reach-back. The
/// `Project` is read-only here.
struct ProjectRow: View {
    let project: Project
    let isSelectionMode: Bool
    let isSelected: Bool

    private var displayTitle: String {
        project.title.isEmpty ? String(localized: "(이름 없음)") : project.title
    }

    private var pairCount: Int {
        project.pairs.count
    }

    private var completedCount: Int {
        project.pairs.count(where: { $0.status == .complete })
    }

    private var combinedCount: Int {
        project.pairs.count(where: { $0.combinedPath != nil })
    }

    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(displayTitle).font(.headline)
                    Spacer()
                    Text(project.updatedAt, format: .dateTime.month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    CountBadge(label: String(localized: "페어"), count: pairCount, tint: .blue)
                    CountBadge(label: String(localized: "완료"), count: completedCount, tint: .green)
                    CountBadge(label: String(localized: "합성"), count: combinedCount, tint: .purple)
                }
            }
        }
        .padding(.vertical, 4)
        // Audit-C — collapse the row into a single VoiceOver utterance
        // so the user hears "프로젝트 X, 페어 N, 선택됨" instead of
        // every badge separately.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let title = displayTitle
        let counts = String(
            format: String(localized: "페어 %d개, 완료 %d개, 합성 %d개"),
            pairCount,
            completedCount,
            combinedCount
        )
        if isSelectionMode {
            let selectionText = isSelected
                ? String(localized: "선택됨")
                : String(localized: "선택 안 됨")
            return "\(title), \(counts), \(selectionText)"
        }
        return "\(title), \(counts)"
    }
}

struct CountBadge: View {
    let label: String
    let count: Int
    let tint: Color

    var body: some View {
        Text("\(label) \(count)")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: .capsule)
            .foregroundStyle(tint)
    }
}
