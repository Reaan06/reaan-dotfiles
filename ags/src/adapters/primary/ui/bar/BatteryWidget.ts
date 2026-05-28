import Widget from "resource:///com/github/Aylur/ags/widget.js";
import { BatteryController } from "../../controllers/battery-controller.js";
import { BatteryState } from "../../../../core/entities/battery.js";

export function BatteryWidget(controller: BatteryController) {
    const label = Widget.Label({
        label: "",
    });

    const box = Widget.Box({
        class_name: "bar-widget battery-widget",
        children: [label],
    });

    const update = (state: BatteryState) => {
        const chargingIcon = state.isCharging ? "⚡" : "🔋";
        label.label = `${chargingIcon} ${state.percent}%`;

        let batteryClass = "bar-widget battery-widget";
        if (state.isCharging) {
            batteryClass += " charging";
        } else if (state.percent <= 15) {
            batteryClass += " danger";
        } else if (state.percent <= 30) {
            batteryClass += " warning";
        }
        box.class_name = batteryClass;
    };

    const unsubscribe = controller.subscribe(update);

    box.setup = (self: any) => {
        self.connect("destroy", unsubscribe);
    };

    // Render inicial
    update(controller.getBatteryInfo());

    return box;
}
