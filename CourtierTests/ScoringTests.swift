import XCTest
@testable import Courtier

final class ScoringTests: XCTestCase {
    func testRaceToThreeAcceptsOnlyRealFinals() {
        let race = Scoring.tennisRace(games: 3, goldenPoint: true)
        for (a, b) in [(3, 0), (3, 1), (3, 2), (0, 3), (1, 3), (2, 3)] {
            XCTAssertTrue(race.isValidFinal(a, b), "\(a)-\(b)")
        }
        for (a, b) in [(3, 3), (4, 1), (2, 1), (0, 0)] {
            XCTAssertFalse(race.isValidFinal(a, b), "\(a)-\(b)")
        }
        XCTAssertEqual(race.quickResults.map { "\($0.a)-\($0.b)" }, ["3-0", "3-1", "3-2", "0-3", "1-3", "2-3"])
        XCTAssertNil(race.matchPoint(2, 2))
        XCTAssertTrue(race.isDecider(2, 2))
        XCTAssertEqual(race.matchPoint(2, 1), .a)
    }

    func testRallyWithDeuceNeedsTwoClearPointsUpToTheCap() {
        let rally = Scoring.rally(target: 21, deuce: true)
        XCTAssertTrue(rally.isValidFinal(21, 19))
        XCTAssertFalse(rally.isValidFinal(21, 20))
        XCTAssertTrue(rally.isValidFinal(22, 20))
        XCTAssertFalse(rally.isValidFinal(23, 20))
        XCTAssertTrue(rally.isValidFinal(30, 29))
        XCTAssertFalse(rally.isValidFinal(31, 29))
        XCTAssertEqual(rally.matchPoint(20, 18), .a)
        XCTAssertNil(rally.matchPoint(20, 20))
        XCTAssertNil(rally.matchPoint(29, 29))
        XCTAssertTrue(rally.isDecider(29, 29))
    }

    func testRallyWithoutDeuceEndsAtTarget() {
        let rally = Scoring.rally(target: 11, deuce: false)
        XCTAssertTrue(rally.isValidFinal(11, 10))
        XCTAssertFalse(rally.isValidFinal(12, 10))
        XCTAssertFalse(rally.canScore(11, 4))
    }

    func testTennisGameWithAdvantage() {
        var score = TennisScore()
        for _ in 0..<3 { score.point(to: .a, goldenPoint: false) }
        for _ in 0..<3 { score.point(to: .b, goldenPoint: false) }
        XCTAssertEqual(score.pointLabel(.a), "40")
        score.point(to: .a, goldenPoint: false)
        XCTAssertEqual(score.pointLabel(.a), "AD")
        score.point(to: .b, goldenPoint: false)
        XCTAssertEqual([score.pointLabel(.a), score.pointLabel(.b)], ["40", "40"])
        score.point(to: .b, goldenPoint: false)
        score.point(to: .b, goldenPoint: false)
        XCTAssertEqual(score.games(.b), 1)
        XCTAssertEqual(score.log, [.b])
    }

    func testGoldenPointDecidesAtFortyAll() {
        var score = TennisScore()
        for _ in 0..<3 {
            score.point(to: .a, goldenPoint: true)
            score.point(to: .b, goldenPoint: true)
        }
        score.point(to: .b, goldenPoint: true)
        XCTAssertEqual(score.games(.b), 1)
        XCTAssertEqual(score.pointLabel(.a), "0")
    }
}
