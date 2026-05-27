// Tipos globales para Aylur's GTK Shell (AGS) y bindings de GJS (Gnome JavaScript)

declare module "resource:///com/github/Aylur/ags/widget.js" {
    export interface WidgetProps {
        class_name?: string;
        css?: string;
        visible?: boolean;
        valign?: "fill" | "start" | "center" | "end";
        halign?: "fill" | "start" | "center" | "end";
        connections?: Array<[any, (self: any, ...args: any[]) => void] | [any, string, string]>;
        setup?: (self: any) => void;
        [key: string]: any;
    }

    export interface LabelProps extends WidgetProps {
        label?: string;
        justification?: "left" | "center" | "right" | "fill";
        truncate?: "none" | "start" | "middle" | "end";
        use_markup?: boolean;
    }

    export interface ButtonProps extends WidgetProps {
        on_clicked?: (self: any) => void;
        on_primary_click?: (self: any) => void;
        on_secondary_click?: (self: any) => void;
        child?: any;
    }

    export interface BoxProps extends WidgetProps {
        vertical?: boolean;
        children?: any[];
        spacing?: number;
    }

    export interface WindowProps extends WidgetProps {
        name: string;
        anchor?: Array<"top" | "bottom" | "left" | "right">;
        exclusivity?: "normal" | "exclusive" | "ignore";
        layer?: "background" | "bottom" | "top" | "overlay";
        child?: any;
    }

    export const Widget: {
        Window: (props: WindowProps) => any;
        Box: (props: BoxProps) => any;
        Label: (props: LabelProps) => any;
        Button: (props: ButtonProps) => any;
        Icon: (props: WidgetProps & { icon?: string; size?: number }) => any;
        ProgressBar: (props: WidgetProps & { value?: number }) => any;
        [key: string]: any;
    };

    export default Widget;
}

declare module "resource:///com/github/Aylur/ags/app.js" {
    export const App: {
        connect: (signal: string, callback: (...args: any[]) => void) => number;
        disconnect: (id: number) => void;
        applyCss: (path: string) => void;
        config: (config: {
            style?: string;
            windows?: any[];
            closeWindowDelay?: Record<string, number>;
        }) => void;
        [key: string]: any;
    };
    export default App;
}

declare module "resource:///com/github/Aylur/ags/service/audio.js" {
    export interface Stream {
        volume: number;
        is_muted: boolean;
        stream?: any;
        id?: number;
        name?: string;
        description?: string;
    }

    export interface AudioService {
        speaker: Stream;
        microphone: Stream;
        speakers: Stream[];
        microphones: Stream[];
        connect: (signal: string, callback: (service: AudioService, ...args: any[]) => void) => number;
        disconnect: (id: number) => void;
    }

    const Audio: AudioService;
    export default Audio;
}

declare module "resource:///com/github/Aylur/ags/service/battery.js" {
    export interface BatteryService {
        percent: number;
        charging: boolean;
        charged: boolean;
        connect: (signal: string, callback: (service: BatteryService, ...args: any[]) => void) => number;
        disconnect: (id: number) => void;
    }

    const Battery: BatteryService;
    export default Battery;
}

declare module "resource:///com/github/Aylur/ags/service/network.js" {
    export interface WifiStream {
        ssid: string;
        strength: number;
        internet: "connected" | "disconnected" | "connecting";
    }

    export interface NetworkService {
        connectivity: "none" | "portal" | "limited" | "full";
        wifi: WifiStream;
        primary: "wifi" | "wired" | "none";
        connect: (signal: string, callback: (service: NetworkService, ...args: any[]) => void) => number;
        disconnect: (id: number) => void;
    }

    const Network: NetworkService;
    export default Network;
}

declare module "resource:///com/github/Aylur/ags/service/hyprland.js" {
    export interface WorkspaceInfo {
        id: number;
        name: string;
    }

    export interface HyprlandService {
        active: {
            workspace: WorkspaceInfo;
            client: {
                address: string;
                title: string;
                class: string;
            };
        };
        workspaces: WorkspaceInfo[];
        connect: (signal: string, callback: (service: HyprlandService, ...args: any[]) => void) => number;
        disconnect: (id: number) => void;
        messageAsync: (command: string) => Promise<string>;
    }

    const Hyprland: HyprlandService;
    export default Hyprland;
}

declare module "resource:///com/github/Aylur/ags/utils.js" {
    export const Utils: {
        exec: (cmd: string) => string;
        execAsync: (cmd: string | string[]) => Promise<string>;
        timeout: (ms: number, callback: () => void) => void;
        interval: (ms: number, callback: () => void, bind?: any) => number;
        [key: string]: any;
    };
    export default Utils;
}
