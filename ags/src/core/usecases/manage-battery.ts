import { BatteryUseCase } from "../ports/inbound/battery-usecase.js";
import { BatteryService } from "../ports/outbound/battery-service.js";
import { BatteryState } from "../entities/battery.js";

export class ManageBattery implements BatteryUseCase {
    constructor(private batteryService: BatteryService) {}

    getBatteryInfo(): BatteryState {
        return this.batteryService.getBatteryState();
    }

    onBatteryChanged(callback: (state: BatteryState) => void): () => void {
        return this.batteryService.subscribe(callback);
    }
}
