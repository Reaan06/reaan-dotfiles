import { AudioService } from "../../../core/ports/outbound/audio-service.js";
import { AudioState } from "../../../core/entities/audio.js";

export class MockAudioAdapter implements AudioService {
    private state: AudioState = {
        volume: 65,
        isMuted: false,
        streamName: "Mock Speakers",
    };
    private listeners = new Set<(state: AudioState) => void>();

    getAudioState(): AudioState {
        return { ...this.state };
    }

    setVolume(percent: number): void {
        this.state.volume = Math.max(0, Math.min(100, percent));
        this.notify();
    }

    toggleMute(): void {
        this.state.isMuted = !this.state.isMuted;
        this.notify();
    }

    subscribe(callback: (state: AudioState) => void): () => void {
        this.listeners.add(callback);
        callback(this.getAudioState());
        return () => {
            this.listeners.delete(callback);
        };
    }

    private notify(): void {
        this.listeners.forEach((cb) => cb(this.getAudioState()));
    }
}
