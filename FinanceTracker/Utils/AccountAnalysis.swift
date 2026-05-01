import Foundation

enum AccountAnalysis {
    /// Returns true if the account has at least 3 snapshot entries and the
    /// most recent 3 entries (by snapshot date desc) are all numerically equal.
    /// Tolerance: <0.01 absolute difference.
    static func isStale(_ account: Account) -> Bool {
        let entries = account.values
            .compactMap { v -> (Date, Double)? in
                guard let s = v.snapshot else { return nil }
                return (s.date, v.nativeValue)
            }
            .sorted { $0.0 > $1.0 }
        guard entries.count >= 3 else { return false }
        let last3 = Array(entries.prefix(3)).map { $0.1 }
        guard let first = last3.first else { return false }
        return last3.allSatisfy { abs($0 - first) < 0.01 }
    }

    /// Distinct identical-value streak across most recent N snapshots, used to
    /// surface "X snapshots unchanged" hint.
    static func unchangedStreak(_ account: Account) -> Int {
        let entries = account.values
            .compactMap { v -> (Date, Double)? in
                guard let s = v.snapshot else { return nil }
                return (s.date, v.nativeValue)
            }
            .sorted { $0.0 > $1.0 }
        guard let first = entries.first else { return 0 }
        var streak = 1
        for i in 1..<entries.count {
            if abs(entries[i].1 - first.1) < 0.01 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
}
