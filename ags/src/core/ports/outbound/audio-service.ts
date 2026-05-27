import { AudioState } from "../../entities/audio.js";

export interface AudioService {
    getAudioState(): AudioState;
    setVolume(percent: number): void;
    toggleMute(): void;
    subscribe(callback: (state: AudioState) => void): () => void;
}
