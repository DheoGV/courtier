import SwiftUI

/// Splash "Courtier" from the brand board: racing green, double brass frame, crown, wordmark.
/// The crown sits where the launch screen's LaunchLogo is (screen centre), so the hand-off is seamless.
struct SplashView: View {
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color.racing.ignoresSafeArea()

            ContainerRelativeShape()
                .strokeBorder(Color.brass.opacity(0.6), lineWidth: 1)
                .padding(18)
            ContainerRelativeShape()
                .strokeBorder(Color.brass.opacity(0.25), lineWidth: 1)
                .padding(28)

            Image("LaunchLogo")
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Text("COURTIER")
                    .font(.marcellus(38))
                    .tracking(8)
                    .foregroundStyle(.onRacing)
                // The splash is always English, whatever the in-app language.
                Text("Respect the game")
                    .font(.jost(14))
                    .foregroundStyle(.heroMuted)
            }
            .offset(y: 120)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 8)

            VStack {
                Spacer()
                Text("EST. 2026 · PADEL CLUB")
                    .font(.jost(10, .medium))
                    .tracking(4)
                    .foregroundStyle(.brass)
                    .padding(.bottom, 56)
                    .opacity(revealed ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .containerShape(RoundedRectangle(cornerRadius: 48))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Courtier")
        .task {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { revealed = true }
        }
    }
}

#Preview {
    SplashView()
}
