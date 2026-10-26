import Foundation

/// How one match is scored.
enum Scoring: Codable, Hashable, Sendable {
    /// Race to `target` points, one point per rally (like volleyball / badminton).
    /// With `deuce`, the winner needs a 2-point lead, up to `cap`.
    case rally(target: Int, deuce: Bool)
    /// Tennis points (15-30-40) inside games; the first team to win `games` games wins the match.
    case tennisRace(games: Int, goldenPoint: Bool)

    var isTennis: Bool {
        if case .tennisRace = self { return true }
        return false
    }

    /// Points (rally) or games (tennis) needed to win.
    var target: Int {
        switch self {
        case .rally(let target, _): target
        case .tennisRace(let games, _): games
        }
    }

    var label: String {
        switch self {
        case .rally(let target, _): "Rally \(target)"
        case .tennisRace(let games, _): "Race to \(games)"
        }
    }

    var hint: String {
        switch self {
        case .rally(let target, true): "Race to \(target) · deuce selisih 2, maks \(Self.cap(for: target))"
        case .rally(let target, false): "Race to \(target) · tanpa deuce"
        case .tennisRace(let games, let golden):
            "Menang \(games) game = menang match · \(golden ? "golden point" : "advantage")"
        }
    }

    /// Highest score one side can reach; inputs are clamped to it.
    var maxScore: Int {
        switch self {
        case .rally(let target, true): Self.cap(for: target)
        case .rally(let target, false): target
        case .tennisRace(let games, _): games
        }
    }

    /// Deuce ceiling: 11 → 15, 21 → 30.
    static func cap(for target: Int) -> Int {
        target <= 11 ? target + 4 : target + 9
    }

    /// Whether a score is a legal final result for this rule.
    func isValidFinal(_ a: Int, _ b: Int) -> Bool {
        guard a >= 0, b >= 0, a != b else { return false }
        let w = max(a, b), l = min(a, b)
        switch self {
        case .tennisRace(let games, _):
            return w == games && l < games
        case .rally(let target, false):
            return w == target && l < target
        case .rally(let target, true):
            let cap = Self.cap(for: target)
            if w == target { return l <= target - 2 }
            if w > target, w < cap { return w - l == 2 }
            if w == cap { return l == cap - 1 || l == cap - 2 }
            return false
        }
    }

    /// A live score can't go past the end of the match.
    func canScore(_ a: Int, _ b: Int) -> Bool {
        !isValidFinal(a, b)
    }

    /// The side one point (rally) or one game (tennis) away from winning, when only one of them is.
    func matchPoint(_ a: Int, _ b: Int) -> Side? {
        guard canScore(a, b), !isDecider(a, b) else { return nil }
        if isValidFinal(a + 1, b) { return .a }
        if isValidFinal(a, b + 1) { return .b }
        return nil
    }

    /// The next point / game ends the match whoever wins it (2–2 in a race to 3, 29–29 at the cap).
    func isDecider(_ a: Int, _ b: Int) -> Bool {
        canScore(a, b) && isValidFinal(a + 1, b) && isValidFinal(a, b + 1)
    }

    /// Every legal final score, winner first then loser ascending, used for the quick-result grid.
    var quickResults: [(a: Int, b: Int)] {
        guard case .tennisRace(let games, _) = self else { return [] }
        let wins = (0..<games).map { (a: games, b: $0) }
        return wins + wins.map { (a: $0.b, b: $0.a) }
    }
}

/// Live tennis scoring inside one race-to-N match: points → games.
struct TennisScore: Hashable, Sendable {
    var games: [Side: Int] = [.a: 0, .b: 0]
    var points: [Side: Int] = [.a: 0, .b: 0]
    /// Winner of each finished game, in order.
    var log: [Side] = []

    init(gamesA: Int = 0, gamesB: Int = 0) {
        games = [.a: gamesA, .b: gamesB]
    }

    func games(_ side: Side) -> Int { games[side] ?? 0 }

    /// Adds a point and closes the game when it is won.
    mutating func point(to side: Side, goldenPoint: Bool) {
        let p = (points[side] ?? 0) + 1
        let q = points[side.other] ?? 0
        let wonGame = goldenPoint ? p >= 4 : (p >= 4 && p - q >= 2)
        if wonGame {
            games[side] = games(side) + 1
            points = [.a: 0, .b: 0]
            log.append(side)
        } else if !goldenPoint, p == 4, q == 4 {
            // Back to deuce.
            points = [.a: 3, .b: 3]
        } else {
            points[side] = p
        }
    }

    /// "0", "15", "30", "40" or "AD".
    func pointLabel(_ side: Side) -> String {
        let p = points[side] ?? 0, q = points[side.other] ?? 0
        if p >= 3, q >= 3 {
            return p > q ? "AD" : "40"
        }
        return ["0", "15", "30", "40"][min(p, 3)]
    }
}
