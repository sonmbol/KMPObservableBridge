import Combine
import shared
import KMPObservableBridge

extension BridgeExampleViewModel {
    var callbackPublisher: AnyPublisher<String, Never> {
        BridgeCallbackStatePublisher(state: callbackState)
            .eraseToAnyPublisher()
    }
}

private struct BridgeCallbackStatePublisher: Publisher {
    typealias Output = String
    typealias Failure = Never

    let state: BridgeCallbackState

    func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
    where SubscriberType.Input == String, SubscriberType.Failure == Never {
        let subscription = BridgeCallbackStateSubscription(
            subscriber: subscriber,
            state: state
        )
        subscriber.receive(subscription: subscription)
    }
}

private final class BridgeCallbackStateSubscription<SubscriberType: Subscriber>: Subscription
where SubscriberType.Input == String, SubscriberType.Failure == Never {
    private var subscriber: SubscriberType?
    private var handle: BridgeCallbackHandle?
    private let state: BridgeCallbackState

    init(
        subscriber: SubscriberType,
        state: BridgeCallbackState
    ) {
        self.subscriber = subscriber
        self.state = state
    }

    func request(_ demand: Subscribers.Demand) {
        guard demand > .none, handle == nil else {
            return
        }

        handle = state.watch { [weak self] value in
            _ = self?.subscriber?.receive(value)
        }
    }

    func cancel() {
        handle?.close()
        handle = nil
        subscriber = nil
    }
}
