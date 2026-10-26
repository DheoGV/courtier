import SwiftUI

/// "Round 3 / 8": round progress, one card per court, who rests, and the next action.
struct ScheduleView: View {
    @Environment(SessionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var selectedRound: Int?

    var body: some View {
        if let session = store.session {
            content(session)
        } else {
            EmptyState(title: tr("No session yet", "Belum ada sesi"),
                       note: tr("Add players and pick a format to build the schedule.", "Tambahkan pemain dan pilih format untuk membuat jadwal."),
                       action: (tr("Set Up Tournament", "Atur Turnamen"), { router.tab = .setup }))
        }
    }

    private func content(_ session: Session) -> some View {
        let current = session.currentRoundIndex ?? 0
        let index = min(selectedRound ?? current, max(session.rounds.count - 1, 0))
        let round = session.rounds.isEmpty ? nil : session.rounds[index]

        // A racing-green navigation bar (no title) carries the hero colour up under the status bar
        // and is the only way to get light status-bar text in an otherwise light app.
        return NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero(session, current: current)
                    VStack(alignment: .leading, spacing: 16) {
                        roundChips(session, selected: index, current: current)
                        if let round {
                            ForEach(round.matches) { match in
                                Button { router.score(match.id) } label: {
                                    MatchCard(match: match, session: session)
                                }
                                .buttonStyle(.plain)
                            }
                            if !round.sitOut.isEmpty {
                                sitOut(session, round)
                            }
                            actions(session, round)
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(.appBackground)
            .tabBarClearance()
            .toolbarBackground(Color.racing, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { brandItem }
        }
    }

    @ToolbarContentBuilder
    private var brandItem: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarLeading) { BrandRow(onHero: true).fixedSize() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { BrandRow(onHero: true).fixedSize() }
        }
    }

    private func hero(_ session: Session, current: Int) -> some View {
        let done = session.rounds.filter(\.isComplete).count
        let remaining = max(session.plannedRounds - done, 0)
        let end = Date.now.addingTimeInterval(Double(remaining * session.minutesPerMatch) * 60)
        return VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "\(session.format.title) · \(session.scoring.label) · \(session.players.count) " + tr("players", "pemain"), color: .heroMuted)
            HStack(alignment: .lastTextBaseline) {
                Text(tr("Round \(current + 1)", "Babak \(current + 1)"))
                    .font(.playfair(40, .semibold))
                    .foregroundStyle(.onRacing)
                Spacer()
                Text("/ \(session.plannedRounds)")
                    .font(.playfair(22, .medium))
                    .foregroundStyle(.heroMuted)
            }
            HStack(spacing: 4) {
                ForEach(0..<session.plannedRounds, id: \.self) { i in
                    Capsule()
                        .fill(i < done ? Color.heroAccent : i == current ? .onRacing : .white.opacity(0.15))
                        .frame(height: 4)
                }
            }
            HStack {
                meta("square.grid.2x2", tr("\(session.activeCourts) courts", "\(session.activeCourts) lapangan"))
                Spacer()
                meta("timer", tr("±\(session.minutesPerMatch) min/match", "±\(session.minutesPerMatch) mnt/game"))
                Spacer()
                meta("flag", tr("Ends", "Selesai") + " ±\(end.formatted(date: .omitted, time: .shortened))")
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .background(.racing, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private func meta(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(.heroAccent)
            Text(text).font(.caption).foregroundStyle(.onRacing)
        }
    }

    private func roundChips(_ session: Session, selected: Int, current: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(session.rounds.enumerated()), id: \.element.id) { i, round in
                        let on = i == selected
                        Button { selectedRound = i } label: {
                            Text("R\(round.number)")
                                .font(.jost(13, .semibold))
                                .foregroundStyle(on ? .onRacing : round.isComplete ? .ink : .inkMuted)
                                .frame(minWidth: 48, minHeight: 36)
                                .background(on ? Color.racing : round.isComplete ? .surface2 : .appBackground, in: Capsule())
                                .overlay(Capsule().strokeBorder(on ? .clear : Color.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
            }
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
    }

    private func sitOut(_ session: Session, _ round: Round) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "chair.lounge")
                .font(.system(size: 18))
                .foregroundStyle(.inkMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Resting", "Istirahat") + ": \(session.names(round.sitOut))")
                    .font(.jost(14, .semibold))
                    .foregroundStyle(.ink)
                Text(session.ranking == .totalPoints
                     ? tr("Fair rotation · gets this round's average points", "Rotasi adil · dapat poin rata-rata babak ini")
                     : tr("Fair rotation · not counted as a win or loss", "Rotasi adil · tidak dihitung menang/kalah"))
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
            }
            Spacer()
        }
        .padding(14)
        .background(.surface2, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    @ViewBuilder
    private func actions(_ session: Session, _ round: Round) -> some View {
        if let next = round.matches.first(where: { $0.status != .done }) {
            Button { router.score(next.id) } label: {
                Label(tr("Enter Score · Court \(next.court)", "Input Skor Lapangan \(next.court)"), systemImage: "pencil.line")
            }
            .buttonStyle(.primary)
        } else if session.canGenerateNextRound {
            Button {
                store.generateNextRound()
                selectedRound = nil
            } label: {
                Label(tr("Generate Round \(session.rounds.count + 1) from Standings", "Generate Babak \(session.rounds.count + 1) dari Klasemen"),
                      systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.primary)
        } else if round.id == session.rounds.last?.id {
            Button { router.tab = .leaderboard } label: {
                Label(tr("View Standings", "Lihat Klasemen"), systemImage: "trophy")
            }
            .buttonStyle(.primary)
        }

        Button {
            store.addRound()
        } label: {
            Label(tr("Add round", "Tambah babak"), systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.ghost)
    }
}

#Preview {
    let store = SessionStore(persist: false)
    store.addPlayers(from: "Andi\nBudi\nCitra\nDodi\nEko\nFajar\nGita\nHana\nIndra\nJoko")
    store.start()
    return ScheduleView()
        .environment(store)
        .environment(AppRouter())
        .background(.appBackground)
}
