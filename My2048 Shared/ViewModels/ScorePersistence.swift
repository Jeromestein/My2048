import Foundation

protocol ScorePersistence {
    func loadBestScore(forKey key: String) -> Int
    func save(bestScore: Int, forKey key: String)
}

final class MemoryScorePersistence: ScorePersistence {
    private var storage: [String: Int] = [:]

    func loadBestScore(forKey key: String) -> Int {
        storage[key] ?? 0
    }

    func save(bestScore: Int, forKey key: String) {
        storage[key] = bestScore
    }
}

final class UserDefaultsScorePersistence: ScorePersistence {
    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
    }

    func loadBestScore(forKey key: String) -> Int {
        defaults.integer(forKey: key)
    }

    func save(bestScore: Int, forKey key: String) {
        defaults.set(bestScore, forKey: key)
    }
}
