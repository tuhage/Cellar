import Foundation

/// Sizes as brew prints them.
enum ByteSize {
    /// Parses "186.4MB", "17.3KB", "11MB" or "(512B)" — brew uses powers of
    /// 1000 and sometimes wraps sizes in parentheses.
    static func parse(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let multipliers: [(suffix: String, factor: Double)] = [
            ("GB", 1_000_000_000), ("MB", 1_000_000), ("KB", 1_000), ("B", 1),
        ]
        for (suffix, factor) in multipliers where trimmed.hasSuffix(suffix) {
            guard let value = Double(trimmed.dropLast(suffix.count)) else { return nil }
            return Int64((value * factor).rounded())
        }
        return nil
    }
}
