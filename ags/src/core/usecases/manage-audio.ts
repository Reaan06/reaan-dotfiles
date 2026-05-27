import { AudioUseCase } from "../ports/inbound/audio-usecase.js";
import { AudioService } from "../ports/outbound/audio-service.js";
import { AudioState } from "../entities/audio.js";

export class ManageAudio implements AudioUseCase {
    constructor(private audioService: AudioService) {}

    getVolume(): number {
        return this.audioService.getAudioState().volume;
    }

    isMuted(): boolean {
        return this.audioService.getAudioState().isMuted;
    }

    setVolume(percent: number): void {
        this.audioService.setVolume(percent);
    }

    toggleMute(): void {
        this.audioService.toggleMute();
    }

    onAudioChanged(callback: (state: AudioState) => void): () => void {
        return this.audioService.subscribe(callback);
    }
}
