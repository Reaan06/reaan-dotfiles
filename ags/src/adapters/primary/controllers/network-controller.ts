import { NetworkUseCase } from "../../../core/ports/inbound/network-usecase.js";
import { NetworkState } from "../../../core/entities/network.js";

export class NetworkController {
    constructor(private networkUseCase: NetworkUseCase) {}

    getNetworkInfo(): NetworkState {
        return this.networkUseCase.getNetworkInfo();
    }

    toggleWifi(): void {
        this.networkUseCase.toggleWifi();
    }

    subscribe(callback: (state: NetworkState) => void): () => void {
        return this.networkUseCase.onNetworkChanged(callback);
    }
}
