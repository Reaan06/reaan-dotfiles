import { AudioState } from "../../entities/audio.js";

export interface AudioUseCase {
    getVolume(): number;
    isMuted(): boolean;
    setVolume(percent: number): void;
    toggleMute(): void;
    onAudioChanged(callback: (state: AudioState) => void): () => void;
}
