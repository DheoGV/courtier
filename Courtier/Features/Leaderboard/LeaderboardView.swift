import SwiftUI

/// "Standings": podium for the top three, then the rest, ordered by the session's ranking rule.
struct LeaderboardView: View {
    @Environment(SessionStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let session = store.session {
            content(session, table: Standings.compute(session))
        } else {
            EmptyState(title: tr("No standings yet", "Klasemen kosong"),
                       note: tr("Standings appear once a session starts and the first score is saved.",
                                "Klasemen muncul setelah sesi dimulai dan skor pertama disimpan."),
                       action: (tr("Set Up Tournament", "Atur Turnamen"), { router.tab = .setup }))
        }
    }

    private func unit(_ session: Session) -> String { session.scoring.isTennis ? tr("games", "game") : tr("pts", "poin") }

    private func content(_ session: Session, table: [Standing]) -> some View {
        let done = session.rounds.filter(\.isComplete).count
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        BrandRow()
                        Eyebrow(text: tr("After round \(done) / \(session.plannedRounds)", "Setelah babak \(done) / \(session.plannedRounds)")
                                + " · \(session.scoring.label)")
                        Text(tr("Standings", "Klasemen")).font(.screenTitle).foregroundStyle(.ink)
                    }
                    Spacer()
                    ShareLink(item: shareText(session, table)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.ink)
                            .frame(width: 40, height: 40)
                            .background(.surface2, in: Circle())
                    }
                    .accessibilityLabel(tr("Share standings", "Bagikan klasemen"))
                }

                if table.count >= 3 {
                    podium(Array(table.prefix(3)), mode: session.ranking)
                }

                VStack(spacing: 0) {
                    HStack {
                        Eyebrow(text: session.format == .fixedPartner ? tr("Teams", "Tim") : tr("Players", "Pemain"))
                        Spacer()
                        Eyebrow(text: session.ranking == .wins ? tr("Wins", "Menang") : tr("Points", "Poin"))
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(.line).frame(height: 1) }

                    ForEach(Array(table.enumerated()).dropFirst(table.count >= 3 ? 3 : 0), id: \.element.id) { index, standing in
                        LeaderboardRow(rank: index + 1, standing: standing, mode: session.ranking, unit: unit(session))
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "scalemass").foregroundStyle(.brassInk)
                    Text(rule(session))
                        .font(.caption)
                        .foregroundStyle(.inkMuted)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.surface2, in: RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .tabBarClearance()
        .statusBarScrim()
    }

    private func podium(_ top: [Standing], mode: RankingMode) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            place(top[1], rank: 2, height: 84, mode: mode)
            place(top[0], rank: 1, height: 116, mode: mode)
            place(top[2], rank: 3, height: 64, mode: mode)
        }
    }

    private func place(_ s: Standing, rank: Int, height: CGFloat, mode: RankingMode) -> some View {
        let first = rank == 1
        let initials = s.members.count == 2
            ? s.name.components(separatedBy: " & ").map { String($0.prefix(1)) }.joined().uppercased()
            : Player(name: s.name).initials
        return VStack(spacing: 6) {
            if first {
                CrownMark(width: 28, lineWidth: 1.6, color: .brassInk)
            }
            Text(initials)
                .font(.jost(first ? 18 : 15, .bold))
                .foregroundStyle(first ? .onRacing : .ink)
                .frame(width: first ? 60 : 50, height: first ? 60 : 50)
                .background(first ? Color.racing : .surface, in: Circle())
                .overlay(Circle().strokeBorder(first ? Color.brass : .line, lineWidth: 2))
            Text(s.name)
                .font(.jost(14, .semibold))
                .foregroundStyle(.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(mode == .wins ? "\(s.won) \(tr("W", "M")) · \(s.diff >= 0 ? "+" : "−")\(abs(s.diff))" : "\(s.totalPoints) pts")
                .font(.playfair(15, .medium))
                .foregroundStyle(.inkMuted)
            Text("\(rank)")
                .font(.playfair(first ? 40 : 30, .semibold))
                .foregroundStyle(first ? .heroAccent : .inkMuted)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(first ? Color.racing : .surface, in: UnevenRoundedRectangle(topLeadingRadius: Radius.md, topTrailingRadius: Radius.md))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: Radius.md, topTrailingRadius: Radius.md).strokeBorder(first ? .clear : Color.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func rule(_ session: Session) -> String {
        switch session.ranking {
        case .wins:
            session.scoring.isTennis
                ? tr("Order: wins → game difference → head-to-head → win rate. Total games are not used.",
                     "Urutan: jumlah menang → selisih game → head-to-head → rasio menang. Total game tidak dipakai.")
                : tr("Order: wins → point difference → head-to-head → win rate. Total points are not used.",
                     "Urutan: jumlah menang → selisih poin → head-to-head → rasio menang. Total poin tidak dipakai.")
        case .totalPoints:
            tr("Order: total points → wins → point difference → head-to-head. Resting players get the round's average.",
               "Urutan: total poin → jumlah menang → selisih poin → head-to-head. Pemain istirahat dapat poin rata-rata babak.")
        }
    }

    private func shareText(_ session: Session, _ table: [Standing]) -> String {
        let lines = table.enumerated().map { i, s in
            let headline = session.ranking == .wins ? tr("\(s.won) wins", "\(s.won) menang") : tr("\(s.totalPoints) pts", "\(s.totalPoints) poin")
            return "\(i + 1). \(s.name) — \(headline), " + tr("diff", "selisih") + " \(s.diff >= 0 ? "+" : "")\(s.diff)"
        }
        return (["👑 " + tr("Courtier Standings", "Klasemen Courtier") + " · \(session.format.title) · \(session.scoring.label)"] + lines).joined(separator: "\n")
    }
}
