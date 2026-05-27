import { NetworkState } from "../../entities/network.js";

export interface NetworkUseCase {
    getNetworkInfo(): NetworkState;
    toggleWifi(): void;
    onNetworkChanged(callback: (state: NetworkState) => void): () => void;
}
