import { BatteryUseCase } from "../../../core/ports/inbound/battery-usecase.js";
import { BatteryState } from "../../../core/entities/battery.js";

export class BatteryController {
    constructor(private batteryUseCase: BatteryUseCase) {}

    getBatteryInfo(): BatteryState {
        return this.batteryUseCase.getBatteryInfo();
    }

    subscribe(callback: (state: BatteryState) => void): () => void {
        return this.batteryUseCase.onBatteryChanged(callback);
    }
}
