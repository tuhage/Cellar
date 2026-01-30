enum HelpCommand {
    static func run() {
        let name = TerminalOutput.bold("cellar")
        print("""
        \(name) — Homebrew manager for macOS

        \(TerminalOutput.bold("USAGE"))
            cellar <command> [arguments]

        \(TerminalOutput.bold("COMMANDS"))
            status              Show summary of installed packages and services
            start <service>     Start a Homebrew service
            stop <service>      Stop a Homebrew service
            health              Run brew doctor and show results
            cleanup             Clean up old downloads and cache files
            help                Show this help message
            version             Show version

        \(TerminalOutput.bold("EXAMPLES"))
            cellar status
            cellar start postgresql@17
            cellar stop redis
            cellar health
            cellar cleanup
        """)
    }
}
