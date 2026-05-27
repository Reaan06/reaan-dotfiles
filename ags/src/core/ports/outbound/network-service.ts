import { NetworkState } from "../../entities/network.js";

export interface NetworkService {
    getNetworkState(): NetworkState;
    toggleWifi(): void;
    subscribe(callback: (state: NetworkState) => void): () => void;
}
