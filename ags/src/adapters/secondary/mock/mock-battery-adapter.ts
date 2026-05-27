import { BatteryService } from "../../../core/ports/outbound/battery-service.js";
import { BatteryState } from "../../../core/entities/battery.js";

export class MockBatteryAdapter implements BatteryService {
    private state: BatteryState = {
        percent: 92,
        isCharging: false,
        isCharged: false,
    };
    private listeners = new Set<(state: BatteryState) => void>();

    constructor() {
        // Simulación sencilla de cambios en batería para verificar reactividad de la arquitectura
        if (typeof setInterval !== "undefined") {
            setInterval(() => {
                if (this.state.isCharging) {
                    this.state.percent = Math.min(100, this.state.percent + 1);
                    if (this.state.percent === 100) {
                        this.state.isCharging = false;
                        this.state.isCharged = true;
                    }
                } else {
                    this.state.percent = Math.max(0, this.state.percent - 1);
                    if (this.state.percent === 15) {
                        this.state.isCharging = true;
                        this.state.isCharged = false;
                    }
                }
                this.notify();
            }, 15000);
        }
    }

    getBatteryState(): BatteryState {
        return { ...this.state };
    }

    subscribe(callback: (state: BatteryState) => void): () => void {
        this.listeners.add(callback);
        callback(this.getBatteryState());
        return () => {
            this.listeners.delete(callback);
        };
    }

    private notify(): void {
        this.listeners.forEach((cb) => cb(this.getBatteryState()));
    }
}
