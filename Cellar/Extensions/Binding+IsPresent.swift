import SwiftUI

extension Binding {
    /// `true` while the optional holds a value; setting `false` clears it.
    /// Presents a dialog or sheet for an optional, such as a pending action.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { if !$0 { wrappedValue = nil } }
        )
    }
}
