import Foundation
import Logger
import RunnerLib

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

func runDangerJSCommandToRunDangerSwift(_ command: DangerCommand, logger: Logger) throws -> Int32 {
    let dangerJS = try getDangerCommandPath(logger: logger)
    let dangerJSVersion = try DangerJSVersionFinder.findDangerJSVersion(dangerJSPath: dangerJS)

    guard dangerJSVersion.compare(MinimumDangerJSVersion, options: .numeric) != .orderedAscending else {
        logger.logError("The installed danger-js version is below the minimum supported version",
                        "Current version = \(dangerJSVersion)",
                        "Minimum supported version = \(MinimumDangerJSVersion)",
                        separator: "\n")
        exit(1)
    }

    let proc = Process()
    proc.environment = ProcessInfo.processInfo.environment
    proc.launchPath = dangerJS

    let dangerOptionsIndexes = DangerSwiftOption.allCases
        .compactMap { option -> (DangerSwiftOption, Int)? in
            if let index = CommandLine.arguments.firstIndex(of: option.rawValue) {
                return (option, index)
            } else {
                return nil
            }
        }

    let unusedArgs = CommandLine.arguments.enumerated().compactMap { index, arg -> String? in
        if dangerOptionsIndexes.contains(where: { index == $0.1 || ($0.0.hasParameter && index == $0.1 + 1) }) {
            return nil
        }

        if arg.contains("danger-swift") || arg == command.rawValue {
            return nil
        }

        return arg
    }

    var dangerSwiftCommand = "danger-swift"
    // Special-case running inside the danger dev dir
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: ".build/debug/danger-swift") {
        dangerSwiftCommand = ".build/debug/danger-swift"
    }

    proc.arguments = [command.rawValue, "--process", dangerSwiftCommand, "--passURLForDSL"] + unusedArgs

    let standardOutput = FileHandle.standardOutput
    proc.standardOutput = standardOutput
    proc.standardError = standardOutput

    logger.debug("Running: \(proc.launchPath!) \(proc.arguments!.joined(separator: " ")) ")
    proc.launch()
    proc.waitUntilExit()

    return proc.terminationStatus
}
