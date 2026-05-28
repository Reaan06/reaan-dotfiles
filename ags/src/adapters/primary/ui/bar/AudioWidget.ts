import Widget from "resource:///com/github/Aylur/ags/widget.js";
import { AudioController } from "../../controllers/audio-controller.js";
import { AudioState } from "../../../../core/entities/audio.js";

export function AudioWidget(controller: AudioController) {
    const label = Widget.Label({
        label: "",
    });

    const button = Widget.Button({
        class_name: "bar-widget audio-widget",
        child: label,
        on_clicked: () => controller.toggleMute(),
    });

    const update = (state: AudioState) => {
        if (state.isMuted) {
            label.label = "🔇 Muted";
            button.class_name = "bar-widget audio-widget muted";
        } else {
            label.label = `🔊 ${state.volume}%`;
            button.class_name = "bar-widget audio-widget";
        }
    };

    const unsubscribe = controller.subscribe(update);

    button.setup = (self: any) => {
        self.connect("destroy", unsubscribe);
    };

    // Render inicial
    update({
        volume: controller.getVolume(),
        isMuted: controller.isMuted(),
        streamName: "",
    });

    return button;
}
