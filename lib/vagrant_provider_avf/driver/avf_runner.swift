import Darwin
import Foundation
import Virtualization

struct Request: Codable {
    struct SharedDirectory: Codable {
        let hostPath: String
        let name: String
        let readOnly: Bool
    }

    struct SshInfo: Codable {
        let host: String
        let port: Int
        let username: String
    }

    let guest: String
    let cpuCount: Int
    let memorySizeBytes: UInt64
    let kernelPath: String?
    let initrdPath: String?
    let diskImagePath: String
    let networkMacAddress: String?
    let sharedDirectoryTag: String?
    let sharedDirectories: [SharedDirectory]
    let seedImagePath: String?
    let seedImageReadOnly: Bool?
    let efiVariableStorePath: String?
    let consoleLogPath: String
    let startedPath: String
    let errorPath: String
    let commandLine: String?
}

struct Started: Codable {
    let processId: Int32
    let sshInfo: Request.SshInfo?

    enum CodingKeys: String, CodingKey {
        case processId = "process_id"
        case sshInfo = "ssh_info"
    }
}

final class RunnerDelegate: NSObject, VZVirtualMachineDelegate {
    private let errorPath: String

    init(errorPath: String) {
        self.errorPath = errorPath
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        RunnerFiles.log("guest stopped cleanly")
        exit(EXIT_SUCCESS)
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        RunnerFiles.log("guest stopped with error: \(error.localizedDescription)")
        RunnerFiles.writeError(message: error.localizedDescription, to: errorPath)
        exit(EXIT_FAILURE)
    }
}

private enum RunnerFiles {
    static func log(_ message: String) {
        guard let data = "\(message)\n".data(using: .utf8) else {
            return
        }

        try? FileHandle.standardError.write(contentsOf: data)
    }

    static func writeError(message: String, to path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? message.write(to: url, atomically: true, encoding: .utf8)
    }

    static func writeStarted(_ started: Started, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(started)
        try data.write(to: url)
    }

    static func openConsoleLog(_ path: String) throws -> FileHandle {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 0)
        try handle.seekToEnd()
        return handle
    }
}

private struct ConfigurationBuilder {
    let request: Request

    func build() throws -> VZVirtualMachineConfiguration {
        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = request.cpuCount
        configuration.memorySize = request.memorySizeBytes
        configuration.platform = VZGenericPlatformConfiguration()
        configuration.bootLoader = try makeBootLoader()
        configuration.storageDevices = try makeStorageDevices()
        configuration.directorySharingDevices = try makeDirectorySharingDevices()
        configuration.entropyDevices = makeEntropyDevices()
        configuration.networkDevices = [makeNetworkDevice()]
        configuration.serialPorts = try makeConsoleDevices()
        try configuration.validate()
        return configuration
    }

    private func makeEntropyDevices() -> [VZEntropyDeviceConfiguration] {
        return [VZVirtioEntropyDeviceConfiguration()]
    }

    private func makeBootLoader() throws -> VZBootLoader {
        if request.kernelPath == nil || request.initrdPath == nil {
            return try makeEFIBootLoader(variableStorePath: request.efiVariableStorePath)
        }

        return try makeLinuxBootLoader(
            kernelPath: request.kernelPath,
            initrdPath: request.initrdPath,
            commandLine: request.commandLine
        )
    }

    private func makeEFIBootLoader(variableStorePath: String?) throws -> VZEFIBootLoader {
        let bootLoader = VZEFIBootLoader()
        guard let variableStorePath else {
            return bootLoader
        }

        let url = URL(fileURLWithPath: variableStorePath)
        bootLoader.variableStore = FileManager.default.fileExists(atPath: variableStorePath)
            ? VZEFIVariableStore(url: url)
            : try VZEFIVariableStore(creatingVariableStoreAt: url)
        return bootLoader
    }

    private func makeLinuxBootLoader(kernelPath: String?, initrdPath: String?, commandLine: String?) throws -> VZLinuxBootLoader {
        guard let kernelPath, let initrdPath else {
            throw NSError(
                domain: "AVFRunner",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "kernelPath and initrdPath must both be present for direct Linux boot"]
            )
        }

        let bootLoader = VZLinuxBootLoader(kernelURL: URL(fileURLWithPath: kernelPath))
        bootLoader.initialRamdiskURL = URL(fileURLWithPath: initrdPath)
        bootLoader.commandLine = commandLine ?? ""
        return bootLoader
    }

    private func makeStorageDevices() throws -> [VZStorageDeviceConfiguration] {
        var devices = [try makeBlockDevice(imagePath: request.diskImagePath, readOnly: false)]
        if let seedImagePath = request.seedImagePath {
            devices.append(
                try makeBlockDevice(
                    imagePath: seedImagePath,
                    readOnly: request.seedImageReadOnly ?? true
                )
            )
        }
        return devices
    }

    private func makeDirectorySharingDevices() throws -> [VZDirectorySharingDeviceConfiguration] {
        guard let tag = request.sharedDirectoryTag, !request.sharedDirectories.isEmpty else {
            return []
        }

        try VZVirtioFileSystemDeviceConfiguration.validateTag(tag)

        let directories = Dictionary(
            uniqueKeysWithValues: request.sharedDirectories.map { sharedDirectory in
                (
                    sharedDirectory.name,
                    VZSharedDirectory(
                        url: URL(fileURLWithPath: sharedDirectory.hostPath, isDirectory: true),
                        readOnly: sharedDirectory.readOnly
                    )
                )
            }
        )

        let device = VZVirtioFileSystemDeviceConfiguration(tag: tag)
        device.share = VZMultipleDirectoryShare(directories: directories)
        return [device]
    }

    private func makeBlockDevice(imagePath: String, readOnly: Bool) throws -> VZVirtioBlockDeviceConfiguration {
        let attachment = try VZDiskImageStorageDeviceAttachment(
            url: URL(fileURLWithPath: imagePath),
            readOnly: readOnly
        )
        return VZVirtioBlockDeviceConfiguration(attachment: attachment)
    }

    private func makeNetworkDevice() -> VZVirtioNetworkDeviceConfiguration {
        let networkConfiguration = VZVirtioNetworkDeviceConfiguration()
        networkConfiguration.attachment = VZNATNetworkDeviceAttachment()
        if let macAddress = request.networkMacAddress.flatMap(VZMACAddress.init(string:)) {
            networkConfiguration.macAddress = macAddress
        }
        return networkConfiguration
    }

    private func makeConsoleDevice(logPath: String) throws -> VZVirtioConsoleDeviceSerialPortConfiguration {
        let consoleHandle = try RunnerFiles.openConsoleLog(logPath)
        let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()
        consoleConfiguration.attachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: nil,
            fileHandleForWriting: consoleHandle
        )
        return consoleConfiguration
    }

    private func makeConsoleDevices() throws -> [VZSerialPortConfiguration] {
        return [try makeConsoleDevice(logPath: request.consoleLogPath)]
    }
}

private func installStopHandler(for virtualMachine: VZVirtualMachine, errorPath: String) -> DispatchSourceSignal {
    signal(SIGTERM, SIG_IGN)

    let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    var stopping = false
    let stopHandler = DispatchWorkItem {
        guard !stopping else {
            return
        }

        stopping = true
        RunnerFiles.log("received SIGTERM, attempting guest stop")

        if requestGracefulStop(for: virtualMachine, errorPath: errorPath) {
            return
        }

        forceStop(virtualMachine, errorPath: errorPath)
    }
    source.setEventHandler(handler: stopHandler)
    source.resume()
    return source
}

private func requestGracefulStop(for virtualMachine: VZVirtualMachine, errorPath: String) -> Bool {
    guard virtualMachine.canRequestStop else {
        RunnerFiles.log("guest stop request not available, falling back to force stop")
        return false
    }

    do {
        try virtualMachine.requestStop()
        RunnerFiles.log("requested guest stop")
        return true
    } catch {
        guard !virtualMachine.canStop else {
            RunnerFiles.log("guest stop request failed, trying force stop: \(error.localizedDescription)")
            return false
        }

        RunnerFiles.writeError(message: error.localizedDescription, to: errorPath)
        exit(EXIT_FAILURE)
    }
}

private func forceStop(_ virtualMachine: VZVirtualMachine, errorPath: String) {
    guard virtualMachine.canStop else {
        RunnerFiles.writeError(message: "the virtual machine is not in a stoppable state", to: errorPath)
        exit(EXIT_FAILURE)
    }

    RunnerFiles.log("forcing guest stop")
    virtualMachine.stop { error in
        if let error {
            RunnerFiles.writeError(message: error.localizedDescription, to: errorPath)
            exit(EXIT_FAILURE)
        }

        exit(EXIT_SUCCESS)
    }
}

private let requestPath = CommandLine.arguments.dropFirst().first

guard let requestPath else {
    fputs("usage: avf_runner <request-path>\n", stderr)
    exit(EXIT_FAILURE)
}

do {
    let requestURL = URL(fileURLWithPath: requestPath)
    let requestData = try Data(contentsOf: requestURL)
    let request = try JSONDecoder().decode(Request.self, from: requestData)
    RunnerFiles.log("starting guest=\(request.guest) disk=\(request.diskImagePath)")

    let configuration = try ConfigurationBuilder(request: request).build()
    let virtualMachine = VZVirtualMachine(configuration: configuration)
    let delegate = RunnerDelegate(errorPath: request.errorPath)
    virtualMachine.delegate = delegate
    let stopSignalSource = installStopHandler(for: virtualMachine, errorPath: request.errorPath)

    virtualMachine.start { result in
        if case let .failure(error) = result {
            RunnerFiles.log("virtual machine start failed: \(error.localizedDescription)")
            RunnerFiles.writeError(message: error.localizedDescription, to: request.errorPath)
            exit(EXIT_FAILURE)
        }

        do {
            try RunnerFiles.writeStarted(
                Started(processId: getpid(), sshInfo: nil),
                to: request.startedPath
            )
            RunnerFiles.log("virtual machine start reported success")
        } catch {
            RunnerFiles.writeError(message: error.localizedDescription, to: request.errorPath)
            exit(EXIT_FAILURE)
        }
    }

    withExtendedLifetime(stopSignalSource) {
        RunLoop.main.run(until: Date.distantFuture)
    }
} catch {
    RunnerFiles.writeError(message: error.localizedDescription, to: "/tmp/vagrant-provider-avf-runner-error.txt")
    fputs("\(error)\n", stderr)
    exit(EXIT_FAILURE)
}
