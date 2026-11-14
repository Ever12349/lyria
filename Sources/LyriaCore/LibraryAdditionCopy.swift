import Foundation

/// Toasts for 「添加曲目」. Cancel and a thrown import use their own sentences.
public enum LibraryAdditionCopy {
    public static func toast(added: Int, already: Int, skipped: Int) -> String {
        if skipped > 0 {
            return "已添加 \(added) 首，跳过 \(skipped) 个"
        }
        if added > 0, already > 0 {
            return "已添加 \(added) 首，\(already) 首已在曲库"
        }
        if added > 0 {
            return "已添加 \(added) 首"
        }
        if already > 0 {
            return "已在曲库中"
        }
        return "添加失败"
    }
}
