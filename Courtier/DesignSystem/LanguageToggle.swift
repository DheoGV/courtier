import SwiftUI

/// Small EN | ID capsule switch for the in-app language.
struct LanguageToggle: View {
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.en.rawValue

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppLanguage.allCases) { option in
                let on = option.rawValue == language
                Button {
                    withAnimation(.snappy) { language = option.rawValue }
                } label: {
                    Text(option.label)
                        .font(.jost(12, .semibold))
                        .tracking(1)
                        .foregroundStyle(on ? .onRacing : .inkMuted)
                        .frame(width: 36, height: 28)
                        .background(on ? Color.racing : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option == .en ? "English" : "Bahasa Indonesia")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.surface2, in: Capsule())
    }
}

#Preview {
    LanguageToggle().padding().background(.appBackground)
}
