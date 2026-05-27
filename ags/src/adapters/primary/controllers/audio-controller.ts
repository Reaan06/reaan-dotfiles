import { AudioUseCase } from "../../../core/ports/inbound/audio-usecase.js";
import { AudioState } from "../../../core/entities/audio.js";

export class AudioController {
    constructor(private audioUseCase: AudioUseCase) {}

    getVolume(): number {
        return this.audioUseCase.getVolume();
    }

    isMuted(): boolean {
        return this.audioUseCase.isMuted();
    }

    toggleMute(): void {
        this.audioUseCase.toggleMute();
    }

    setVolume(percent: number): void {
        this.audioUseCase.setVolume(percent);
    }

    subscribe(callback: (state: AudioState) => void): () => void {
        return this.audioUseCase.onAudioChanged(callback);
    }
}
