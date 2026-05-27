import { NetworkService } from "../../../core/ports/outbound/network-service.js";
import { NetworkState } from "../../../core/entities/network.js";
import AgsNetwork from "resource:///com/github/Aylur/ags/service/network.js";

export class AgsNetworkAdapter implements NetworkService {
    getNetworkState(): NetworkState {
        const primary = AgsNetwork.primary || "none";
        const isWifi = primary === "wifi";
        const isWired = primary === "wired";

        return {
            type: isWifi ? "wifi" : (isWired ? "wired" : "none"),
            isConnected: AgsNetwork.connectivity === "full",
            ssid: AgsNetwork.wifi?.ssid || undefined,
            strength: AgsNetwork.wifi?.strength || undefined,
        };
    }

    toggleWifi(): void {
        const isEnabled = AgsNetwork.wifi?.internet !== "disconnected";
        const targetState = isEnabled ? "off" : "on";

        import("resource:///com/github/Aylur/ags/utils.js")
            .then((m) => {
                m.default.execAsync(["nmcli", "radio", "wifi", targetState]).catch(console.error);
            })
            .catch(console.error);
    }

    subscribe(callback: (state: NetworkState) => void): () => void {
        const id = AgsNetwork.connect("changed", () => {
            callback(this.getNetworkState());
        });
        return () => {
            AgsNetwork.disconnect(id);
        };
    }
}
