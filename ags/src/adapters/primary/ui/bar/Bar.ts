import Widget from "resource:///com/github/Aylur/ags/widget.js";
import { WorkspaceWidget } from "./WorkspaceWidget.js";
import { AudioWidget } from "./AudioWidget.js";
import { BatteryWidget } from "./BatteryWidget.js";
import { NetworkWidget } from "./NetworkWidget.js";
import { DIContainer } from "../../../../infrastructure/di/container.js";

import { WorkspaceController } from "../../controllers/workspace-controller.js";
import { AudioController } from "../../controllers/audio-controller.js";
import { BatteryController } from "../../controllers/battery-controller.js";
import { NetworkController } from "../../controllers/network-controller.js";

export function Bar(monitor: number = 0) {
    const container = DIContainer.getInstance();

    // Crear instancias de controladores conectándolos a sus correspondientes casos de uso en el dominio
    const workspaceController = new WorkspaceController(container.workspaceUseCase);
    const audioController = new AudioController(container.audioUseCase);
    const batteryController = new BatteryController(container.batteryUseCase);
    const networkController = new NetworkController(container.networkUseCase);

    const leftBox = Widget.Box({
        halign: "start",
        children: [
            WorkspaceWidget(workspaceController),
        ],
    });

    const centerBox = Widget.Box({
        halign: "center",
        children: [
            Widget.Label({
                label: "AGS Hexagonal Shell 🚀",
                class_name: "bar-widget title-widget",
            }),
        ],
    });

    const rightBox = Widget.Box({
        halign: "end",
        children: [
            NetworkWidget(networkController),
            AudioWidget(audioController),
            BatteryWidget(batteryController),
        ],
    });

    const mainLayout = Widget.Box({
        class_name: "bar-container",
        children: [leftBox, centerBox, rightBox],
    });

    return Widget.Window({
        monitor,
        name: `bar-${monitor}`,
        class_name: "bar-window",
        anchor: ["top", "left", "right"],
        exclusivity: "exclusive",
        child: mainLayout,
    });
}
