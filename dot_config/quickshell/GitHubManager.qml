import QtQuick
import Quickshell
import Quickshell.Io
import "components"

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

    property var runtimePaths: RuntimePaths {}

    readonly property string fetchScript: runtimePaths.scriptsDir + "/github-fetch.sh"
    readonly property string configScript: runtimePaths.scriptsDir + "/github-config.py"

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
        id: fetchProc
        property string credential: ""
        stdinEnabled: credential.length > 0
        onRunningChanged: if (running && credential.length > 0) fetchProc.write(credential + "\n")
        onExited: credential = ""
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
        id: saveProc
        property string credential: ""
        stdinEnabled: credential.length > 0
        onRunningChanged: if (running && credential.length > 0) saveProc.write(credential + "\n")
        onExited: credential = ""
    }

    // ── Persistence: load config ──
    property var _loadProc: Process {
        command: ["python3", ghManager.configScript, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var saved = JSON.parse((text || "").trim() || "{}")
                    if (saved.username) {
                        ghManager.username = saved.username
                        ghManager.token = saved.token || ""
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

        _saveProc.credential = token
        _saveProc.command = ["python3", configScript, "save", username]
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
        _saveProc.credential = ""
        _saveProc.command = ["python3", configScript, "delete"]
        _saveProc.running = true
    }

    function refresh() {
        if (!username || loading) return
        loading = true
        errorMessage = ""

        _fetchProc.credential = token
        _fetchProc.command = ["bash", fetchScript, username]
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
