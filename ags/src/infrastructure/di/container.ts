// Contenedor de Inyección de Dependencias (Service Locator / DI Container)
import { AgsAudioAdapter } from "../../adapters/secondary/ags/ags-audio-adapter.js";
import { AgsBatteryAdapter } from "../../adapters/secondary/ags/ags-battery-adapter.js";
import { AgsNetworkAdapter } from "../../adapters/secondary/ags/ags-network-adapter.js";
import { AgsWorkspaceAdapter } from "../../adapters/secondary/ags/ags-workspace-adapter.js";

import { MockAudioAdapter } from "../../adapters/secondary/mock/mock-audio-adapter.js";
import { MockBatteryAdapter } from "../../adapters/secondary/mock/mock-battery-adapter.js";

import { ManageAudio } from "../../core/usecases/manage-audio.js";
import { ManageBattery } from "../../core/usecases/manage-battery.js";
import { ManageNetwork } from "../../core/usecases/manage-network.js";
import { ManageWorkspaces } from "../../core/usecases/manage-workspaces.js";

import { AudioUseCase } from "../../core/ports/inbound/audio-usecase.js";
import { BatteryUseCase } from "../../core/ports/inbound/battery-usecase.js";
import { NetworkUseCase } from "../../core/ports/inbound/network-usecase.js";
import { WorkspaceUseCase } from "../../core/ports/inbound/workspace-usecase.js";

export class DIContainer {
    private static instance: DIContainer;

    // Casos de uso expuestos a la capa de UI
    public audioUseCase!: AudioUseCase;
    public batteryUseCase!: BatteryUseCase;
    public networkUseCase!: NetworkUseCase;
    public workspaceUseCase!: WorkspaceUseCase;

    private constructor() {
        this.initialize();
    }

    public static getInstance(): DIContainer {
        if (!DIContainer.instance) {
            DIContainer.instance = new DIContainer();
        }
        return DIContainer.instance;
    }

    private initialize() {
        // Cambiar a true para desarrollo headless o pruebas sin entorno GTK/AGS
        const useMock = false;

        const audioService = useMock ? new MockAudioAdapter() : new AgsAudioAdapter();
        const batteryService = useMock ? new MockBatteryAdapter() : new AgsBatteryAdapter();
        const networkService = new AgsNetworkAdapter();
        const workspaceService = new AgsWorkspaceAdapter();

        // Inyección de dependencias limpia en la instanciación de casos de uso
        this.audioUseCase = new ManageAudio(audioService);
        this.batteryUseCase = new ManageBattery(batteryService);
        this.networkUseCase = new ManageNetwork(networkService);
        this.workspaceUseCase = new ManageWorkspaces(workspaceService);
    }
}
