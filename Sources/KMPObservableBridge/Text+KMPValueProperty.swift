import SwiftUI

public extension Text {
    init<Property>(_ property: Property)
    where Property: KMPValueProperty, Property.Value == String {
        self.init(verbatim: property.value)
    }
}
