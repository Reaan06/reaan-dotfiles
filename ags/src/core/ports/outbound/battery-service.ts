import { BatteryState } from "../../entities/battery.js";

export interface BatteryService {
    getBatteryState(): BatteryState;
    subscribe(callback: (state: BatteryState) => void): () => void;
}
