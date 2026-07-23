package com.petros.efthymiou.dailypulse.examples

import com.petros.efthymiou.dailypulse.BaseViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class BridgeExampleViewModel: BaseViewModel() {
    private val _counterState = MutableStateFlow(BridgeExampleState())
    val counterState: StateFlow<BridgeExampleState> get() = _counterState.asStateFlow()

    private val _messageState = MutableStateFlow("Ready")
    val messageState: StateFlow<String> get() = _messageState.asStateFlow()

    val callbackState = BridgeCallbackState("Callback ready")

    fun increment() {
        val nextCount = _counterState.value.count + 1
        _counterState.value = _counterState.value.copy(count = nextCount)
        _messageState.value = "Counter updated to $nextCount"
        callbackState.update("Callback updated to $nextCount")
    }

    fun reset() {
        _counterState.value = BridgeExampleState()
        _messageState.value = "Ready"
        callbackState.update("Callback ready")
    }

    fun simulateLoading() {
        scope.launch {
            _counterState.value = _counterState.value.copy(isLoading = true)
            _messageState.value = "Loading from KMP..."
            callbackState.update("Callback loading...")
            delay(700)
            _counterState.value = _counterState.value.copy(isLoading = false)
            _messageState.value = "Finished loading"
            callbackState.update("Callback finished")
        }
    }
}
