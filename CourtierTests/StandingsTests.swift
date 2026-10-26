import XCTest
@testable import Courtier

final class StandingsTests: XCTestCase {
    private let andi = Player(name: "Andi"), budi = Player(name: "Budi"), citra = Player(name: "Citra"), dodi = Player(name: "Dodi")

    private func session(_ ranking: RankingMode, _ results: [([Player], [Player], Int, Int)], sitOut: [Player] = []) -> Session {
        var s = Session(players: [andi, budi, citra, dodi], format: .americano, scoring: .tennisRace(games: 3, goldenPoint: true),
                        ranking: ranking, courts: 1, plannedRounds: results.count, minutesPerMatch: 10)
        s.rounds = results.enumerated().map { i, r in
            Round(number: i + 1, matches: [Match(court: 1, teamA: r.0.map(\.id), teamB: r.1.map(\.id), scoreA: r.2, scoreB: r.3, status: .done)],
                  sitOut: sitOut.map(\.id))
        }
        return s
    }

    func testWinsRankAboveGameDifference() {
        // Everyone but Dodi wins twice; the 3-0 win gives Budi and Citra the better difference.
        let s = session(.wins, [
            ([andi, citra], [budi, dodi], 3, 2),
            ([andi, budi], [citra, dodi], 3, 2),
            ([citra, budi], [andi, dodi], 3, 0),
        ])
        let table = Standings.compute(s)
        // Budi and Citra are level on everything (they beat each other once), so the name decides.
        XCTAssertEqual(table.map(\.name), ["Budi", "Citra", "Andi", "Dodi"])
        XCTAssertEqual(table.map(\.won), [2, 2, 2, 0])
        XCTAssertEqual(table.map(\.diff), [3, 3, -1, -5])
        XCTAssertEqual(table.last?.pointsFor, 4, "Dodi's 4 games don't lift him over anyone with a win")
    }

    func testHeadToHeadBreaksAnExactTie() {
        // Andi and Budi both finish 1 win, +1; Budi beat Andi when they met, so Budi ranks higher.
        let eko = Player(name: "Eko")
        var s = Session(players: [andi, budi, citra, dodi, eko], format: .americano, scoring: .tennisRace(games: 3, goldenPoint: true),
                        ranking: .wins, courts: 1, plannedRounds: 2, minutesPerMatch: 10)
        s.rounds = [
            Round(number: 1, matches: [Match(court: 1, teamA: [budi.id, citra.id], teamB: [andi.id, dodi.id], scoreA: 3, scoreB: 2, status: .done)],
                  sitOut: [eko.id]),
            Round(number: 2, matches: [Match(court: 1, teamA: [andi.id, eko.id], teamB: [citra.id, dodi.id], scoreA: 3, scoreB: 1, status: .done)],
                  sitOut: [budi.id]),
        ]
        let table = Standings.compute(s)
        XCTAssertEqual(table.map(\.name), ["Eko", "Budi", "Andi", "Citra", "Dodi"])
        XCTAssertEqual([table[1].won, table[1].diff], [table[2].won, table[2].diff])
    }

    func testTotalPointsModeCreditsRestingPlayersTheRoundAverage() {
        var s = Session(players: [andi, budi, citra, dodi, Player(name: "Eko")], format: .americano,
                        scoring: .rally(target: 21, deuce: false), ranking: .totalPoints, courts: 1, plannedRounds: 1, minutesPerMatch: 10)
        let eko = s.players[4]
        s.rounds = [Round(number: 1, matches: [Match(court: 1, teamA: [andi.id, budi.id], teamB: [citra.id, dodi.id],
                                                      scoreA: 21, scoreB: 15, status: .done)], sitOut: [eko.id])]
        let table = Standings.compute(s)
        XCTAssertEqual(table.first { $0.name == "Eko" }?.totalPoints, 18)
        XCTAssertEqual(table.first?.totalPoints, 21)
    }
}
