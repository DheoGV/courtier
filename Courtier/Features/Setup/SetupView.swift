import SwiftUI

/// "Atur Turnamen": players (no limit), format, scoring, courts & rounds, then generate the schedule.
struct SetupView: View {
    @Environment(SessionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var name = ""
    @State private var showPaste = false
    @State private var confirmReplace = false
    @FocusState private var nameFocused: Bool

    private enum ScoringKind: Hashable { case rally11, rally21, tennis }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let session = store.session { activeSession(session) }
                players
                format
                scoring
                courtsAndRounds
                Button {
                    if store.session == nil { start() } else { confirmReplace = true }
                } label: {
                    Label("Generate Jadwal", systemImage: "shuffle")
                }
                .buttonStyle(.primary)
                .disabled(!store.config.canStart)
                if !store.config.canStart {
                    Text(minimumNote)
                        .font(.caption)
                        .foregroundStyle(.loss)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .tabBarClearance()
        .statusBarScrim()
        .sheet(isPresented: $showPaste) { PastePlayersSheet() }
        .confirmationDialog("Sesi yang berjalan akan diganti.", isPresented: $confirmReplace, titleVisibility: .visible) {
            Button("Mulai sesi baru", role: .destructive, action: start)
        }
    }

    private func start() {
        store.start()
        router.tab = .schedule
    }

    private var minimumNote: String {
        store.config.format == .fixedPartner
            ? "Butuh minimal 4 pemain (2 tim) untuk satu lapangan."
            : "Butuh minimal 4 pemain untuk satu lapangan."
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandRow()
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Sesi baru · \(Date.now.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "id_ID"))))")
                Text("Atur Turnamen")
                    .font(.screenTitle)
                    .foregroundStyle(.ink)
            }
        }
    }

    private func activeSession(_ session: Session) -> some View {
        Button { router.tab = .schedule } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.heroAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sesi berjalan · \(session.format.title)")
                        .font(.jost(15, .semibold))
                    Text("Babak \((session.currentRoundIndex ?? 0) + 1) dari \(session.plannedRounds) · \(session.players.count) pemain")
                        .font(.caption)
                        .foregroundStyle(.heroMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.heroMuted)
            }
            .foregroundStyle(.onRacing)
            .padding(16)
            .background(.racing, in: RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
    }

    private var players: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pemain").font(.sectionTitle).foregroundStyle(.ink)
                Spacer()
                Text("\(store.config.players.count) pemain · tanpa batas")
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
            }
            HStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(.inkMuted)
                    TextField("Ketik nama, Enter untuk tambah", text: $name)
                        .font(.body)
                        .foregroundStyle(.ink)
                        .focused($nameFocused)
                        .submitLabel(.next)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onSubmit(addName)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(.line, lineWidth: 1))

                Button(action: addName) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.onRacing)
                        .frame(width: 48, height: 48)
                        .background(.racing, in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tambah pemain")
            }

            if !store.config.players.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(store.config.players) { player in
                        PlayerChip(player: player) {
                            withAnimation(.snappy) { store.removePlayer(player) }
                        }
                    }
                }
            }

            HStack {
                Button { showPaste = true } label: {
                    Label("Tempel daftar nama", systemImage: "list.clipboard")
                }
                Spacer()
                if store.config.players.count > 1 {
                    Button { withAnimation(.snappy) { store.shufflePlayers() } } label: {
                        Label("Acak urutan", systemImage: "shuffle")
                    }
                }
            }
            .font(.jost(13, .medium))
            .foregroundStyle(.inkMuted)
            .buttonStyle(.plain)

            if store.config.format == .fixedPartner, store.config.players.count >= 2 {
                teamsPreview
            }
        }
    }

    private var teamsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Tim (berurutan, ubah dengan acak urutan)")
            ForEach(Array(store.config.teams.enumerated()), id: \.offset) { index, team in
                HStack {
                    Text("Tim \(index + 1)")
                        .font(.jost(12, .semibold))
                        .foregroundStyle(.brassInk)
                        .frame(width: 48, alignment: .leading)
                    Text(team.compactMap { id in store.config.players.first { $0.id == id }?.name }.joined(separator: " & "))
                        .font(.jost(14, .medium))
                        .foregroundStyle(.ink)
                }
            }
            if store.config.players.count % 2 == 1, let last = store.config.players.last {
                Text("\(last.name) belum punya partner.")
                    .font(.caption)
                    .foregroundStyle(.loss)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surface2, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private var format: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Format Main").font(.sectionTitle).foregroundStyle(.ink)
            ForEach(Format.allCases) { option in
                Button {
                    withAnimation(.snappy) { store.config.format = option }
                } label: {
                    OptionCard(format: option, selected: store.config.format == option)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scoringKind: Binding<ScoringKind> {
        Binding {
            switch store.config.scoring {
            case .rally(let target, _): target == 11 ? .rally11 : .rally21
            case .tennisRace: .tennis
            }
        } set: { kind in
            switch kind {
            case .rally11: store.config.scoring = .rally(target: 11, deuce: deuce)
            case .rally21: store.config.scoring = .rally(target: 21, deuce: deuce)
            case .tennis: store.config.scoring = .tennisRace(games: 3, goldenPoint: true)
            }
        }
    }

    private var deuce: Bool {
        if case .rally(_, let deuce) = store.config.scoring { return deuce }
        return true
    }

    private var scoring: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sistem Poin").font(.sectionTitle).foregroundStyle(.ink)
            Segmented(options: [ScoringKind.rally11, .rally21, .tennis], selection: scoringKind) {
                switch $0 {
                case .rally11: "Rally 11"
                case .rally21: "Rally 21"
                case .tennis: "Tennis"
                }
            }
            Text(store.config.scoring.hint)
                .font(.caption)
                .foregroundStyle(.inkMuted)

            switch store.config.scoring {
            case .rally(let target, let deuce):
                Toggle(isOn: Binding { deuce } set: { store.config.scoring = .rally(target: target, deuce: $0) }) {
                    settingLabel("Deuce", "Harus menang selisih 2 poin")
                }
                .tint(.racing)
            case .tennisRace(let games, let golden):
                HStack {
                    settingLabel("Race to", "Menang \(games) game = menang match")
                    Spacer()
                    ValueStepper(value: Binding { games } set: { store.config.scoring = .tennisRace(games: $0, goldenPoint: golden) },
                                 range: 1...9, label: "Race to")
                }
                Toggle(isOn: Binding { golden } set: { store.config.scoring = .tennisRace(games: games, goldenPoint: $0) }) {
                    settingLabel("Golden point", "40–40: satu poin penentu (tanpa advantage)")
                }
                .tint(.racing)
            }

            HStack {
                settingLabel("Urutan klasemen", store.config.ranking == .wins ? "Menang → selisih → head-to-head" : "Total poin → menang → selisih")
                Spacer()
            }
            Segmented(options: RankingMode.allCases, selection: Bindable(store).config.ranking) { $0.title }
        }
    }

    private var courtsAndRounds: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 14) {
            Text("Lapangan & Babak").font(.sectionTitle).foregroundStyle(.ink)
            HStack {
                settingLabel("Lapangan", "\(store.config.format.unitsPerCourt == 4 ? "4 pemain" : "2 tim") per lapangan")
                Spacer()
                ValueStepper(value: $store.config.courts, range: 1...20, label: "Lapangan")
            }
            HStack {
                settingLabel("Jumlah babak", "Bebas, bisa ditambah saat main")
                Spacer()
                ValueStepper(value: $store.config.rounds, range: 1...99, label: "Jumlah babak")
            }
            HStack {
                settingLabel("Menit per game", "Rata-rata durasi satu pertandingan")
                Spacer()
                ValueStepper(value: $store.config.minutesPerMatch, range: 3...60, label: "Menit per game")
            }
            estimate
        }
    }

    private var estimate: some View {
        let minutes = store.config.rounds * store.config.minutesPerMatch
        let end = Date.now.addingTimeInterval(Double(minutes) * 60)
        let resting = store.config.restingPerRound
        return HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 20))
                .foregroundStyle(.brassInk)
            VStack(alignment: .leading, spacing: 2) {
                Text("± \(minutes) menit · selesai \(end.formatted(date: .omitted, time: .shortened))")
                    .font(.playfair(17, .medium))
                    .foregroundStyle(.ink)
                Text("\(store.config.rounds) babak × \(store.config.minutesPerMatch) mnt · \(store.config.activeCourts) lapangan aktif · \(resting) istirahat/babak")
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(.line, lineWidth: 1))
    }

    private func settingLabel(_ title: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.jost(15, .medium)).foregroundStyle(.ink)
            Text(note).font(.caption).foregroundStyle(.inkMuted)
        }
    }

    private func addName() {
        store.addPlayers(from: name)
        name = ""
        nameFocused = true
    }
}

/// Paste a whole WhatsApp list: one name per line (numbers and commas are fine).
struct PastePlayersSheet: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Satu nama per baris. Nomor urut dan koma otomatis dibersihkan.")
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
                TextEditor(text: $text)
                    .font(.body)
                    // Names aren't dictionary words: autocorrect turns "Citra" into "Cites".
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(.line, lineWidth: 1))
            }
            .padding(Space.gutter)
            .background(.appBackground)
            .navigationTitle("Tempel daftar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        store.addPlayers(from: text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    SetupView()
        .environment(SessionStore(persist: false))
        .environment(AppRouter())
        .background(.appBackground)
}
