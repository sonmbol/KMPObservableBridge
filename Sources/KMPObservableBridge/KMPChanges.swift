/// A compile-time checked projection used to suppress unrelated emissions.
@MainActor
public struct KMPChanges<Root, Selection: Equatable> {
    let select: @MainActor (Root) -> Selection

    public static func field(
        _ keyPath: KeyPath<Root, Selection>
    ) -> Self {
        Self { $0[keyPath: keyPath] }
    }

    public static func projection(
        _ select: @escaping @MainActor (Root) -> Selection
    ) -> Self {
        Self(select: select)
    }
}
