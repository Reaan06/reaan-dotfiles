export interface NetworkState {
    type: "wifi" | "wired" | "none";
    isConnected: boolean;
    ssid?: string;
    strength?: number; // Porcentaje de 0 a 100
}
