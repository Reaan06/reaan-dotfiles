import { NetworkUseCase } from "../ports/inbound/network-usecase.js";
import { NetworkService } from "../ports/outbound/network-service.js";
import { NetworkState } from "../entities/network.js";

export class ManageNetwork implements NetworkUseCase {
    constructor(private networkService: NetworkService) {}

    getNetworkInfo(): NetworkState {
        return this.networkService.getNetworkState();
    }

    toggleWifi(): void {
        this.networkService.toggleWifi();
    }

    onNetworkChanged(callback: (state: NetworkState) => void): () => void {
        return this.networkService.subscribe(callback);
    }
}
