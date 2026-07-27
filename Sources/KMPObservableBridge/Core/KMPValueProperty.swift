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
