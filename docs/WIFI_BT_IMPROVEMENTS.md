# WiFi & Bluetooth Improvements (v1.7.0)

## New Features

### WiFi Password Retrieval

- **Secure Retrieval**: Users can now view the password of the currently connected WiFi network.
- **Sudo Authentication**: Integrated a custom QML authentication dialog to request sudo privileges before revealing the password.
- **Multi-step UI Flow**: A clear two-step process: click "VER CLAVE", authenticate, and then see the password in a dedicated modal.
- **Collapsible UI**: The password display modal is hidden by default and includes a close (X) button for better space management.

### Bluetooth Responsiveness

- **Increased Polling**: Reduced status polling interval from 4 seconds to **1 second**.
- **Event-Driven Updates**: The UI now updates almost instantly after a connection or disconnection action is completed.
- **Refined Status Feedback**: Improved text and icon states for faster visual confirmation of device status.

## Technical Improvements

- **Keyboard Focus Fix**: Enabled keyboard focus on panel windows (WlrLayershell.keyboardFocus: OnDemand) to allow text input in WiFi/Sudo dialogs.
- **Robust Backend**: Created `get-wifi-pass.sh` for secure secret retrieval via `nmcli`.
- **UI Architecture**: Implemented a unified modal layer in `WifiGraph.qml` to prevent UI overlap and manage interaction states.

## Version

**Current Version**: 1.7.0
