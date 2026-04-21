import QtQuick
import Quickshell
import Quickshell.Io

// GitHubManager: Singleton-like component that manages GitHub data.
// Uses Process to run github-fetch.sh and exposes parsed data as properties.

QtObject {
    id: ghManager

    // ── Configuration ──
    property string username: ""
    property string token: ""
    property bool connected: false
    property bool loading: false
    property string errorMessage: ""

    // ── Persistence file (stored alongside quickshell config) ──
    readonly property string configPath: "$HOME/.config/quickshell/.github-config"

    // ── Parsed data ──
    property var profile: ({
        login: "", name: "", avatar_url: "", bio: "",
        public_repos: 0, followers: 0, following: 0
    })
    property var events: []
    property var repos: []
    property var notifications: []
    property var contributions: null
    property bool hasToken: false

    // ── Internal process ──
    property var _fetchProc: Process {
        command: ["sh", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                ghManager.loading = false
                try {
                    var cleaned = text.trim()
                    if (!cleaned.startsWith("{")) return

                    var data = JSON.parse(cleaned)

                    if (data.error) {
                        ghManager.errorMessage = data.message || data.error
                        return
                    }

                    ghManager.errorMessage = ""
                    ghManager.profile = data.profile || ghManager.profile
                    ghManager.events = data.events || []
                    ghManager.repos = data.repos || []
                    ghManager.notifications = data.notifications || []
                    ghManager.contributions = data.contributions || null
                    ghManager.hasToken = data.has_token || false
                    ghManager.connected = true
                } catch(e) {
                    ghManager.errorMessage = "Error parsing response"
                    console.log("GitHubManager parse error: " + e)
                }
            }
        }
    }

    // ── Auto-refresh timer ──
    property var _refreshTimer: Timer {
        interval: 300000  // 5 minutes
        running: ghManager.connected
        repeat: true
        onTriggered: ghManager.refresh()
    }

    // ── Persistence: save config ──
    property var _saveProc: Process {
        command: ["sh", "-c", ""]
    }

    // ── Persistence: load config ──
    property var _loadProc: Process {
        command: ["sh", "-c", "cat " + ghManager.configPath + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var lines = text.trim().split("\n")
                    if (lines.length >= 1 && lines[0].length > 0) {
                        ghManager.username = lines[0]
                        if (lines.length >= 2) ghManager.token = lines[1]
                        ghManager.refresh()
                    }
                } catch(e) {}
            }
        }
    }

    // ── Public API ──

    function connect(user, tok) {
        username = user.trim()
        token = (tok || "").trim()

        if (!username) {
            errorMessage = "Username is required"
            return
        }

        // Save config — use printf for safe escaping
        var content = username
        if (token) content += "\\n" + token
        _saveProc.command = ["sh", "-c",
            "printf '%b\\n' '" + content + "' > " + configPath + " && chmod 600 " + configPath
        ]
        _saveProc.running = true

        refresh()
    }

    function disconnect() {
        username = ""
        token = ""
        connected = false
        profile = { login: "", name: "", avatar_url: "", bio: "", public_repos: 0, followers: 0, following: 0 }
        events = []
        repos = []
        contributions = null
        hasToken = false
        errorMessage = ""
        _saveProc.command = ["sh", "-c", "rm -f " + configPath]
        _saveProc.running = true
    }

    function refresh() {
        if (!username || loading) return
        loading = true
        errorMessage = ""

        var tokenArg = token ? (" " + token) : ""
        _fetchProc.command = ["sh", "-c",
            "$HOME/.config/scripts/github-fetch.sh " + username + tokenArg
        ]
        _fetchProc.running = true
    }

    function loadSavedConfig() {
        _loadProc.running = false
        _loadProc.running = true
    }

    // ── Load on creation ──
    Component.onCompleted: {
        loadSavedConfig()
    }
}
