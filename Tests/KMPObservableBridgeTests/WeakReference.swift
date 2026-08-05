final class WeakReference<Value: AnyObject> {
    private(set) weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}
