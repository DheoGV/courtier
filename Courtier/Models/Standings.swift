import Foundation

/// One leaderboard line: a player (Americano / Mexicano) or a fixed team.
struct Standing: Identifiable, Hashable, Sendable {
    var members: [Player.ID]
    var name: String
    var played = 0
    var won = 0
    var lost = 0
    /// Points (rally) or games (tennis) won and conceded.
    var pointsFor = 0
    var pointsAgainst = 0
    /// Average points credited for resting rounds (total-points ranking only).
    var restBonus = 0

    var id: String { members.map(\.uuidString).joined(separator: "+") }
    var diff: Int { pointsFor - pointsAgainst }
    var totalPoints: Int { pointsFor + restBonus }
    var winRate: Double { played == 0 ? 0 : Double(won) / Double(played) }

    /// The number shown in the big column.
    func headline(_ mode: RankingMode) -> Int { mode == .wins ? won : totalPoints }
}

enum Standings {
    /// Builds the ordered leaderboard from every finished match.
    ///
    /// Wins mode: wins → difference → head-to-head → win rate → name.
    /// Total-points mode: total points → wins → difference → head-to-head → name.
    static func compute(_ session: Session) -> [Standing] {
        let units: [[Player.ID]] = session.format == .fixedPartner ? session.teams : session.players.map { [$0.id] }
        var table = Dictionary(uniqueKeysWithValues: units.map { ($0[0], Standing(members: $0, name: session.names($0))) })
        let unitOf: [Player.ID: Player.ID] = Dictionary(uniqueKeysWithValues: units.flatMap { u in u.map { ($0, u[0]) } })

        for round in session.rounds {
            let done = round.matches.filter { $0.status == .done }
            for match in done {
                for side in [Side.a, .b] {
                    let keys = Set(match.team(side).compactMap { unitOf[$0] })
                    for key in keys {
                        table[key]?.played += 1
                        table[key]?.pointsFor += match.score(side)
                        table[key]?.pointsAgainst += match.score(side.other)
                        if match.winner == side { table[key]?.won += 1 } else { table[key]?.lost += 1 }
                    }
                }
            }
            // Resting players get the round's average score so total-points standings stay fair.
            if session.ranking == .totalPoints, round.isComplete, !done.isEmpty {
                let scores = done.flatMap { [$0.scoreA, $0.scoreB] }
                let average = Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
                for key in Set(round.sitOut.compactMap { unitOf[$0] }) {
                    table[key]?.restBonus += average
                }
            }
        }

        let rows = units.compactMap { table[$0[0]] }
        return rank(rows, mode: session.ranking, matches: session.matches.filter { $0.status == .done }, unitOf: unitOf)
    }

    private static func rank(_ rows: [Standing], mode: RankingMode, matches: [Match], unitOf: [Player.ID: Player.ID]) -> [Standing] {
        func primary(_ s: Standing) -> [Int] {
            mode == .wins ? [s.won, s.diff] : [s.totalPoints, s.won, s.diff]
        }
        let sorted = rows.sorted { primary($0).lexicographicallyPrecedes(primary($1), by: >) }

        // Break ties inside each group with the same primary keys by head-to-head results.
        var result: [Standing] = []
        var index = 0
        while index < sorted.count {
            var end = index + 1
            while end < sorted.count, primary(sorted[end]) == primary(sorted[index]) { end += 1 }
            let group = Array(sorted[index..<end])
            result += group.count == 1 ? group : headToHead(group, matches: matches, unitOf: unitOf)
            index = end
        }
        return result
    }

    /// Wins minus losses in matches where the tied competitors faced each other.
    private static func headToHead(_ group: [Standing], matches: [Match], unitOf: [Player.ID: Player.ID]) -> [Standing] {
        let keys = Set(group.map { $0.members[0] })
        var score: [Player.ID: Int] = [:]
        for match in matches {
            let a = Set(match.teamA.compactMap { unitOf[$0] }).intersection(keys)
            let b = Set(match.teamB.compactMap { unitOf[$0] }).intersection(keys)
            guard !a.isEmpty, !b.isEmpty, let winner = match.winner else { continue }
            for key in a { score[key, default: 0] += winner == .a ? 1 : -1 }
            for key in b { score[key, default: 0] += winner == .b ? 1 : -1 }
        }
        return group.sorted { x, y in
            let hx = score[x.members[0], default: 0], hy = score[y.members[0], default: 0]
            if hx != hy { return hx > hy }
            if x.winRate != y.winRate { return x.winRate > y.winRate }
            return x.name.localizedCaseInsensitiveCompare(y.name) == .orderedAscending
        }
    }
}
