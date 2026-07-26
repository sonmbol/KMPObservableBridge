import SwiftUI

/// A KMP wrapper that exposes its current value through a `value` property.
@dynamicMemberLookup
public protocol KMPValueProperty {
    associatedtype Value

    var value: Value { get }
}

public extension KMPValueProperty {
    subscript<Member>(
        dynamicMember keyPath: KeyPath<Value, Member>
    ) -> Member {
        value[keyPath: keyPath]
    }
}

public extension Text {
    init<Property>(_ property: Property)
    where Property: KMPValueProperty, Property.Value == String {
        self.init(verbatim: property.value)
    }
}
