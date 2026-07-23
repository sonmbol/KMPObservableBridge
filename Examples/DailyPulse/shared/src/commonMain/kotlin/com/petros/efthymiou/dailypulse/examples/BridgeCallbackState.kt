package com.petros.efthymiou.dailypulse.examples

class BridgeCallbackHandle(
    private val onClose: () -> Unit
) {
    fun close() {
        onClose()
    }
}

class BridgeCallbackState(
    initialValue: String
) {
    private val observers = mutableMapOf<Int, (String) -> Unit>()
    private var nextObserverId = 0
    private var currentValue = initialValue

    val value: String
        get() = currentValue

    fun update(value: String) {
        currentValue = value
        observers.values.forEach { observer ->
            observer(value)
        }
    }

    fun watch(observer: (String) -> Unit): BridgeCallbackHandle {
        val observerId = nextObserverId++
        observers[observerId] = observer
        observer(currentValue)

        return BridgeCallbackHandle {
            observers.remove(observerId)
        }
    }
}
