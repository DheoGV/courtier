import XCTest
@testable import Courtier

final class SchedulerTests: XCTestCase {
    private func players(_ count: Int) -> [Player] {
        (1...count).map { Player(name: "P\($0)") }
    }

    private func session(_ format: Format, players count: Int, courts: Int, rounds: Int) -> Session {
        let ps = players(count)
        let teams = format == .fixedPartner ? stride(from: 0, to: count - 1, by: 2).map { [ps[$0].id, ps[$0 + 1].id] } : []
        return Session(players: ps, format: format, scoring: .tennisRace(games: 3, goldenPoint: true), ranking: .wins,
                       courts: courts, plannedRounds: rounds, minutesPerMatch: 10, teams: teams)
    }

    func testAmericanoEightPlayersSevenRoundsNeverRepeatsAPartner() {
        var s = session(.americano, players: 8, courts: 2, rounds: 7)
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<7 { s.rounds.append(Scheduler.nextRound(for: s, using: &rng)) }

        let partners = Scheduler.tallies(s.rounds).partners
        XCTAssertEqual(partners.count, 28, "every one of the 28 pairs partners once")
        XCTAssertEqual(partners.values.max(), 1)
        for round in s.rounds {
            let ids = round.matches.flatMap { $0.teamA + $0.teamB }
            XCTAssertEqual(Set(ids).count, 8, "everyone plays once per round")
        }
    }

    func testSitOutsRotateFairly() {
        var s = session(.americano, players: 10, courts: 3, rounds: 10)
        XCTAssertEqual(s.activeCourts, 2)
        XCTAssertEqual(s.sitOutPerRound, 2)
        var rng = SeededGenerator(seed: 3)
        for _ in 0..<10 { s.rounds.append(Scheduler.nextRound(for: s, using: &rng)) }

        var rested: [Player.ID: Int] = [:]
        for round in s.rounds {
            XCTAssertEqual(round.sitOut.count, 2)
            XCTAssertTrue(Set(round.sitOut).isDisjoint(with: round.matches.flatMap { $0.teamA + $0.teamB }))
            round.sitOut.forEach { rested[$0, default: 0] += 1 }
        }
        XCTAssertEqual(Set(rested.values), [2], "20 rests spread evenly over 10 players")
    }

    func testMexicanoPairsOneAndFourAgainstTwoAndThree() {
        var s = session(.mexicano, players: 4, courts: 1, rounds: 3)
        var rng = SeededGenerator(seed: 1)
        s.rounds.append(Scheduler.nextRound(for: s, using: &rng))
        // Round 1: team A wins 3-0, so its players lead the table.
        s.rounds[0].matches[0].scoreA = 3
        s.rounds[0].matches[0].status = .done
        let first = s.rounds[0].matches[0]

        let order = Standings.compute(s).map { $0.members[0] }
        let next = Scheduler.nextRound(for: s, using: &rng).matches[0]
        // 1+4 were not partners last round (1 and 2 were), so the classic split applies.
        XCTAssertEqual(Set(next.teamA), Set([order[0], order[3]]))
        XCTAssertEqual(Set(next.teamB), Set([order[1], order[2]]))
        XCTAssertNotEqual(Set(next.teamA), Set(first.teamA))
    }

    func testFixedPartnerKeepsTeamsTogether() {
        var s = session(.fixedPartner, players: 8, courts: 2, rounds: 3)
        var rng = SeededGenerator(seed: 9)
        for _ in 0..<3 { s.rounds.append(Scheduler.nextRound(for: s, using: &rng)) }
        let teams = Set(s.teams.map { Set($0) })
        for match in s.matches {
            XCTAssertTrue(teams.contains(Set(match.teamA)))
            XCTAssertTrue(teams.contains(Set(match.teamB)))
        }
        // 4 teams, 3 rounds: a full round-robin, nobody meets twice.
        let meetings = s.matches.map { Set([match0($0.teamA), match0($0.teamB)]) }
        XCTAssertEqual(Set(meetings).count, 6)
    }

    private func match0(_ team: [Player.ID]) -> Player.ID { team[0] }
}
