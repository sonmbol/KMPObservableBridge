import Foundation
import PathKit
import XcodeProj

private struct SymbolGraph: Decodable {
    struct Metadata: Decodable {
        struct Version: Decodable {
            let major: Int
        }

        let formatVersion: Version
    }

    struct Symbol: Decodable {
        struct Identifier: Decodable {
            let precise: String
        }

        struct Kind: Decodable {
            let identifier: String
        }

        struct Names: Decodable {
            let title: String
        }

        struct Fragment: Decodable {
            let kind: String
            let spelling: String
            let preciseIdentifier: String?
        }

        let identifier: Identifier
        let kind: Kind
        let names: Names
        let pathComponents: [String]
        let declarationFragments: [Fragment]?
    }

    struct Relationship: Decodable {
        let kind: String
        let source: String
        let target: String
    }

    let metadata: Metadata
    let symbols: [Symbol]
    let relationships: [Relationship]
}

private struct Options {
    let symbolGraph: URL?
    let framework: URL?
    let module: String?
    let xcodeProject: URL?
    let target: String?
    let output: URL

    init(arguments: [String]) throws {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag),
                  arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }

        guard let output = value(after: "--output") else {
            throw GeneratorError.usage
        }

        symbolGraph = value(after: "--symbol-graph").map {
            URL(fileURLWithPath: $0)
        }
        framework = value(after: "--framework").map {
            URL(fileURLWithPath: $0)
        }
        module = value(after: "--module")
        xcodeProject = value(after: "--xcode-project").map {
            URL(fileURLWithPath: $0)
        }
        target = value(after: "--target")
        self.output = URL(fileURLWithPath: output)

        guard (symbolGraph != nil && module != nil)
                || framework != nil else {
            throw GeneratorError.usage
        }
        guard (xcodeProject == nil) == (target == nil) else {
            throw GeneratorError.usage
        }
    }
}

private enum GeneratorError: LocalizedError {
    case usage
    case unsupportedSymbolGraph(Int)
    case noStateFlows
    case missingEnvironment(String)
    case processFailed(String, Int32)
    case invalidXcodeProject(String)
    case targetNotFound(String)
    case outputOutsideProject(String)
    case sourcesBuildPhaseNotFound(String)
    case projectRegistered(String, String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return """
            Usage:
              kmp-observable-bridge-generator \
                --symbol-graph <file> --module <Swift module> --output <file>
              kmp-observable-bridge-generator \
                --framework <framework> [--module <Swift module>] --output <file> \
                [--xcode-project <project.xcodeproj> --target <target>]
            """
        case .unsupportedSymbolGraph(let major):
            return "Unsupported symbol graph format major version \(major)."
        case .noStateFlows:
            return "No public SKIE StateFlow properties were found."
        case .missingEnvironment(let name):
            return "Required Xcode build environment variable \(name) is missing."
        case .processFailed(let command, let status):
            return "\(command) failed with exit status \(status)."
        case .invalidXcodeProject(let path):
            return "The Xcode project at \(path) has no root project or main group."
        case .targetNotFound(let name):
            return "The Xcode project does not contain a native target named \(name)."
        case .outputOutsideProject(let path):
            return "Generated output must be inside the Xcode project's directory: \(path)"
        case .sourcesBuildPhaseNotFound(let target):
            return "Target \(target) has no Compile Sources build phase."
        case .projectRegistered(let file, let target):
            return """
            Registered \(file) with target \(target). Xcode planned this build \
            before registration, so this first build stops intentionally. \
            Build again; future generation is automatic.
            """
        }
    }
}

private let supportedStateFlowNames: Set<String> = [
    "SkieSwiftStateFlow",
    "SkieSwiftMutableStateFlow",
    "SkieSwiftOptionalStateFlow",
    "SkieSwiftOptionalMutableStateFlow",
]

private func run(
    _ executable: URL,
    arguments: [String],
    directory: URL? = nil,
    environment: [String: String]? = nil,
    captureOutput: Bool = false
) throws -> Data {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = directory
    if let environment {
        process.environment = environment
    }

    let pipe = Pipe()
    if captureOutput {
        process.standardOutput = pipe
    } else {
        process.standardOutput = FileHandle.standardOutput
    }
    process.standardError = FileHandle.standardError
    try process.run()
    let output = captureOutput
        ? pipe.fileHandleForReading.readDataToEndOfFile()
        : Data()
    process.waitUntilExit()
    guard process.terminationStatus == EXIT_SUCCESS else {
        throw GeneratorError.processFailed(
            ([executable.path] + arguments).joined(separator: " "),
            process.terminationStatus
        )
    }
    return output
}

private func extractSymbolGraph(
    framework: URL,
    module requestedModule: String?
) throws -> (graph: URL, module: String) {
    let module = requestedModule
        ?? framework.deletingPathExtension().lastPathComponent
    let environment = ProcessInfo.processInfo.environment
    guard let sdkRoot = environment["KMP_OBSERVABLE_SDKROOT"]
            ?? environment["SDKROOT"] else {
        throw GeneratorError.missingEnvironment("SDKROOT")
    }
    let architecture = environment["NATIVE_ARCH_ACTUAL"]
        ?? environment["CURRENT_ARCH"]
        ?? environment["ARCHS"]?.split(separator: " ").first.map(String.init)
    guard let architecture else {
        throw GeneratorError.missingEnvironment(
            "NATIVE_ARCH_ACTUAL or CURRENT_ARCH"
        )
    }
    guard let operatingSystem = environment["LLVM_TARGET_TRIPLE_OS_VERSION"]
    else {
        throw GeneratorError.missingEnvironment(
            "LLVM_TARGET_TRIPLE_OS_VERSION"
        )
    }
    let suffix = environment["LLVM_TARGET_TRIPLE_SUFFIX"] ?? ""
    let target = "\(architecture)-apple-\(operatingSystem)\(suffix)"
    let graphDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("KMPObservableBridge-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: graphDirectory,
        withIntermediateDirectories: true
    )

    _ = try run(
        URL(fileURLWithPath: "/usr/bin/xcrun"),
        arguments: [
            "swift-symbolgraph-extract",
            "-module-name", module,
            "-F", framework.deletingLastPathComponent().path,
            "-target", target,
            "-sdk", sdkRoot,
            "-minimum-access-level", "public",
            "-output-dir", graphDirectory.path,
        ]
    )

    return (
        graphDirectory.appendingPathComponent("\(module).symbols.json"),
        module
    )
}

private func generate(options: Options) throws {
    let input: (graph: URL, module: String)
    if let framework = options.framework {
        input = try extractSymbolGraph(
            framework: framework,
            module: options.module
        )
    } else if let graph = options.symbolGraph, let module = options.module {
        input = (graph, module)
    } else {
        throw GeneratorError.usage
    }

    let data = try Data(contentsOf: input.graph)
    let graph = try JSONDecoder().decode(SymbolGraph.self, from: data)
    guard graph.metadata.formatVersion.major == 0 else {
        throw GeneratorError.unsupportedSymbolGraph(
            graph.metadata.formatVersion.major
        )
    }

    let symbolsByID = Dictionary(
        uniqueKeysWithValues: graph.symbols.map {
            ($0.identifier.precise, $0)
        }
    )
    let ownerByMember = Dictionary(
        uniqueKeysWithValues: graph.relationships.compactMap { relationship in
            relationship.kind == "memberOf"
                ? (relationship.source, relationship.target)
                : nil
        }
    )
    let flowImplementationOwners = Set(
        graph.relationships.compactMap { relationship in
            relationship.kind == "conformsTo"
                && relationship.target.lowercased().contains(
                    "kotlinx_coroutines_core"
                )
                ? relationship.source
                : nil
        }
    )

    var propertiesByOwner: [String: [String]] = [:]
    for symbol in graph.symbols where symbol.kind.identifier == "swift.property" {
        let isStateFlow = symbol.declarationFragments?.contains { fragment in
            fragment.kind == "typeIdentifier"
                && supportedStateFlowNames.contains(fragment.spelling)
        } == true
        guard isStateFlow,
              let ownerID = ownerByMember[symbol.identifier.precise],
              let owner = symbolsByID[ownerID],
              owner.kind.identifier == "swift.class",
              // Kotlin/Native exported classes retain Objective-C symbol IDs.
              // Excluding native Swift IDs prevents accidental conformances
              // for SKIE's own StateFlow implementation classes.
              owner.identifier.precise.hasPrefix("c:objc(cs)"),
              !flowImplementationOwners.contains(ownerID) else {
            continue
        }

        propertiesByOwner[owner.names.title, default: []].append(
            symbol.names.title
        )
    }

    guard !propertiesByOwner.isEmpty else {
        throw GeneratorError.noStateFlows
    }

    var source = """
    // Generated by KMPObservableBridge. Do not edit.
    import KMPObservableBridge
    import \(input.module)

    """
    for owner in propertiesByOwner.keys.sorted() {
        let properties = propertiesByOwner[owner, default: []].sorted()
        source += """
        extension \(owner): @retroactive KMPAutomaticallyObservable {
            public func kmpObserveAutomatically(
                notify: @escaping KMPState<\(owner)>.Notify,
                reportError: @escaping KMPState<\(owner)>.ReportError
            ) -> KMPObservation {
                .group(
        """
        for property in properties {
            source += """

                        KMPState<\(owner)>.asyncSequence(\\.\(property))
                            .startObservation(
                                on: self,
                                notify: notify,
                                reportError: reportError
                            ),
            """
        }
        source += """

                )
            }
        }

        """
    }

    let directory = options.output.deletingLastPathComponent()
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let temporary = directory.appendingPathComponent(
        ".\(options.output.lastPathComponent).\(UUID().uuidString).tmp"
    )
    try Data(source.utf8).write(to: temporary, options: .atomic)
    if FileManager.default.fileExists(atPath: options.output.path) {
        _ = try FileManager.default.replaceItemAt(
            options.output,
            withItemAt: temporary
        )
    } else {
        try FileManager.default.moveItem(at: temporary, to: options.output)
    }

    if let project = options.xcodeProject, let target = options.target {
        let changed = try installGeneratedSource(
            options.output,
            in: project,
            targetName: target
        )
        if changed {
            throw GeneratorError.projectRegistered(
                options.output.lastPathComponent,
                target
            )
        }
    }
}

/// Registers the generated source without requiring the developer to edit the
/// project navigator or Compile Sources. Returns `true` only when the project
/// was changed, so normal builds never rewrite `project.pbxproj`.
private func installGeneratedSource(
    _ sourceURL: URL,
    in projectURL: URL,
    targetName: String
) throws -> Bool {
    let projectPath = Path(projectURL.standardizedFileURL.path)
    let projectDirectory = projectPath.parent()
    let sourcePath = Path(sourceURL.standardizedFileURL.path)
    guard sourcePath.string.hasPrefix(projectDirectory.string + "/") else {
        throw GeneratorError.outputOutsideProject(sourcePath.string)
    }

    let xcodeProject = try XcodeProj(path: projectPath)
    guard let project = xcodeProject.pbxproj.rootObject,
          let mainGroup = project.mainGroup else {
        throw GeneratorError.invalidXcodeProject(projectPath.string)
    }
    guard let target = project.targets
        .compactMap({ $0 as? PBXNativeTarget })
        .first(where: { $0.name == targetName }) else {
        throw GeneratorError.targetNotFound(targetName)
    }
    guard let sources = try target.sourcesBuildPhase() else {
        throw GeneratorError.sourcesBuildPhaseNotFound(targetName)
    }

    let relativePath = String(
        sourcePath.string.dropFirst(projectDirectory.string.count + 1)
    )
    let groupComponents = Path(relativePath).parent().components
    var group = mainGroup
    var changed = false
    for component in groupComponents where component != "." {
        if let existing = group.group(named: component) {
            group = existing
        } else {
            guard let created = try group.addGroup(named: component).last else {
                throw GeneratorError.invalidXcodeProject(projectPath.string)
            }
            group = created
            changed = true
        }
    }

    let file: PBXFileReference
    if let existing = group.file(named: sourcePath.lastComponent) {
        file = existing
    } else {
        file = try group.addFile(
            at: sourcePath,
            sourceRoot: projectDirectory
        )
        changed = true
    }

    let alreadyCompiled = try target.sourceFiles().contains { $0 === file }
    if !alreadyCompiled {
        _ = try sources.add(file: file)
        changed = true
    }

    if changed {
        try xcodeProject.write(path: projectPath)
    }
    return changed
}

do {
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    try generate(options: options)
} catch {
    FileHandle.standardError.write(
        Data("error: \(error.localizedDescription)\n".utf8)
    )
    exit(EXIT_FAILURE)
}
