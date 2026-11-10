import Foundation

/// One recorded audio path after a Trash attempt. Artwork is not included.
public enum LibraryRemovalFileResult: Equatable, Sendable {
    case missing
    case trashed
    case failed
}

/// One track. Missing aliases do not make a track missing when another path was trashed.
public enum LibraryRemovalTrackOutcome: Equatable, Sendable {
    case success
    case missing
    case failed
}

/// Confirmation and toast copy for 「从曲库移除」 / 「移到废纸篓」.
public enum LibraryRemovalCopy {
    public static let deleteFailed = "移除曲目失败"

    public static func confirmTitle(count: Int, singleTitle: String?) -> String {
        if count <= 1 {
            guard let singleTitle, !singleTitle.isEmpty else { return "从曲库移除？" }
            return "从曲库移除「\(singleTitle)」？"
        }
        return "从曲库移除 \(count) 首？"
    }

    public static func confirmMessage(mentionsICloud: Bool) -> String {
        let base = "也会从播放列表里去掉。文件可以留在磁盘，或移到废纸篓。"
        guard mentionsICloud else { return base }
        return base + "其中有 iCloud 文件；若移到废纸篓，其他设备上也会去掉，30 天内可从废纸篓找回。"
    }

    public static func libraryOnlyToast(count: Int, singleTitle: String) -> String {
        if count <= 1 { return "已从曲库移除「\(singleTitle)」" }
        return "已从曲库移除 \(count) 首"
    }

    /// Failed wins. Any trashed path with no failure is success, even if other paths are missing.
    public static func trackOutcome(fileResults: [LibraryRemovalFileResult]) -> LibraryRemovalTrackOutcome {
        if fileResults.contains(.failed) { return .failed }
        if fileResults.contains(.trashed) { return .success }
        return .missing
    }

    public static func trashToast(outcomes: [LibraryRemovalTrackOutcome], singleTitle: String) -> String {
        let success = outcomes.filter { $0 == .success }.count
        let missing = outcomes.filter { $0 == .missing }.count
        let failed = outcomes.filter { $0 == .failed }.count
        if outcomes.isEmpty { return deleteFailed }
        if missing == 0, failed == 0 {
            if outcomes.count == 1 { return "已将「\(singleTitle)」移到废纸篓" }
            return "已移到废纸篓 \(success) 首"
        }
        if success == 0, failed == 0 {
            if outcomes.count == 1 { return "已从曲库移除「\(singleTitle)」，找不到文件" }
            return "已从曲库移除 \(missing) 首，找不到文件"
        }
        if success == 0, missing == 0 {
            if outcomes.count == 1 { return "已从曲库移除「\(singleTitle)」，没能移到废纸篓" }
            return "已从曲库移除 \(failed) 首，没能移到废纸篓"
        }
        if success > 0, failed == 0 {
            return "已移到废纸篓 \(success) 首，\(missing) 首找不到文件"
        }
        if success > 0, missing == 0 {
            return "已移到废纸篓 \(success) 首，\(failed) 首没能移到废纸篓"
        }
        if success > 0 {
            return "已移到废纸篓 \(success) 首，\(missing) 首找不到文件，\(failed) 首没能移到废纸篓"
        }
        return "已从曲库移除 \(missing + failed) 首，\(missing) 首找不到文件，\(failed) 首没能移到废纸篓"
    }
}
