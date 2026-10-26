import SwiftUI

/// Small uppercase label with letter spacing ("SESI BARU · SABTU MALAM").
struct Eyebrow: View {
    let text: String
    var color: Color = .inkMuted

    var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jost(15, .semibold))
            .foregroundStyle(.onRacing)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(.racing, in: Capsule())
            .shadow(color: .glow, radius: 10, y: 6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.jost(14, .medium))
            .foregroundStyle(.ink)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .overlay(Capsule().stroke(.line, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

struct Avatar: View {
    let initials: String
    var size: CGFloat = 36
    var filled = false

    var body: some View {
        Text(initials)
            .font(.jost(size * 0.34, .bold))
            .foregroundStyle(filled ? .onRacing : .ink)
            .frame(width: size, height: size)
            .background(filled ? Color.racing : .surface2, in: Circle())
    }
}

struct PlayerChip: View {
    let player: Player
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Avatar(initials: player.initials, size: 26, filled: true)
            Text(player.name)
                .font(.jost(14, .medium))
                .foregroundStyle(.ink)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.inkMuted)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hapus \(player.name)")
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, onRemove == nil ? 12 : 8)
        .padding(.vertical, 6)
        .background(.surface2, in: Capsule())
    }
}

/// − value + control.
struct ValueStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var label: String

    var body: some View {
        HStack(spacing: 4) {
            step("minus", -1)
            Text("\(value)")
                .font(.playfair(20, .medium))
                .foregroundStyle(.ink)
                .monospacedDigit()
                .frame(width: 44)
                .contentTransition(.numericText())
            step("plus", 1)
        }
        .padding(4)
        .background(.surface2, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(1)
            case .decrement: change(-1)
            @unknown default: break
            }
        }
    }

    private func step(_ symbol: String, _ delta: Int) -> some View {
        Button { change(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.ink)
                .frame(width: 36, height: 36)
                .background(.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!range.contains(value + delta))
        .opacity(range.contains(value + delta) ? 1 : 0.35)
    }

    private func change(_ delta: Int) {
        let next = value + delta
        guard range.contains(next) else { return }
        withAnimation(.snappy) { value = next }
    }
}

/// Capsule segmented control from the design ("Rally 11 · Rally 21 · Tennis").
struct Segmented<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    withAnimation(.snappy) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.jost(14, on ? .semibold : .medium))
                        .foregroundStyle(on ? .ink : .inkMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if on {
                                Capsule().fill(.surface).shadow(color: .glow, radius: 4, y: 2)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.surface2, in: Capsule())
    }
}

struct OptionCard: View {
    let format: Format
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: format.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.racing)
                Spacer()
                Circle()
                    .strokeBorder(selected ? Color.racing : .line, lineWidth: selected ? 5 : 1.5)
                    .frame(width: 18, height: 18)
            }
            Text(format.title)
                .font(.playfair(19, .semibold))
                .foregroundStyle(.ink)
            Text(format.summary)
                .font(.caption)
                .foregroundStyle(.inkMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(selected ? Color.racing : .line, lineWidth: selected ? 1.5 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Status pill with a coloured dot ("Selesai", "Berlangsung").
struct StatusPill: View {
    let match: Match

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.jost(11, .semibold)).foregroundStyle(.ink)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(.surface2, in: Capsule())
    }

    private var label: String {
        switch match.status {
        case .pending: "Belum mulai"
        case .live: "Berlangsung"
        case .done: "Selesai"
        }
    }

    private var color: Color {
        switch match.status {
        case .pending: .line
        case .live: .brass
        case .done: .win
        }
    }
}

struct MatchCard: View {
    let match: Match
    let session: Session

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Eyebrow(text: "Lapangan \(match.court)")
                Spacer()
                StatusPill(match: match)
            }
            row(.a)
            Rectangle().fill(.line).frame(height: 1)
            row(.b)
        }
        .padding(16)
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.line, lineWidth: 1))
        .shadow(color: .glow, radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func row(_ side: Side) -> some View {
        let dim = match.winner == side.other
        return HStack {
            Text(session.names(match.team(side)))
                .font(.jost(16, .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Text(match.status == .pending ? "–" : "\(match.score(side))")
                .font(.playfair(30, .medium))
                .monospacedDigit()
        }
        .foregroundStyle(dim ? .inkMuted : .ink)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let standing: Standing
    let mode: RankingMode
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.playfair(18, .medium))
                .foregroundStyle(rank == 1 ? .brassInk : .inkMuted)
                .frame(width: 24, alignment: .leading)
            Avatar(initials: initials)
            VStack(alignment: .leading, spacing: 2) {
                Text(standing.name)
                    .font(.jost(15, .semibold))
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
            }
            Spacer(minLength: 8)
            Text("\(standing.headline(mode))")
                .font(.playfair(24, .medium))
                .foregroundStyle(.ink)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(.line).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private var initials: String {
        let parts = standing.name.components(separatedBy: " & ")
        return parts.count == 2 ? parts.map { String($0.prefix(1)) }.joined().uppercased() : Player(name: standing.name).initials
    }

    private var meta: String {
        let diff = standing.diff > 0 ? "+\(standing.diff)" : standing.diff < 0 ? "−\(-standing.diff)" : "0"
        return "\(standing.played) main · \(standing.won)M \(standing.lost)K · selisih \(diff) \(unit)"
    }
}

/// Wraps children onto new lines, left to right.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Empty state used by tabs before a session exists.
struct EmptyState: View {
    let title: String
    let note: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            CrownMark(width: 64, lineWidth: 1.6)
            Text(title)
                .font(.playfair(24, .semibold))
                .foregroundStyle(.ink)
            Text(note)
                .font(.body)
                .foregroundStyle(.inkMuted)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.title, action: action.run)
                    .buttonStyle(.primary)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
