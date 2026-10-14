import Foundation

extension String {
    /// "1 package", "3 packages": the count with its noun in agreement,
    /// through Foundation's automatic grammar agreement. Irregular plurals
    /// such as "formulae" need their own wording.
    public static func count(_ count: Int, _ noun: String) -> String {
        String(AttributedString(localized: "^[\(count) \(noun)](inflect: true)").characters)
    }
}
