import SwiftUI

struct PaywallSheetModifier: ViewModifier {
    private static let autoDismissThreshold: TimeInterval = 0.6
    private static let maxRecoveryAttempts: Int = 1

    @Binding var isPresented: Bool

    @State private var presentedAt: Date?
    @State private var didCompleteIntentionally: Bool = false
    @State private var recoveryAttempts: Int = 0

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            PaywallView(mode: .upgrade) {
                didCompleteIntentionally = true
                isPresented = false
            }
        }
        .onChange(of: isPresented) { oldValue, newValue in
            handleIsPresentedChange(oldValue: oldValue, newValue: newValue)
        }
    }

    private func handleIsPresentedChange(oldValue: Bool, newValue: Bool) {
        if !oldValue, newValue {
            presentedAt = .now
            didCompleteIntentionally = false
            return
        }
        guard oldValue, !newValue else { return }
        defer { presentedAt = nil }
        guard !didCompleteIntentionally,
              let openedAt = presentedAt,
              Date().timeIntervalSince(openedAt) < Self.autoDismissThreshold,
              recoveryAttempts < Self.maxRecoveryAttempts
        else {
            recoveryAttempts = 0
            return
        }
        recoveryAttempts += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            isPresented = true
        }
    }
}

extension View {
    func paywallSheet(isPresented: Binding<Bool>) -> some View {
        modifier(PaywallSheetModifier(isPresented: isPresented))
    }
}
