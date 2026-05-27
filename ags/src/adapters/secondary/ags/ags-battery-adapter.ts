import { BatteryService } from "../../../core/ports/outbound/battery-service.js";
import { BatteryState } from "../../../core/entities/battery.js";
import AgsBattery from "resource:///com/github/Aylur/ags/service/battery.js";

export class AgsBatteryAdapter implements BatteryService {
    getBatteryState(): BatteryState {
        return {
            percent: AgsBattery.percent ?? 0,
            isCharging: AgsBattery.charging ?? false,
            isCharged: AgsBattery.charged ?? false,
        };
    }

    subscribe(callback: (state: BatteryState) => void): () => void {
        const id = AgsBattery.connect("changed", () => {
            callback(this.getBatteryState());
        });
        return () => {
            AgsBattery.disconnect(id);
        };
    }
}
