import Foundation

/// Remembers a table's sort order across launches.
///
/// Sort rows in the view with `rows.sorted(using: sortOrder)` — never reorder
/// a store's array, which other pages share. Columns are saved by name so a
/// stored order survives app updates.
struct SortOrderStorage<Row> {
    let key: String
    /// Column name → ascending comparator.
    let columns: [String: KeyPathComparator<Row>]
    let defaultColumn: String

    func load() -> [KeyPathComparator<Row>] {
        let defaults = UserDefaults.standard
        let column = defaults.string(forKey: key + ".column").flatMap { columns[$0] }
            ?? columns[defaultColumn]
        guard var comparator = column else { return [] }
        comparator.order = defaults.object(forKey: key + ".ascending") as? Bool == false ? .reverse : .forward
        return [comparator]
    }

    func save(_ order: [KeyPathComparator<Row>]) {
        guard let first = order.first,
              let name = columns.first(where: { $0.value.keyPath == first.keyPath })?.key
        else { return }
        UserDefaults.standard.set(name, forKey: key + ".column")
        UserDefaults.standard.set(first.order == .forward, forKey: key + ".ascending")
    }
}
