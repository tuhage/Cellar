import AppKit

/// Runs a shell command in Terminal, where the user can watch it and type
/// their password. It opens a `.command` file, which Terminal runs — no
/// Apple Events permission needed.
enum TerminalLauncher {

    enum LaunchError: LocalizedError {
        case scriptNotWritten(Error)
        case terminalNotOpened

        var errorDescription: String? {
            switch self {
            case .scriptNotWritten(let error): "Couldn’t prepare the command: \(error.localizedDescription)"
            case .terminalNotOpened: "Couldn’t open Terminal. Copy the command and run it yourself."
            }
        }
    }

    /// - Parameter title: The script's name, shown as Terminal's window title.
    static func run(_ command: String, title: String) throws(LaunchError) {
        let script = FileManager.default.temporaryDirectory.appending(path: "\(title).command")
        do {
            try "#!/bin/bash\n\(command)\n".write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        } catch {
            throw .scriptNotWritten(error)
        }
        guard NSWorkspace.shared.open(script) else {
            throw .terminalNotOpened
        }
    }
}
