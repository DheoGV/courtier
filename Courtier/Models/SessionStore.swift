import Foundation
import Observation

/// Settings chosen on the setup screen, before a session starts.
struct SessionConfig: Codable, Sendable {
    var players: [Player] = []
    var format: Format = .americano
    var scoring: Scoring = .rally(target: 21, deuce: true)
    var ranking: RankingMode = .wins
    var courts = 2
    var rounds = 8
    var minutesPerMatch = 10

    var units: Int { format == .fixedPartner ? players.count / 2 : players.count }
    var activeCourts: Int { max(0, min(courts, units / format.unitsPerCourt)) }
    var restingPerRound: Int {
        let resting = units - activeCourts * format.unitsPerCourt
        return format == .fixedPartner ? resting * 2 : resting
    }
    var canStart: Bool { activeCourts > 0 }

    /// Fixed-partner teams in entry order: 1&2, 3&4, …
    var teams: [[Player.ID]] {
        stride(from: 0, to: players.count - 1, by: 2).map { [players[$0].id, players[$0 + 1].id] }
    }
}

/// Owns the setup draft and the running session, saved as JSON in Application Support.
@MainActor
@Observable
final class SessionStore {
    var config = SessionConfig() { didSet { save() } }
    private(set) var session: Session? { didSet { save() } }

    private let url: URL?

    /// `persist: false` keeps everything in memory (previews and tests).
    init(persist: Bool = true) {
        if persist, let dir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            url = dir.appending(path: "courtier-state.json")
        } else {
            url = nil
        }
        if let url, let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            config = saved.config
            session = saved.session
        }
    }

    private struct Saved: Codable {
        var config: SessionConfig
        var session: Session?
    }

    private func save() {
        guard let url else { return }
        let data = try? JSONEncoder().encode(Saved(config: config, session: session))
        try? data?.write(to: url, options: .atomic)
    }

    // MARK: Players

    /// Adds one name, or many when a pasted list holds several lines / commas.
    func addPlayers(from text: String) {
        let names = text
            .split(whereSeparator: { $0.isNewline || $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"^\d+[.)]\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
        let existing = Set(config.players.map { $0.name.lowercased() })
        config.players += names.filter { !existing.contains($0.lowercased()) }.map { Player(name: $0) }
    }

    func removePlayer(_ player: Player) {
        config.players.removeAll { $0.id == player.id }
    }

    func shufflePlayers() {
        config.players.shuffle()
    }

    // MARK: Session

    func start() {
        var rng = SystemRandomNumberGenerator()
        start(using: &rng)
    }

    func start<R: RandomNumberGenerator>(using rng: inout R) {
        guard config.canStart else { return }
        var new = Session(
            // The scheduler rotates players by list position, so start from a random order.
            players: config.players.shuffled(using: &rng),
            format: config.format,
            scoring: config.scoring,
            ranking: config.ranking,
            courts: config.courts,
            plannedRounds: max(1, config.rounds),
            minutesPerMatch: config.minutesPerMatch,
            teams: config.format == .fixedPartner ? config.teams : []
        )
        // Americano and Fix Partner are scheduled up front; Mexicano waits for each round's results.
        let upFront = new.format == .mexicano ? 1 : new.plannedRounds
        for _ in 0..<upFront {
            new.rounds.append(Scheduler.nextRound(for: new, using: &rng))
        }
        session = new
    }

    func endSession() {
        session = nil
    }

    /// One more round on top of the plan. Americano / Fix Partner schedule it straight away.
    func addRound() {
        guard var s = session else { return }
        s.plannedRounds += 1
        if s.format != .mexicano {
            var rng = SystemRandomNumberGenerator()
            s.rounds.append(Scheduler.nextRound(for: s, using: &rng))
        }
        session = s
    }

    func generateNextRound() {
        guard var s = session, s.canGenerateNextRound else { return }
        var rng = SystemRandomNumberGenerator()
        s.rounds.append(Scheduler.nextRound(for: s, using: &rng))
        session = s
    }

    // MARK: Scores

    func match(_ id: Match.ID) -> Match? {
        session?.matches.first { $0.id == id }
    }

    /// Saves a live score; the match becomes "live" once a point is scored.
    func setLiveScore(_ id: Match.ID, a: Int, b: Int) {
        update(id) { match in
            match.scoreA = max(0, a)
            match.scoreB = max(0, b)
            if a == 0, b == 0 {
                match.status = .pending
            } else {
                if match.status == .pending { match.startedAt = .now }
                match.status = .live
            }
        }
    }

    /// Stores a final result. Returns false when the score isn't legal for the session's rule.
    @discardableResult
    func finish(_ id: Match.ID, a: Int, b: Int) -> Bool {
        guard let scoring = session?.scoring, scoring.isValidFinal(a, b) else { return false }
        update(id) { match in
            match.scoreA = a
            match.scoreB = b
            match.status = .done
        }
        return true
    }

    func reopen(_ id: Match.ID) {
        update(id) { $0.status = .live }
    }

    private func update(_ id: Match.ID, _ change: (inout Match) -> Void) {
        guard var s = session else { return }
        for r in s.rounds.indices {
            if let m = s.rounds[r].matches.firstIndex(where: { $0.id == id }) {
                change(&s.rounds[r].matches[m])
                session = s
                return
            }
        }
    }
}
