import SwiftUI

/// Score tab: the chosen match (or the next unfinished one) with a rally or tennis scorer.
struct ScoreView: View {
    @Environment(SessionStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let session = store.session, case let (round, match)? = target(session) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(round: round, match: match, session: session)
                    courtPicker(round: round, selected: match.id)
                    Group {
                        if session.scoring.isTennis {
                            TennisScorer(match: match, session: session, onSaved: { advance(from: match, in: round) })
                        } else {
                            RallyScorer(match: match, session: session, onSaved: { advance(from: match, in: round) })
                        }
                    }
                    .id(match.id)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .tabBarClearance()
            .statusBarScrim()
        } else {
            EmptyState(title: "Tidak ada pertandingan", note: "Buat jadwal dulu di tab Sesi, lalu pilih lapangan untuk diisi skornya.",
                       action: ("Ke Jadwal", { router.tab = store.session == nil ? .setup : .schedule }))
        }
    }

    private func target(_ session: Session) -> (Round, Match)? {
        if let id = router.scoringMatch {
            for round in session.rounds {
                if let match = round.matches.first(where: { $0.id == id }) { return (round, match) }
            }
        }
        guard let index = session.currentRoundIndex else { return nil }
        let round = session.rounds[index]
        guard let match = round.matches.first(where: { $0.status != .done }) ?? round.matches.first else { return nil }
        return (round, match)
    }

    /// After saving, jump to the next unfinished court of the round, or back to the schedule.
    private func advance(from match: Match, in round: Round) {
        let refreshed = store.session?.rounds.first { $0.id == round.id }
        if let next = refreshed?.matches.first(where: { $0.status != .done && $0.id != match.id }) {
            router.scoringMatch = next.id
        } else {
            router.scoringMatch = nil
            router.tab = .schedule
        }
    }

    private func header(round: Round, match: Match, session: Session) -> some View {
        HStack {
            Button { router.tab = .schedule } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.ink)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Kembali ke jadwal")
            Spacer()
            VStack(spacing: 2) {
                Text("Lapangan \(match.court)").font(.jost(16, .semibold)).foregroundStyle(.ink)
                Text("Babak \(round.number) · \(session.scoring.label)").font(.caption).foregroundStyle(.inkMuted)
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
    }

    @ViewBuilder
    private func courtPicker(round: Round, selected: Match.ID) -> some View {
        if round.matches.count > 1 {
            HStack(spacing: 6) {
                ForEach(round.matches) { m in
                    let on = m.id == selected
                    Button { router.scoringMatch = m.id } label: {
                        HStack(spacing: 6) {
                            if m.status == .done { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                            Text("Lap. \(m.court)")
                        }
                        .font(.jost(12, .semibold))
                        .foregroundStyle(on ? .onRacing : .ink)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(on ? Color.racing : .surface2, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Rally (11 / 21)

struct RallyScorer: View {
    @Environment(SessionStore.self) private var store
    let match: Match
    let session: Session
    var onSaved: () -> Void

    @State private var a: Int
    @State private var b: Int
    @State private var history: [(Int, Int)] = []
    @State private var error: String?
    @State private var draft: [Side: String] = [:]
    @FocusState private var focused: Side?

    init(match: Match, session: Session, onSaved: @escaping () -> Void) {
        self.match = match
        self.session = session
        self.onSaved = onSaved
        _a = State(initialValue: match.scoreA)
        _b = State(initialValue: match.scoreB)
    }

    private var scoring: Scoring { session.scoring }

    var body: some View {
        VStack(spacing: 20) {
            MatchClock(startedAt: store.match(match.id)?.startedAt, minutes: session.minutesPerMatch)
            HStack(spacing: 12) {
                panel(.a)
                panel(.b)
            }
            banner
            quickInput
            if let error {
                Text(error).font(.caption).foregroundStyle(.loss)
            }
            HStack(spacing: 10) {
                Button(action: undo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.ghost)
                    .disabled(history.isEmpty)
                Button(action: save) { Label("Simpan Hasil", systemImage: "checkmark") }
                    .buttonStyle(.primary)
            }
        }
        // The number pad has no return key.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Selesai") { focused = nil }
                    .font(.jost(15, .semibold))
            }
        }
    }

    private func panel(_ side: Side) -> some View {
        let score = side == .a ? a : b
        let lead = score > (side == .a ? b : a)
        return VStack(spacing: 14) {
            Eyebrow(text: "Tim \(side.rawValue.uppercased())", color: lead ? .heroMuted : .inkMuted)
            Text(session.names(match.team(side)))
                .font(.jost(14, .semibold))
                .foregroundStyle(lead ? .onRacing : .ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 36)
            Text("\(score)")
                .font(.playfair(84, .medium))
                .foregroundStyle(lead ? .heroAccent : .ink)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(score)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 8) {
                Button { change(side, -1) } label: {
                    Image(systemName: "minus").frame(width: 48, height: 52)
                        .background(lead ? Color.white.opacity(0.1) : .surface2, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(score == 0)
                .accessibilityLabel("Kurangi poin tim \(side.rawValue.uppercased())")
                Button { change(side, 1) } label: {
                    Image(systemName: "plus").frame(maxWidth: .infinity, minHeight: 52)
                        .background(lead ? Color.heroAccent : .racing, in: RoundedRectangle(cornerRadius: Radius.md))
                        .foregroundStyle(lead ? .racing : .onRacing)
                }
                .disabled(!scoring.canScore(a, b))
                .accessibilityLabel("Tambah poin tim \(side.rawValue.uppercased())")
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(lead ? .onRacing : .ink)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(lead ? Color.racing : .surface, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(lead ? .clear : Color.line, lineWidth: 1))
        .animation(.snappy, value: lead)
    }

    @ViewBuilder
    private var banner: some View {
        if let text = bannerText {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundStyle(.brassInk)
                Text(text).font(.jost(13, .semibold)).foregroundStyle(.ink)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(.surface2, in: Capsule())
        }
    }

    private var bannerText: String? {
        if scoring.isValidFinal(a, b) { return "SELESAI · Tim \(a > b ? "A" : "B") menang \(max(a, b))–\(min(a, b))" }
        if scoring.isDecider(a, b) { return "POIN PENENTU · siapa pun yang dapat, menang" }
        if let side = scoring.matchPoint(a, b) { return "GAME POINT · Tim \(side.rawValue.uppercased()) butuh 1 poin" }
        return nil
    }

    private var quickInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atau ketik skor akhir langsung").font(.jost(14, .semibold)).foregroundStyle(.ink)
            HStack(spacing: 12) {
                field(.a)
                Text("–").font(.playfair(24)).foregroundStyle(.inkMuted)
                field(.b)
            }
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.line, lineWidth: 1))
    }

    private func field(_ side: Side) -> some View {
        let value = side == .a ? a : b
        // While focused the field starts empty (current score as placeholder), so typing replaces the score
        // instead of appending to it ("17" + "9" → "179").
        return TextField("\(value)", text: Binding {
            focused == side ? (draft[side] ?? "") : (value == 0 ? "" : "\(value)")
        } set: { text in
            let digits = String(text.filter(\.isNumber).prefix(2))
            draft[side] = digits
            guard let typed = Int(digits) else { return }
            history.append((a, b))
            if side == .a { a = min(typed, scoring.maxScore) } else { b = min(typed, scoring.maxScore) }
            error = nil
            store.setLiveScore(match.id, a: a, b: b)
        })
        .keyboardType(.numberPad)
        .focused($focused, equals: side)
        .onChange(of: focused) { draft = [:] }
        .multilineTextAlignment(.center)
        .font(.playfair(26, .medium))
        .foregroundStyle(.ink)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(focused == side ? Color.racing : .line, lineWidth: 1))
        .accessibilityLabel("Skor tim \(side.rawValue.uppercased())")
    }

    private func change(_ side: Side, _ delta: Int) {
        history.append((a, b))
        withAnimation(.snappy) {
            if side == .a { a = max(0, a + delta) } else { b = max(0, b + delta) }
        }
        error = nil
        store.setLiveScore(match.id, a: a, b: b)
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        withAnimation(.snappy) { (a, b) = last }
        store.setLiveScore(match.id, a: a, b: b)
    }

    private func save() {
        focused = nil
        if store.finish(match.id, a: a, b: b) {
            onSaved()
        } else {
            error = "Skor \(a)–\(b) belum sah untuk \(scoring.hint.lowercased())."
        }
    }
}

// MARK: Tennis race to N

struct TennisScorer: View {
    @Environment(SessionStore.self) private var store
    let match: Match
    let session: Session
    var onSaved: () -> Void

    @State private var score: TennisScore
    @State private var history: [TennisScore] = []

    init(match: Match, session: Session, onSaved: @escaping () -> Void) {
        self.match = match
        self.session = session
        self.onSaved = onSaved
        _score = State(initialValue: TennisScore(gamesA: match.scoreA, gamesB: match.scoreB))
    }

    private var games: Int { session.scoring.target }
    private var golden: Bool {
        if case .tennisRace(_, let golden) = session.scoring { return golden }
        return true
    }
    private var gA: Int { score.games(.a) }
    private var gB: Int { score.games(.b) }
    private var finished: Bool { session.scoring.isValidFinal(gA, gB) }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 6) {
                ForEach(["Race to \(games)", golden ? "Golden point" : "Advantage", "Maks \(games * 2 - 1) game"], id: \.self) {
                    Text($0)
                        .font(.jost(12, .semibold))
                        .foregroundStyle(.ink)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(.surface2, in: Capsule())
                }
            }
            scoreboard
            gameLog
            HStack(spacing: 12) {
                pointButton(.a)
                pointButton(.b)
            }
            quickResults
            HStack(spacing: 10) {
                Button(action: undo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.ghost)
                    .disabled(history.isEmpty)
                Button(action: save) { Label("Simpan Hasil", systemImage: "checkmark") }
                    .buttonStyle(.primary)
                    .disabled(!finished)
            }
        }
    }

    private var scoreboard: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow(text: "Tim", color: .heroMuted).frame(maxWidth: .infinity, alignment: .leading)
                Eyebrow(text: "Game", color: .heroMuted).frame(width: 56)
                Eyebrow(text: "Poin", color: .heroMuted).frame(width: 64)
            }
            .padding(.bottom, 6)
            row(.a)
            row(.b)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.racing, in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private func row(_ side: Side) -> some View {
        let leading = score.games(side) > score.games(side.other)
        return HStack(spacing: 8) {
            Text(session.names(match.team(side)))
                .font(.jost(16, .semibold))
                .foregroundStyle(.onRacing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(score.games(side))")
                .font(.playfair(30, .medium))
                .foregroundStyle(.onRacing)
                .frame(width: 56)
                .contentTransition(.numericText())
            Text(finished ? "–" : score.pointLabel(side))
                .font(.playfair(26, .medium))
                .foregroundStyle(leading ? .racing : .onRacing)
                .frame(width: 64, height: 48)
                .background(leading ? Color.heroAccent : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.sm))
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
    }

    private var gameLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(finished ? "Hasil" : "Game \(min(gA + gB + 1, games * 2 - 1))").font(.jost(13, .semibold)).foregroundStyle(.ink)
                Spacer()
                if let text = status {
                    Text(text).font(.jost(13, .semibold)).foregroundStyle(.brassInk)
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<(games * 2 - 1), id: \.self) { i in
                    let winner = i < score.log.count ? score.log[i] : nil
                    Text(winner.map { $0.rawValue.uppercased() } ?? (i == gA + gB && !finished ? "•" : ""))
                        .font(.jost(11, .bold))
                        .foregroundStyle(winner == .a ? .onRacing : .inkMuted)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(winner == .a ? Color.racing : winner == .b ? .surface2 : .appBackground,
                                    in: RoundedRectangle(cornerRadius: Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(winner == nil ? Color.line : .clear, lineWidth: 1))
                }
            }
        }
    }

    private var status: String? {
        let scoring = session.scoring
        if finished { return "Selesai · \(max(gA, gB))–\(min(gA, gB))" }
        if scoring.isDecider(gA, gB) { return "Game penentu" }
        if let side = scoring.matchPoint(gA, gB) { return "Match point Tim \(side.rawValue.uppercased())" }
        return nil
    }

    private func pointButton(_ side: Side) -> some View {
        let primary = side == .a
        return Button { point(side) } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 24, weight: .semibold))
                Text("Poin Tim \(side.rawValue.uppercased())").font(.jost(15, .semibold))
                Text(session.names(match.team(side))).font(.jost(11)).opacity(0.75).lineLimit(1)
            }
            .foregroundStyle(primary ? .onRacing : .ink)
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.horizontal, 8)
            .background(primary ? Color.racing : .surface, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(primary ? .clear : Color.line, lineWidth: 1))
            .shadow(color: .glow, radius: 9, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(finished)
        .opacity(finished ? 0.4 : 1)
    }

    private var quickResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atau tap hasil akhir").font(.jost(13, .semibold)).foregroundStyle(.inkMuted)
            ForEach([Side.a, .b], id: \.self) { side in
                HStack(spacing: 8) {
                    Text("Tim \(side.rawValue.uppercased())")
                        .font(.jost(12, .semibold))
                        .foregroundStyle(.inkMuted)
                        .frame(width: 44, alignment: .leading)
                    let results = session.scoring.quickResults.filter { side == .a ? $0.a > $0.b : $0.b > $0.a }
                    ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                        let on = finished && gA == result.a && gB == result.b
                        Button {
                            history.append(score)
                            score = TennisScore(gamesA: result.a, gamesB: result.b)
                            store.setLiveScore(match.id, a: result.a, b: result.b)
                        } label: {
                            Text("\(result.a)–\(result.b)")
                                .font(.playfair(18, .medium))
                                .foregroundStyle(on ? .onRacing : .ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(on ? Color.racing : .surface2, in: RoundedRectangle(cornerRadius: Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(on ? .clear : Color.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.line, lineWidth: 1))
    }

    private func point(_ side: Side) {
        history.append(score)
        let before = score.log.count
        withAnimation(.snappy) { score.point(to: side, goldenPoint: golden) }
        if score.log.count != before {
            store.setLiveScore(match.id, a: gA, b: gB)
        }
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        withAnimation(.snappy) { score = last }
        store.setLiveScore(match.id, a: gA, b: gB)
    }

    private func save() {
        if store.finish(match.id, a: gA, b: gB) { onSaved() }
    }
}

/// "06:24 / ±10:00" since the first point.
struct MatchClock: View {
    let startedAt: Date?
    let minutes: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = startedAt.map { max(0, Int(context.date.timeIntervalSince($0))) } ?? 0
            HStack(spacing: 8) {
                Circle().fill(startedAt == nil ? Color.line : .loss).frame(width: 8, height: 8)
                Text(String(format: "%02d:%02d", elapsed / 60, elapsed % 60))
                    .font(.playfair(16, .medium))
                    .monospacedDigit()
                    .foregroundStyle(.ink)
                Text("/ ±\(minutes):00").font(.jost(13)).foregroundStyle(.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
