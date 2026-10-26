import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var store
    @State private var router = AppRouter()
    /// The tab bar steps aside while typing, otherwise it rides up with the keyboard and covers "Simpan Hasil".
    @State private var keyboardShown = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            switch router.tab {
            case .setup: SetupView()
            case .schedule: ScheduleView()
            case .score: ScoreView()
            case .leaderboard: LeaderboardView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardShown {
                TabBar(selection: Bindable(router).tab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    // Fades scrolled content out under the bar and the home indicator.
                    .background {
                        LinearGradient(colors: [Color.appBackground.opacity(0), .appBackground], startPoint: .top, endPoint: .center)
                            .ignoresSafeArea()
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardShown = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardShown = false }
        .environment(router)
        .onAppear {
            if store.session != nil { router.tab = .schedule }
        }
    }
}

extension View {
    /// Keeps the end of a scroll view clear of the floating tab bar.
    func tabBarClearance() -> some View {
        safeAreaPadding(.bottom, 84)
    }

    /// Ivory band behind the status bar so scrolled content doesn't run under the clock.
    func statusBarScrim() -> some View {
        // A zero-height inset whose ShapeStyle background extends up into the status bar area.
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(.appBackground)
        }
    }
}

struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { item($0) }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Color.surface.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(.line, lineWidth: 1))
        .shadow(color: .glow, radius: 12, y: 8)
    }

    private func item(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 18, weight: selected ? .semibold : .regular))
                Text(tab.title)
                    .font(.jost(10, selected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? .racing : .inkMuted)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? Color.surface2 : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    RootView().environment(SessionStore(persist: false))
}
