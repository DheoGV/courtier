import Foundation

/// Builds rounds for every format. Pure: same session + same random source → same round.
enum Scheduler {
    /// Random pairings tried per Americano / Fix Partner round; the one with the fewest repeats wins.
    static let attempts = 400

    static func nextRound<R: RandomNumberGenerator>(for session: Session, using rng: inout R) -> Round {
        let number = session.rounds.count + 1
        switch session.format {
        case .americano:
            let ids = session.players.map(\.id)
            // Everyone plays and the count is a multiple of 4: the circle method gives every pair
            // exactly one round as partners over N−1 rounds.
            if session.sitOutPerRound == 0, ids.count % 4 == 0, session.rounds.count < ids.count - 1 {
                let pairs = circlePairs(ids, round: session.rounds.count)
                return Round(number: number, matches: matches(bestCourts(for: pairs, history: session.rounds, using: &rng)))
            }
            let (active, sitOut) = pickSitOut(units: ids.map { [$0] }, session: session, using: &rng)
            let courts = bestIndividualPairing(active.flatMap { $0 }, history: session.rounds, using: &rng)
            return Round(number: number, matches: matches(courts), sitOut: sitOut.flatMap { $0 })
        case .mexicano:
            let (active, sitOut) = pickSitOut(units: session.players.map { [$0.id] }, session: session, using: &rng)
            let courts = mexicanoPairing(active.flatMap { $0 }, session: session, using: &rng)
            return Round(number: number, matches: matches(courts), sitOut: sitOut.flatMap { $0 })
        case .fixedPartner:
            let (active, sitOut) = pickSitOut(units: session.teams, session: session, using: &rng)
            let courts = bestTeamPairing(active, history: session.rounds, using: &rng)
            return Round(number: number, matches: matches(courts), sitOut: sitOut.flatMap { $0 })
        }
    }

    private static func matches(_ courts: [([Player.ID], [Player.ID])]) -> [Match] {
        courts.enumerated().map { Match(court: $0.offset + 1, teamA: $0.element.0, teamB: $0.element.1) }
    }

    // MARK: Sit-out rotation

    /// Units (players, or fixed teams) that don't fit on a court rest this round:
    /// those who rested least so far, then those who rested longest ago.
    static func pickSitOut<R: RandomNumberGenerator>(
        units: [[Player.ID]], session: Session, using rng: inout R
    ) -> (active: [[Player.ID]], sitOut: [[Player.ID]]) {
        let sitCount = units.count - session.activeCourts * session.format.unitsPerCourt
        guard sitCount > 0 else { return (units, []) }

        var count: [Player.ID: Int] = [:]
        var last: [Player.ID: Int] = [:]
        for round in session.rounds {
            for id in round.sitOut {
                count[id, default: 0] += 1
                last[id] = round.number
            }
        }
        let ranked = units.shuffled(using: &rng).sorted { x, y in
            let cx = count[x[0], default: 0], cy = count[y[0], default: 0]
            if cx != cy { return cx < cy }
            return last[x[0], default: 0] < last[y[0], default: 0]
        }
        let sitOut = Array(ranked.prefix(sitCount))
        let resting = Set(sitOut.flatMap { $0 })
        return (units.filter { !resting.contains($0[0]) }, sitOut)
    }

    // MARK: Americano

    struct PairKey: Hashable {
        let a: Player.ID, b: Player.ID
        init(_ x: Player.ID, _ y: Player.ID) {
            (a, b) = x.uuidString < y.uuidString ? (x, y) : (y, x)
        }
    }

    /// How often each pair has been partners and opponents in the rounds so far.
    static func tallies(_ rounds: [Round]) -> (partners: [PairKey: Int], opponents: [PairKey: Int]) {
        var partners: [PairKey: Int] = [:], opponents: [PairKey: Int] = [:]
        for match in rounds.flatMap(\.matches) {
            for team in [match.teamA, match.teamB] where team.count == 2 {
                partners[PairKey(team[0], team[1]), default: 0] += 1
            }
            for x in match.teamA {
                for y in match.teamB { opponents[PairKey(x, y), default: 0] += 1 }
            }
        }
        return (partners, opponents)
    }

    /// Round-robin partner pairs: the first player stays put, the rest rotate one step per round.
    static func circlePairs(_ ids: [Player.ID], round: Int) -> [[Player.ID]] {
        let n = ids.count
        let rest = Array(ids.dropFirst())
        let shift = round % (n - 1)
        let order = [ids[0]] + Array(rest[shift...] + rest[..<shift])
        return (0..<n / 2).map { [order[$0], order[n - 1 - $0]] }
    }

    /// Puts fixed partner pairs on courts, two pairs per court, minimising repeated opponents.
    static func bestCourts<R: RandomNumberGenerator>(
        for pairs: [[Player.ID]], history: [Round], using rng: inout R
    ) -> [([Player.ID], [Player.ID])] {
        let opponents = tallies(history).opponents
        var best: [([Player.ID], [Player.ID])] = []
        var bestCost = Int.max
        for _ in 0..<attempts {
            let order = pairs.shuffled(using: &rng)
            var courts: [([Player.ID], [Player.ID])] = []
            var total = 0
            for start in stride(from: 0, to: order.count - 1, by: 2) {
                for x in order[start] { for y in order[start + 1] { total += opponents[PairKey(x, y), default: 0] } }
                courts.append((order[start], order[start + 1]))
            }
            if total < bestCost {
                best = courts
                bestCost = total
                if total == 0 { break }
            }
        }
        return best
    }

    /// Splits players into courts of four, minimising repeated partners (heavily) and repeated opponents.
    static func bestIndividualPairing<R: RandomNumberGenerator>(
        _ players: [Player.ID], history: [Round], using rng: inout R
    ) -> [([Player.ID], [Player.ID])] {
        let (partners, opponents) = tallies(history)
        func cost(_ t1: [Player.ID], _ t2: [Player.ID]) -> Int {
            var c = partners[PairKey(t1[0], t1[1]), default: 0] * 100 + partners[PairKey(t2[0], t2[1]), default: 0] * 100
            for x in t1 { for y in t2 { c += opponents[PairKey(x, y), default: 0] * 10 } }
            return c
        }

        var best: [([Player.ID], [Player.ID])] = []
        var bestCost = Int.max
        for _ in 0..<attempts {
            let order = players.shuffled(using: &rng)
            var courts: [([Player.ID], [Player.ID])] = []
            var total = 0
            for start in stride(from: 0, to: order.count - 3, by: 4) {
                let g = Array(order[start..<start + 4])
                let options = [([g[0], g[1]], [g[2], g[3]]), ([g[0], g[2]], [g[1], g[3]]), ([g[0], g[3]], [g[1], g[2]])]
                let pick = options.min { cost($0.0, $0.1) < cost($1.0, $1.1) }!
                total += cost(pick.0, pick.1)
                courts.append(pick)
            }
            if total < bestCost {
                best = courts
                bestCost = total
                if total == 0 { break }
            }
        }
        return best
    }

    // MARK: Mexicano

    /// Round 1 is random. After that, players are sorted by the standings and grouped by four per court:
    /// 1+4 vs 2+3, or 1+3 vs 2+4 when 1+4 / 2+3 were already partners last round.
    static func mexicanoPairing<R: RandomNumberGenerator>(
        _ players: [Player.ID], session: Session, using rng: inout R
    ) -> [([Player.ID], [Player.ID])] {
        guard !session.rounds.isEmpty else {
            return bestIndividualPairing(players, history: [], using: &rng)
        }
        let rank = Dictionary(uniqueKeysWithValues: Standings.compute(session).enumerated().map { ($0.element.members[0], $0.offset) })
        let ordered = players.sorted { rank[$0, default: .max] < rank[$1, default: .max] }
        let lastPartners = tallies(session.rounds.suffix(1)).partners

        return stride(from: 0, to: ordered.count - 3, by: 4).map { start in
            let g = Array(ordered[start..<start + 4])
            let repeats = lastPartners[PairKey(g[0], g[3])] != nil || lastPartners[PairKey(g[1], g[2])] != nil
            return repeats ? ([g[0], g[2]], [g[1], g[3]]) : ([g[0], g[3]], [g[1], g[2]])
        }
    }

    // MARK: Fix Partner

    /// Pairs fixed teams against each other, minimising repeated opponents.
    static func bestTeamPairing<R: RandomNumberGenerator>(
        _ teams: [[Player.ID]], history: [Round], using rng: inout R
    ) -> [([Player.ID], [Player.ID])] {
        var met: [PairKey: Int] = [:]
        for match in history.flatMap(\.matches) {
            met[PairKey(match.teamA[0], match.teamB[0]), default: 0] += 1
        }
        var best: [([Player.ID], [Player.ID])] = []
        var bestCost = Int.max
        for _ in 0..<attempts {
            let order = teams.shuffled(using: &rng)
            var courts: [([Player.ID], [Player.ID])] = []
            var total = 0
            for start in stride(from: 0, to: order.count - 1, by: 2) {
                total += met[PairKey(order[start][0], order[start + 1][0]), default: 0]
                courts.append((order[start], order[start + 1]))
            }
            if total < bestCost {
                best = courts
                bestCost = total
                if total == 0 { break }
            }
        }
        return best
    }
}

/// Deterministic generator for tests and reproducible schedules (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
