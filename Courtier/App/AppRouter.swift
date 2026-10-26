import Observation

enum AppTab: CaseIterable, Hashable {
    case setup, schedule, score, leaderboard

    var title: String {
        switch self {
        case .setup: tr("Session", "Sesi")
        case .schedule: tr("Schedule", "Jadwal")
        case .score: tr("Score", "Skor")
        case .leaderboard: tr("Standings", "Klasemen")
        }
    }

    var symbol: String {
        switch self {
        case .setup: "person.2"
        case .schedule: "calendar"
        case .score: "smallcircle.filled.circle"
        case .leaderboard: "trophy"
        }
    }
}

/// App-wide navigation state: selected tab and the match open on the score tab.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .setup
    var scoringMatch: Match.ID?

    func score(_ match: Match.ID) {
        scoringMatch = match
        tab = .score
    }
}
