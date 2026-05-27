import { AudioService } from "../../../core/ports/outbound/audio-service.js";
import { AudioState } from "../../../core/entities/audio.js";
import AgsAudio from "resource:///com/github/Aylur/ags/service/audio.js";

export class AgsAudioAdapter implements AudioService {
    getAudioState(): AudioState {
        return {
            volume: Math.round((AgsAudio.speaker?.volume || 0) * 100),
            isMuted: !!AgsAudio.speaker?.is_muted,
            streamName: AgsAudio.speaker?.description || "Altavoz Principal",
        };
    }

    setVolume(percent: number): void {
        if (AgsAudio.speaker) {
            AgsAudio.speaker.volume = percent / 100;
        }
    }

    toggleMute(): void {
        if (AgsAudio.speaker) {
            AgsAudio.speaker.is_muted = !AgsAudio.speaker.is_muted;
        }
    }

    subscribe(callback: (state: AudioState) => void): () => void {
        const id = AgsAudio.connect("speaker-changed", () => {
            callback(this.getAudioState());
        });
        return () => {
            AgsAudio.disconnect(id);
        };
    }
}
