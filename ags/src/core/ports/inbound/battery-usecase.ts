import { BatteryState } from "../../entities/battery.js";

export interface BatteryUseCase {
    getBatteryInfo(): BatteryState;
    onBatteryChanged(callback: (state: BatteryState) => void): () => void;
}
