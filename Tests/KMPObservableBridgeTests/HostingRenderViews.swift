#if os(iOS) || os(macOS)
import SwiftUI
@testable import KMPObservableBridge

@MainActor
struct HostingRoot: View {
    let model: HostingModel
    let probe: HostingRenderProbe
    let mode: HostingObservationMode

    var body: some View {
        VStack {
            field(.first)
            field(.second)
        }
    }

    @ViewBuilder
    private func field(_ field: HostedField) -> some View {
        switch mode {
        case .runtime:
            HostedProjectedField(
                model: model,
                field: field,
                probe: probe
            )
        case .forcedFallback:
            FallbackHostedProjectedField(
                model: model,
                field: field,
                probe: probe
            )
        }
    }
}

@MainActor
private struct HostedProjectedField: View {
    @KMPObservedObject private var model: HostingModel
    let field: HostedField
    let probe: HostingRenderProbe

    init(
        model: HostingModel,
        field: HostedField,
        probe: HostingRenderProbe
    ) {
        _model = KMPObservedObject(
            model,
            updatePolicy: .immediate,
            failurePolicy: .ignore
        )
        self.field = field
        self.probe = probe
    }

    var body: some View {
        let value: Int
        switch field {
        case .first:
            value = $model.first
        case .second:
            value = $model.second
        }
        return Text(verbatim: probe.record(field, value: value))
    }
}

@MainActor
private struct FallbackHostedProjectedField: View {
    @StateObject private var storage: KMPViewModelStore<HostingModel>
    let field: HostedField
    let probe: HostingRenderProbe

    init(
        model: HostingModel,
        field: HostedField,
        probe: HostingRenderProbe
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                model,
                source: .staticPlan(HostingModel.kmpObservationPlan),
                updatePolicy: .immediate,
                failurePolicy: .ignore,
                ownsModel: false,
                modernObservationEnabled: false
            )
        )
        self.field = field
        self.probe = probe
    }

    var body: some View {
        let value: Int
        switch field {
        case .first:
            value = storage.first
        case .second:
            value = storage.second
        }
        return Text(verbatim: probe.record(field, value: value))
    }
}
#endif
