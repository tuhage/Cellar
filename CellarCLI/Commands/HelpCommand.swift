enum HelpCommand {
    static func run() {
        let name = TerminalOutput.bold("cellar")
        print("""
        \(name) — Homebrew manager for macOS

        \(TerminalOutput.bold("USAGE"))
            cellar <command> [arguments]

        \(TerminalOutput.bold("COMMANDS"))
            status              Show summary of installed packages and services
            list                List installed packages (--formulae, --casks)
            search <query>      Search for packages
            start <service>     Start a Homebrew service
            stop <service>      Stop a Homebrew service
            restart <service>   Restart a Homebrew service
            health              Run brew doctor and show results
            cleanup             Clean up old downloads and cache files
            help                Show this help message
            version             Show version

        \(TerminalOutput.bold("EXAMPLES"))
            cellar status
            cellar list
            cellar list --formulae
            cellar search postgres
            cellar start postgresql@17
            cellar stop redis
            cellar restart postgresql@17
            cellar health
            cellar cleanup
        """)
    }
}
