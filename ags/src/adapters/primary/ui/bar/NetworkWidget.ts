import Widget from "resource:///com/github/Aylur/ags/widget.js";
import { NetworkController } from "../../controllers/network-controller.js";
import { NetworkState } from "../../../../core/entities/network.js";

export function NetworkWidget(controller: NetworkController) {
    const label = Widget.Label({
        label: "",
    });

    const button = Widget.Button({
        class_name: "bar-widget network-widget",
        child: label,
        on_clicked: () => controller.toggleWifi(),
    });

    const update = (state: NetworkState) => {
        if (!state.isConnected) {
            label.label = "📡 Desconectado";
            button.class_name = "bar-widget network-widget disconnected";
            return;
        }

        if (state.type === "wifi") {
            label.label = `📶 ${state.ssid || "Wifi"}`;
        } else if (state.type === "wired") {
            label.label = "🔌 Cableado";
        } else {
            label.label = "📡 Conectado";
        }
        button.class_name = "bar-widget network-widget";
    };

    const unsubscribe = controller.subscribe(update);

    button.setup = (self: any) => {
        self.connect("destroy", unsubscribe);
    };

    // Render inicial
    update(controller.getNetworkInfo());

    return button;
}
