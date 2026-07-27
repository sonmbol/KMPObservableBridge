import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct KMPMacroDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(
        domain: "KMPObservableBridgeMacros",
        id: "invalid-declaration"
    )
    let severity = DiagnosticSeverity.error
}

public struct KMPObservableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: KMPMacroDiagnostic(
                        message: "@KMPObservable must be attached to a ViewModel extension."
                    )
                )
            )
            return []
        }
        guard case .argumentList(let arguments) = node.arguments,
              let modelArgument = arguments.first else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: KMPMacroDiagnostic(
                        message: "@KMPObservable requires ViewModel.self and at least one field."
                    )
                )
            )
            return []
        }

        let model = extensionDecl.extendedType.trimmedDescription
        let declaredModel = modelArgument.expression.trimmedDescription
        guard declaredModel == "\(model).self" else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(modelArgument.expression),
                    message: KMPMacroDiagnostic(
                        message: "@KMPObservable model must match the extended type '\(model).self'."
                    )
                )
            )
            return []
        }

        let fields = arguments.dropFirst()
        guard !fields.isEmpty else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: KMPMacroDiagnostic(
                        message: "Swift macros cannot discover properties of imported KMP types; add fields: key paths explicitly."
                    )
                )
            )
            return []
        }
        guard fields.first?.label?.text == "fields",
              fields.dropFirst().allSatisfy({ $0.label == nil }) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: KMPMacroDiagnostic(
                        message: "@KMPObservable fields must use 'fields: \\.state, \\.otherState'."
                    )
                )
            )
            return []
        }

        let entries = fields
            .map {
                "        KMPState<\(model)>.skie(\($0.expression.trimmedDescription))"
            }
            .joined(separator: ",\n")

        return [
            DeclSyntax(
                stringLiteral: """
                public static var kmpObservationPlan: KMPObservationPlan<\(model)> {
                    KMPObservationPlan(
                \(entries)
                    )
                }

                public static func kmpStartObservation(
                    on model: \(model),
                    notify: @escaping KMPObservationNotify,
                    reportError: @escaping KMPObservationErrorHandler
                ) -> KMPObservation {
                    kmpObservationPlan.startObservation(
                        on: model,
                        notify: notify,
                        reportError: reportError
                    )
                }
                """
            ),
        ]
    }
}

@main
struct KMPObservableBridgePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        KMPObservableMacro.self,
    ]
}
