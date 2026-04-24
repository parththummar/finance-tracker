import Foundation
import AppKit

enum BackupInterval: String, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self { case .daily: return "Daily"; case .weekly: return "Weekly"; case .monthly: return "Monthly" }
    }
    var seconds: TimeInterval {
        switch self {
        case .daily:   return 24 * 3600
        case .weekly:  return 7 * 24 * 3600
        case .monthly: return 30 * 24 * 3600
        }
    }
}

enum BackupService {
    static let storeFilename = "default.store"
    private static let backupsDirName = "FinanceTracker-Backups"
    private static let autoPrefix = "FinanceTracker-auto-"
    private static let manualPrefix = "FinanceTracker-backup-"

    // MARK: - Paths

    static func storeURL() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return nil }
        return appSupport.appendingPathComponent(storeFilename)
    }

    static func backupsDir() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let dir = appSupport.appendingPathComponent(backupsDirName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Listing

    struct BackupFile: Identifiable, Hashable {
        let id: URL
        let url: URL
        let date: Date
        let size: Int64
        let kind: Kind
        enum Kind { case auto, manual, other }
        var name: String { url.lastPathComponent }
    }

    static func list() -> [BackupFile] {
        guard let dir = backupsDir() else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )) ?? []
        return files.compactMap { url -> BackupFile? in
            guard url.pathExtension == "store" else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate ?? .distantPast
            let size = Int64(values?.fileSize ?? 0)
            let kind: BackupFile.Kind
            if url.lastPathComponent.hasPrefix(autoPrefix)   { kind = .auto }
            else if url.lastPathComponent.hasPrefix(manualPrefix) { kind = .manual }
            else { kind = .other }
            return BackupFile(id: url, url: url, date: date, size: size, kind: kind)
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - Auto backup

    /// Runs an auto backup if the configured interval has elapsed.
    @discardableResult
    static func runIfDue() -> URL? {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "autoBackupEnabled") as? Bool ?? true
        guard enabled else { return nil }

        let raw = defaults.string(forKey: "autoBackupInterval") ?? BackupInterval.weekly.rawValue
        let interval = BackupInterval(rawValue: raw) ?? .weekly
        let last = defaults.double(forKey: "lastAutoBackupAt")
        let now = Date().timeIntervalSince1970
        if last > 0, now - last < interval.seconds { return nil }

        guard let dir = backupsDir(), let src = storeURL(),
              FileManager.default.fileExists(atPath: src.path) else { return nil }
        let stamp = timestamp()
        let dest = dir.appendingPathComponent("\(autoPrefix)\(stamp).store")
        guard copyStore(from: src, to: dest) else { return nil }

        defaults.set(now, forKey: "lastAutoBackupAt")
        let keep = defaults.object(forKey: "autoBackupKeep") as? Int ?? 10
        pruneAuto(keep: max(1, keep))
        return dest
    }

    static func backupNow() -> URL? {
        guard let dir = backupsDir(), let src = storeURL(),
              FileManager.default.fileExists(atPath: src.path) else { return nil }
        let dest = dir.appendingPathComponent("\(manualPrefix)\(timestamp()).store")
        return copyStore(from: src, to: dest) ? dest : nil
    }

    private static func pruneAuto(keep: Int) {
        let autos = list().filter { $0.kind == .auto }
        guard autos.count > keep else { return }
        for b in autos.dropFirst(keep) {
            try? FileManager.default.removeItem(at: b.url)
            try? FileManager.default.removeItem(at: b.url.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: b.url.appendingPathExtension("shm"))
        }
    }

    // MARK: - Restore

    /// Replaces the live store files with those from `backupURL`.
    /// Caller must then quit & relaunch — the in-memory ModelContainer still
    /// points at the old file handles.
    static func restore(from backupURL: URL) throws {
        guard let dst = storeURL() else {
            throw NSError(domain: "Backup", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "App Support unavailable."])
        }
        let fm = FileManager.default

        // Safety: copy live store to a "pre-restore" backup first.
        if fm.fileExists(atPath: dst.path), let dir = backupsDir() {
            let safety = dir.appendingPathComponent("\(autoPrefix)pre-restore-\(timestamp()).store")
            _ = copyStore(from: dst, to: safety)
        }

        for ext in ["", ".wal", ".shm"] {
            let dstPath = URL(fileURLWithPath: dst.path + ext)
            if fm.fileExists(atPath: dstPath.path) {
                try fm.removeItem(at: dstPath)
            }
        }

        try fm.copyItem(at: backupURL, to: dst)
        for ext in ["wal", "shm"] {
            let srcSide = backupURL.appendingPathExtension(ext)
            let dstSide = dst.appendingPathExtension(ext)
            if fm.fileExists(atPath: srcSide.path) {
                try? fm.copyItem(at: srcSide, to: dstSide)
            }
        }
    }

    // MARK: - Helpers

    @discardableResult
    private static func copyStore(from src: URL, to dst: URL) -> Bool {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
            for ext in ["wal", "shm"] {
                let s = src.appendingPathExtension(ext)
                let d = dst.appendingPathExtension(ext)
                if fm.fileExists(atPath: d.path) { try? fm.removeItem(at: d) }
                if fm.fileExists(atPath: s.path) {
                    try? fm.copyItem(at: s, to: d)
                }
            }
            return true
        } catch {
            return false
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: Date())
    }

    static func lastAutoBackupDate() -> Date? {
        let t = UserDefaults.standard.double(forKey: "lastAutoBackupAt")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
}
