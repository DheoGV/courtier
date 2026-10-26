import Foundation

struct Player: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String

    /// "Andi Rahman" → "AR", "Andi" → "AN".
    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2, let a = words[0].first, let b = words[1].first {
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

enum Side: String, Codable, Sendable {
    case a, b

    var other: Side { self == .a ? .b : .a }
}

enum Format: String, Codable, CaseIterable, Identifiable, Sendable {
    case americano, mexicano, fixedPartner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .americano: "Americano"
        case .mexicano: "Mexicano"
        case .fixedPartner: tr("Fixed Partner", "Fix Partner")
        }
    }

    var summary: String {
        switch self {
        case .americano:
            tr("New partner and opponents every round. Ranked per player.",
               "Partner & lawan diacak tiap babak. Klasemen per individu.")
        case .mexicano:
            tr("Round 1 is random, then courts are set from the standings (1+4 vs 2+3).",
               "Babak 1 acak, berikutnya dipasangkan sesuai klasemen (1+4 vs 2+3).")
        case .fixedPartner:
            tr("Same teams all session, opponents rotate. Ranked per team.",
               "Tim tetap sepanjang sesi, lawan dirotasi. Klasemen per tim.")
        }
    }

    var symbol: String {
        switch self {
        case .americano: "shuffle"
        case .mexicano: "arrow.up.arrow.down"
        case .fixedPartner: "link"
        }
    }

    /// Players (or teams) that share one court.
    var unitsPerCourt: Int { self == .fixedPartner ? 2 : 4 }
}

/// How the leaderboard orders competitors.
enum RankingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Match wins → point/game difference → head-to-head → win rate. Default; fair for race formats.
    case wins
    /// Classic Americano: total points → wins → difference → head-to-head.
    case totalPoints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wins: tr("Wins", "Menang")
        case .totalPoints: tr("Total points", "Total poin")
        }
    }
}

struct Match: Identifiable, Codable, Hashable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending, live, done
    }

    var id = UUID()
    var court: Int
    var teamA: [Player.ID]
    var teamB: [Player.ID]
    var scoreA = 0
    var scoreB = 0
    var status: Status = .pending
    var startedAt: Date?

    func team(_ side: Side) -> [Player.ID] { side == .a ? teamA : teamB }
    func score(_ side: Side) -> Int { side == .a ? scoreA : scoreB }

    func side(of player: Player.ID) -> Side? {
        if teamA.contains(player) { return .a }
        if teamB.contains(player) { return .b }
        return nil
    }

    var winner: Side? {
        guard status == .done, scoreA != scoreB else { return nil }
        return scoreA > scoreB ? .a : .b
    }
}

struct Round: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var number: Int
    var matches: [Match]
    var sitOut: [Player.ID] = []

    var isComplete: Bool { matches.allSatisfy { $0.status == .done } }
    var doneCount: Int { matches.filter { $0.status == .done }.count }
}

struct Session: Identifiable, Codable, Sendable {
    var id = UUID()
    var createdAt = Date()
    var players: [Player]
    var format: Format
    var scoring: Scoring
    var ranking: RankingMode
    var courts: Int
    var plannedRounds: Int
    var minutesPerMatch: Int
    /// Fixed-partner pairs, in entry order. Empty for individual formats.
    var teams: [[Player.ID]] = []
    var rounds: [Round] = []

    func player(_ id: Player.ID) -> Player? { players.first { $0.id == id } }

    func names(_ ids: [Player.ID]) -> String {
        ids.compactMap { player($0)?.name }.joined(separator: " & ")
    }

    /// Courts actually in use: limited by the courts available and by how many full games the players fill.
    var activeCourts: Int {
        let units = format == .fixedPartner ? teams.count : players.count
        return max(0, min(courts, units / format.unitsPerCourt))
    }

    var sitOutPerRound: Int {
        let units = format == .fixedPartner ? teams.count : players.count
        return (units - activeCourts * format.unitsPerCourt) * (format == .fixedPartner ? 2 : 1)
    }

    var estimatedMinutes: Int { plannedRounds * minutesPerMatch }

    var matches: [Match] { rounds.flatMap(\.matches) }

    /// The round people are playing now: the first one with an unfinished match.
    var currentRoundIndex: Int? {
        rounds.firstIndex { !$0.isComplete } ?? (rounds.isEmpty ? nil : rounds.count - 1)
    }

    /// Mexicano builds each round from the standings, so the next one waits until the last is done.
    var canGenerateNextRound: Bool {
        format == .mexicano && (rounds.last?.isComplete ?? true) && rounds.count < plannedRounds
    }
}
