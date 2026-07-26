import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import KMPObservableBridgeMacros

final class KMPObservableBridgeMacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "KMPObservable": KMPObservableMacro.self,
    ]

    func testObservableExpansion() {
        assertMacroExpansion(
            """
            @KMPObservable(
                ProfileViewModel.self,
                fields: \\.profileState, \\.permissionsState
            )
            extension ProfileViewModel: @retroactive KMPStaticallyObservable {}
            """,
            expandedSource: """
            extension ProfileViewModel: @retroactive KMPStaticallyObservable {

                public static var kmpObservationPlan: KMPObservationPlan<ProfileViewModel> {
                    KMPObservationPlan(
                        KMPState<ProfileViewModel>.skie(\\.profileState),
                        KMPState<ProfileViewModel>.skie(\\.permissionsState)
                    )
                }

                public static func kmpStartObservation(
                    on model: ProfileViewModel,
                    notify: @escaping KMPObservationNotify,
                    reportError: @escaping KMPObservationErrorHandler
                ) -> KMPObservation {
                    kmpObservationPlan.startObservation(
                        on: model,
                        notify: notify,
                        reportError: reportError
                    )
                }
            }
            """,
            macros: macros
        )
    }
}
