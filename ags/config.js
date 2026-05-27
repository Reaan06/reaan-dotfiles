// src/main.ts
import App from "resource:///com/github/Aylur/ags/app.js";

// src/adapters/primary/ui/bar/Bar.ts
import Widget5 from "resource:///com/github/Aylur/ags/widget.js";

// src/adapters/primary/ui/bar/WorkspaceWidget.ts
import Widget from "resource:///com/github/Aylur/ags/widget.js";
function WorkspaceWidget(controller) {
  const box = Widget.Box({
    class_name: "workspaces-container",
    spacing: 4
  });
  const update = (workspaces) => {
    box.children = workspaces.map(
      (ws) => Widget.Button({
        class_name: `workspace-button ${ws.isActive ? "active" : ""}`,
        label: ws.name,
        on_clicked: () => controller.goToWorkspace(ws.id)
      })
    );
  };
  const unsubscribe = controller.subscribe(update);
  box.setup = (self) => {
    self.connect("destroy", unsubscribe);
  };
  update(controller.getWorkspaces());
  return box;
}

// src/adapters/primary/ui/bar/AudioWidget.ts
import Widget2 from "resource:///com/github/Aylur/ags/widget.js";
function AudioWidget(controller) {
  const label = Widget2.Label({
    label: ""
  });
  const button = Widget2.Button({
    class_name: "bar-widget audio-widget",
    child: label,
    on_clicked: () => controller.toggleMute()
  });
  const update = (state) => {
    if (state.isMuted) {
      label.label = "\u{1F507} Muted";
      button.class_name = "bar-widget audio-widget muted";
    } else {
      label.label = `\u{1F50A} ${state.volume}%`;
      button.class_name = "bar-widget audio-widget";
    }
  };
  const unsubscribe = controller.subscribe(update);
  button.setup = (self) => {
    self.connect("destroy", unsubscribe);
  };
  update({
    volume: controller.getVolume(),
    isMuted: controller.isMuted(),
    streamName: ""
  });
  return button;
}

// src/adapters/primary/ui/bar/BatteryWidget.ts
import Widget3 from "resource:///com/github/Aylur/ags/widget.js";
function BatteryWidget(controller) {
  const label = Widget3.Label({
    label: ""
  });
  const box = Widget3.Box({
    class_name: "bar-widget battery-widget",
    children: [label]
  });
  const update = (state) => {
    const chargingIcon = state.isCharging ? "\u26A1" : "\u{1F50B}";
    label.label = `${chargingIcon} ${state.percent}%`;
    let batteryClass = "bar-widget battery-widget";
    if (state.isCharging) {
      batteryClass += " charging";
    } else if (state.percent <= 15) {
      batteryClass += " danger";
    } else if (state.percent <= 30) {
      batteryClass += " warning";
    }
    box.class_name = batteryClass;
  };
  const unsubscribe = controller.subscribe(update);
  box.setup = (self) => {
    self.connect("destroy", unsubscribe);
  };
  update(controller.getBatteryInfo());
  return box;
}

// src/adapters/primary/ui/bar/NetworkWidget.ts
import Widget4 from "resource:///com/github/Aylur/ags/widget.js";
function NetworkWidget(controller) {
  const label = Widget4.Label({
    label: ""
  });
  const button = Widget4.Button({
    class_name: "bar-widget network-widget",
    child: label,
    on_clicked: () => controller.toggleWifi()
  });
  const update = (state) => {
    if (!state.isConnected) {
      label.label = "\u{1F4E1} Desconectado";
      button.class_name = "bar-widget network-widget disconnected";
      return;
    }
    if (state.type === "wifi") {
      label.label = `\u{1F4F6} ${state.ssid || "Wifi"}`;
    } else if (state.type === "wired") {
      label.label = "\u{1F50C} Cableado";
    } else {
      label.label = "\u{1F4E1} Conectado";
    }
    button.class_name = "bar-widget network-widget";
  };
  const unsubscribe = controller.subscribe(update);
  button.setup = (self) => {
    self.connect("destroy", unsubscribe);
  };
  update(controller.getNetworkInfo());
  return button;
}

// src/adapters/secondary/ags/ags-audio-adapter.ts
import AgsAudio from "resource:///com/github/Aylur/ags/service/audio.js";
var AgsAudioAdapter = class {
  getAudioState() {
    return {
      volume: Math.round((AgsAudio.speaker?.volume || 0) * 100),
      isMuted: !!AgsAudio.speaker?.is_muted,
      streamName: AgsAudio.speaker?.description || "Altavoz Principal"
    };
  }
  setVolume(percent) {
    if (AgsAudio.speaker) {
      AgsAudio.speaker.volume = percent / 100;
    }
  }
  toggleMute() {
    if (AgsAudio.speaker) {
      AgsAudio.speaker.is_muted = !AgsAudio.speaker.is_muted;
    }
  }
  subscribe(callback) {
    const id = AgsAudio.connect("speaker-changed", () => {
      callback(this.getAudioState());
    });
    return () => {
      AgsAudio.disconnect(id);
    };
  }
};

// src/adapters/secondary/ags/ags-battery-adapter.ts
import AgsBattery from "resource:///com/github/Aylur/ags/service/battery.js";
var AgsBatteryAdapter = class {
  getBatteryState() {
    return {
      percent: AgsBattery.percent ?? 0,
      isCharging: AgsBattery.charging ?? false,
      isCharged: AgsBattery.charged ?? false
    };
  }
  subscribe(callback) {
    const id = AgsBattery.connect("changed", () => {
      callback(this.getBatteryState());
    });
    return () => {
      AgsBattery.disconnect(id);
    };
  }
};

// src/adapters/secondary/ags/ags-network-adapter.ts
import AgsNetwork from "resource:///com/github/Aylur/ags/service/network.js";
var AgsNetworkAdapter = class {
  getNetworkState() {
    const primary = AgsNetwork.primary || "none";
    const isWifi = primary === "wifi";
    const isWired = primary === "wired";
    return {
      type: isWifi ? "wifi" : isWired ? "wired" : "none",
      isConnected: AgsNetwork.connectivity === "full",
      ssid: AgsNetwork.wifi?.ssid || void 0,
      strength: AgsNetwork.wifi?.strength || void 0
    };
  }
  toggleWifi() {
    const isEnabled = AgsNetwork.wifi?.internet !== "disconnected";
    const targetState = isEnabled ? "off" : "on";
    import("resource:///com/github/Aylur/ags/utils.js").then((m) => {
      m.default.execAsync(["nmcli", "radio", "wifi", targetState]).catch(console.error);
    }).catch(console.error);
  }
  subscribe(callback) {
    const id = AgsNetwork.connect("changed", () => {
      callback(this.getNetworkState());
    });
    return () => {
      AgsNetwork.disconnect(id);
    };
  }
};

// src/adapters/secondary/ags/ags-workspace-adapter.ts
import AgsHyprland from "resource:///com/github/Aylur/ags/service/hyprland.js";
var AgsWorkspaceAdapter = class {
  getWorkspaces() {
    const activeId = AgsHyprland.active.workspace?.id ?? 1;
    const rawWorkspaces = AgsHyprland.workspaces || [];
    const workspacesMap = /* @__PURE__ */ new Map();
    rawWorkspaces.forEach((w) => {
      workspacesMap.set(w.id, w.name || `${w.id}`);
    });
    const defaultIds = [1, 2, 3, 4, 5];
    defaultIds.forEach((id) => {
      if (!workspacesMap.has(id)) {
        workspacesMap.set(id, `${id}`);
      }
    });
    const list = [];
    workspacesMap.forEach((name, id) => {
      list.push({
        id,
        name,
        isActive: id === activeId
      });
    });
    return list.sort((a, b) => a.id - b.id);
  }
  changeWorkspace(id) {
    AgsHyprland.messageAsync(`dispatch workspace ${id}`).catch(console.error);
  }
  subscribe(callback) {
    const id = AgsHyprland.connect("changed", () => {
      callback(this.getWorkspaces());
    });
    return () => {
      AgsHyprland.disconnect(id);
    };
  }
};

// src/adapters/secondary/mock/mock-audio-adapter.ts
var MockAudioAdapter = class {
  state = {
    volume: 65,
    isMuted: false,
    streamName: "Mock Speakers"
  };
  listeners = /* @__PURE__ */ new Set();
  getAudioState() {
    return { ...this.state };
  }
  setVolume(percent) {
    this.state.volume = Math.max(0, Math.min(100, percent));
    this.notify();
  }
  toggleMute() {
    this.state.isMuted = !this.state.isMuted;
    this.notify();
  }
  subscribe(callback) {
    this.listeners.add(callback);
    callback(this.getAudioState());
    return () => {
      this.listeners.delete(callback);
    };
  }
  notify() {
    this.listeners.forEach((cb) => cb(this.getAudioState()));
  }
};

// src/adapters/secondary/mock/mock-battery-adapter.ts
var MockBatteryAdapter = class {
  state = {
    percent: 92,
    isCharging: false,
    isCharged: false
  };
  listeners = /* @__PURE__ */ new Set();
  constructor() {
    if (typeof setInterval !== "undefined") {
      setInterval(() => {
        if (this.state.isCharging) {
          this.state.percent = Math.min(100, this.state.percent + 1);
          if (this.state.percent === 100) {
            this.state.isCharging = false;
            this.state.isCharged = true;
          }
        } else {
          this.state.percent = Math.max(0, this.state.percent - 1);
          if (this.state.percent === 15) {
            this.state.isCharging = true;
            this.state.isCharged = false;
          }
        }
        this.notify();
      }, 15e3);
    }
  }
  getBatteryState() {
    return { ...this.state };
  }
  subscribe(callback) {
    this.listeners.add(callback);
    callback(this.getBatteryState());
    return () => {
      this.listeners.delete(callback);
    };
  }
  notify() {
    this.listeners.forEach((cb) => cb(this.getBatteryState()));
  }
};

// src/core/usecases/manage-audio.ts
var ManageAudio = class {
  constructor(audioService) {
    this.audioService = audioService;
  }
  getVolume() {
    return this.audioService.getAudioState().volume;
  }
  isMuted() {
    return this.audioService.getAudioState().isMuted;
  }
  setVolume(percent) {
    this.audioService.setVolume(percent);
  }
  toggleMute() {
    this.audioService.toggleMute();
  }
  onAudioChanged(callback) {
    return this.audioService.subscribe(callback);
  }
};

// src/core/usecases/manage-battery.ts
var ManageBattery = class {
  constructor(batteryService) {
    this.batteryService = batteryService;
  }
  getBatteryInfo() {
    return this.batteryService.getBatteryState();
  }
  onBatteryChanged(callback) {
    return this.batteryService.subscribe(callback);
  }
};

// src/core/usecases/manage-network.ts
var ManageNetwork = class {
  constructor(networkService) {
    this.networkService = networkService;
  }
  getNetworkInfo() {
    return this.networkService.getNetworkState();
  }
  toggleWifi() {
    this.networkService.toggleWifi();
  }
  onNetworkChanged(callback) {
    return this.networkService.subscribe(callback);
  }
};

// src/core/usecases/manage-workspaces.ts
var ManageWorkspaces = class {
  constructor(workspaceService) {
    this.workspaceService = workspaceService;
  }
  getWorkspaces() {
    return this.workspaceService.getWorkspaces();
  }
  goToWorkspace(id) {
    this.workspaceService.changeWorkspace(id);
  }
  onWorkspacesChanged(callback) {
    return this.workspaceService.subscribe(callback);
  }
};

// src/infrastructure/di/container.ts
var DIContainer = class _DIContainer {
  static instance;
  // Casos de uso expuestos a la capa de UI
  audioUseCase;
  batteryUseCase;
  networkUseCase;
  workspaceUseCase;
  constructor() {
    this.initialize();
  }
  static getInstance() {
    if (!_DIContainer.instance) {
      _DIContainer.instance = new _DIContainer();
    }
    return _DIContainer.instance;
  }
  initialize() {
    const useMock = false;
    const audioService = useMock ? new MockAudioAdapter() : new AgsAudioAdapter();
    const batteryService = useMock ? new MockBatteryAdapter() : new AgsBatteryAdapter();
    const networkService = new AgsNetworkAdapter();
    const workspaceService = new AgsWorkspaceAdapter();
    this.audioUseCase = new ManageAudio(audioService);
    this.batteryUseCase = new ManageBattery(batteryService);
    this.networkUseCase = new ManageNetwork(networkService);
    this.workspaceUseCase = new ManageWorkspaces(workspaceService);
  }
};

// src/adapters/primary/controllers/workspace-controller.ts
var WorkspaceController = class {
  constructor(workspaceUseCase) {
    this.workspaceUseCase = workspaceUseCase;
  }
  getWorkspaces() {
    return this.workspaceUseCase.getWorkspaces();
  }
  goToWorkspace(id) {
    this.workspaceUseCase.goToWorkspace(id);
  }
  subscribe(callback) {
    return this.workspaceUseCase.onWorkspacesChanged(callback);
  }
};

// src/adapters/primary/controllers/audio-controller.ts
var AudioController = class {
  constructor(audioUseCase) {
    this.audioUseCase = audioUseCase;
  }
  getVolume() {
    return this.audioUseCase.getVolume();
  }
  isMuted() {
    return this.audioUseCase.isMuted();
  }
  toggleMute() {
    this.audioUseCase.toggleMute();
  }
  setVolume(percent) {
    this.audioUseCase.setVolume(percent);
  }
  subscribe(callback) {
    return this.audioUseCase.onAudioChanged(callback);
  }
};

// src/adapters/primary/controllers/battery-controller.ts
var BatteryController = class {
  constructor(batteryUseCase) {
    this.batteryUseCase = batteryUseCase;
  }
  getBatteryInfo() {
    return this.batteryUseCase.getBatteryInfo();
  }
  subscribe(callback) {
    return this.batteryUseCase.onBatteryChanged(callback);
  }
};

// src/adapters/primary/controllers/network-controller.ts
var NetworkController = class {
  constructor(networkUseCase) {
    this.networkUseCase = networkUseCase;
  }
  getNetworkInfo() {
    return this.networkUseCase.getNetworkInfo();
  }
  toggleWifi() {
    this.networkUseCase.toggleWifi();
  }
  subscribe(callback) {
    return this.networkUseCase.onNetworkChanged(callback);
  }
};

// src/adapters/primary/ui/bar/Bar.ts
function Bar(monitor = 0) {
  const container = DIContainer.getInstance();
  const workspaceController = new WorkspaceController(container.workspaceUseCase);
  const audioController = new AudioController(container.audioUseCase);
  const batteryController = new BatteryController(container.batteryUseCase);
  const networkController = new NetworkController(container.networkUseCase);
  const leftBox = Widget5.Box({
    halign: "start",
    children: [
      WorkspaceWidget(workspaceController)
    ]
  });
  const centerBox = Widget5.Box({
    halign: "center",
    children: [
      Widget5.Label({
        label: "AGS Hexagonal Shell \u{1F680}",
        class_name: "bar-widget title-widget"
      })
    ]
  });
  const rightBox = Widget5.Box({
    halign: "end",
    children: [
      NetworkWidget(networkController),
      AudioWidget(audioController),
      BatteryWidget(batteryController)
    ]
  });
  const mainLayout = Widget5.Box({
    class_name: "bar-container",
    children: [leftBox, centerBox, rightBox]
  });
  return Widget5.Window({
    monitor,
    name: `bar-${monitor}`,
    class_name: "bar-window",
    anchor: ["top", "left", "right"],
    exclusivity: "exclusive",
    child: mainLayout
  });
}

// src/main.ts
var cssPath = App.configDir + "/style.css";
App.applyCss(cssPath);
App.config({
  style: cssPath,
  windows: [
    Bar(0)
    // Se crea la barra en el monitor 0
  ]
});
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsic3JjL21haW4udHMiLCAic3JjL2FkYXB0ZXJzL3ByaW1hcnkvdWkvYmFyL0Jhci50cyIsICJzcmMvYWRhcHRlcnMvcHJpbWFyeS91aS9iYXIvV29ya3NwYWNlV2lkZ2V0LnRzIiwgInNyYy9hZGFwdGVycy9wcmltYXJ5L3VpL2Jhci9BdWRpb1dpZGdldC50cyIsICJzcmMvYWRhcHRlcnMvcHJpbWFyeS91aS9iYXIvQmF0dGVyeVdpZGdldC50cyIsICJzcmMvYWRhcHRlcnMvcHJpbWFyeS91aS9iYXIvTmV0d29ya1dpZGdldC50cyIsICJzcmMvYWRhcHRlcnMvc2Vjb25kYXJ5L2Fncy9hZ3MtYXVkaW8tYWRhcHRlci50cyIsICJzcmMvYWRhcHRlcnMvc2Vjb25kYXJ5L2Fncy9hZ3MtYmF0dGVyeS1hZGFwdGVyLnRzIiwgInNyYy9hZGFwdGVycy9zZWNvbmRhcnkvYWdzL2Fncy1uZXR3b3JrLWFkYXB0ZXIudHMiLCAic3JjL2FkYXB0ZXJzL3NlY29uZGFyeS9hZ3MvYWdzLXdvcmtzcGFjZS1hZGFwdGVyLnRzIiwgInNyYy9hZGFwdGVycy9zZWNvbmRhcnkvbW9jay9tb2NrLWF1ZGlvLWFkYXB0ZXIudHMiLCAic3JjL2FkYXB0ZXJzL3NlY29uZGFyeS9tb2NrL21vY2stYmF0dGVyeS1hZGFwdGVyLnRzIiwgInNyYy9jb3JlL3VzZWNhc2VzL21hbmFnZS1hdWRpby50cyIsICJzcmMvY29yZS91c2VjYXNlcy9tYW5hZ2UtYmF0dGVyeS50cyIsICJzcmMvY29yZS91c2VjYXNlcy9tYW5hZ2UtbmV0d29yay50cyIsICJzcmMvY29yZS91c2VjYXNlcy9tYW5hZ2Utd29ya3NwYWNlcy50cyIsICJzcmMvaW5mcmFzdHJ1Y3R1cmUvZGkvY29udGFpbmVyLnRzIiwgInNyYy9hZGFwdGVycy9wcmltYXJ5L2NvbnRyb2xsZXJzL3dvcmtzcGFjZS1jb250cm9sbGVyLnRzIiwgInNyYy9hZGFwdGVycy9wcmltYXJ5L2NvbnRyb2xsZXJzL2F1ZGlvLWNvbnRyb2xsZXIudHMiLCAic3JjL2FkYXB0ZXJzL3ByaW1hcnkvY29udHJvbGxlcnMvYmF0dGVyeS1jb250cm9sbGVyLnRzIiwgInNyYy9hZGFwdGVycy9wcmltYXJ5L2NvbnRyb2xsZXJzL25ldHdvcmstY29udHJvbGxlci50cyJdLAogICJzb3VyY2VzQ29udGVudCI6IFsiaW1wb3J0IEFwcCBmcm9tIFwicmVzb3VyY2U6Ly8vY29tL2dpdGh1Yi9BeWx1ci9hZ3MvYXBwLmpzXCI7XG5pbXBvcnQgeyBCYXIgfSBmcm9tIFwiLi9hZGFwdGVycy9wcmltYXJ5L3VpL2Jhci9CYXIuanNcIjtcblxuLy8gQXBsaWNhciBlc3RpbG9zIFNDU1MgY29tcGlsYWRvcyBhIHN0eWxlLmNzc1xuY29uc3QgY3NzUGF0aCA9IEFwcC5jb25maWdEaXIgKyBcIi9zdHlsZS5jc3NcIjtcbkFwcC5hcHBseUNzcyhjc3NQYXRoKTtcblxuLy8gSW5pY2lhbGl6YXIgbGEgY29uZmlndXJhY2lcdTAwRjNuIGRlIGxhIHZlbnRhbmEgcHJpbmNpcGFsIGRlIEFHU1xuQXBwLmNvbmZpZyh7XG4gICAgc3R5bGU6IGNzc1BhdGgsXG4gICAgd2luZG93czogW1xuICAgICAgICBCYXIoMCksIC8vIFNlIGNyZWEgbGEgYmFycmEgZW4gZWwgbW9uaXRvciAwXG4gICAgXSxcbn0pO1xuIiwgImltcG9ydCBXaWRnZXQgZnJvbSBcInJlc291cmNlOi8vL2NvbS9naXRodWIvQXlsdXIvYWdzL3dpZGdldC5qc1wiO1xuaW1wb3J0IHsgV29ya3NwYWNlV2lkZ2V0IH0gZnJvbSBcIi4vV29ya3NwYWNlV2lkZ2V0LmpzXCI7XG5pbXBvcnQgeyBBdWRpb1dpZGdldCB9IGZyb20gXCIuL0F1ZGlvV2lkZ2V0LmpzXCI7XG5pbXBvcnQgeyBCYXR0ZXJ5V2lkZ2V0IH0gZnJvbSBcIi4vQmF0dGVyeVdpZGdldC5qc1wiO1xuaW1wb3J0IHsgTmV0d29ya1dpZGdldCB9IGZyb20gXCIuL05ldHdvcmtXaWRnZXQuanNcIjtcbmltcG9ydCB7IERJQ29udGFpbmVyIH0gZnJvbSBcIi4uLy4uLy4uLy4uL2luZnJhc3RydWN0dXJlL2RpL2NvbnRhaW5lci5qc1wiO1xuXG5pbXBvcnQgeyBXb3Jrc3BhY2VDb250cm9sbGVyIH0gZnJvbSBcIi4uLy4uL2NvbnRyb2xsZXJzL3dvcmtzcGFjZS1jb250cm9sbGVyLmpzXCI7XG5pbXBvcnQgeyBBdWRpb0NvbnRyb2xsZXIgfSBmcm9tIFwiLi4vLi4vY29udHJvbGxlcnMvYXVkaW8tY29udHJvbGxlci5qc1wiO1xuaW1wb3J0IHsgQmF0dGVyeUNvbnRyb2xsZXIgfSBmcm9tIFwiLi4vLi4vY29udHJvbGxlcnMvYmF0dGVyeS1jb250cm9sbGVyLmpzXCI7XG5pbXBvcnQgeyBOZXR3b3JrQ29udHJvbGxlciB9IGZyb20gXCIuLi8uLi9jb250cm9sbGVycy9uZXR3b3JrLWNvbnRyb2xsZXIuanNcIjtcblxuZXhwb3J0IGZ1bmN0aW9uIEJhcihtb25pdG9yOiBudW1iZXIgPSAwKSB7XG4gICAgY29uc3QgY29udGFpbmVyID0gRElDb250YWluZXIuZ2V0SW5zdGFuY2UoKTtcblxuICAgIC8vIENyZWFyIGluc3RhbmNpYXMgZGUgY29udHJvbGFkb3JlcyBjb25lY3RcdTAwRTFuZG9sb3MgYSBzdXMgY29ycmVzcG9uZGllbnRlcyBjYXNvcyBkZSB1c28gZW4gZWwgZG9taW5pb1xuICAgIGNvbnN0IHdvcmtzcGFjZUNvbnRyb2xsZXIgPSBuZXcgV29ya3NwYWNlQ29udHJvbGxlcihjb250YWluZXIud29ya3NwYWNlVXNlQ2FzZSk7XG4gICAgY29uc3QgYXVkaW9Db250cm9sbGVyID0gbmV3IEF1ZGlvQ29udHJvbGxlcihjb250YWluZXIuYXVkaW9Vc2VDYXNlKTtcbiAgICBjb25zdCBiYXR0ZXJ5Q29udHJvbGxlciA9IG5ldyBCYXR0ZXJ5Q29udHJvbGxlcihjb250YWluZXIuYmF0dGVyeVVzZUNhc2UpO1xuICAgIGNvbnN0IG5ldHdvcmtDb250cm9sbGVyID0gbmV3IE5ldHdvcmtDb250cm9sbGVyKGNvbnRhaW5lci5uZXR3b3JrVXNlQ2FzZSk7XG5cbiAgICBjb25zdCBsZWZ0Qm94ID0gV2lkZ2V0LkJveCh7XG4gICAgICAgIGhhbGlnbjogXCJzdGFydFwiLFxuICAgICAgICBjaGlsZHJlbjogW1xuICAgICAgICAgICAgV29ya3NwYWNlV2lkZ2V0KHdvcmtzcGFjZUNvbnRyb2xsZXIpLFxuICAgICAgICBdLFxuICAgIH0pO1xuXG4gICAgY29uc3QgY2VudGVyQm94ID0gV2lkZ2V0LkJveCh7XG4gICAgICAgIGhhbGlnbjogXCJjZW50ZXJcIixcbiAgICAgICAgY2hpbGRyZW46IFtcbiAgICAgICAgICAgIFdpZGdldC5MYWJlbCh7XG4gICAgICAgICAgICAgICAgbGFiZWw6IFwiQUdTIEhleGFnb25hbCBTaGVsbCBcdUQ4M0RcdURFODBcIixcbiAgICAgICAgICAgICAgICBjbGFzc19uYW1lOiBcImJhci13aWRnZXQgdGl0bGUtd2lkZ2V0XCIsXG4gICAgICAgICAgICB9KSxcbiAgICAgICAgXSxcbiAgICB9KTtcblxuICAgIGNvbnN0IHJpZ2h0Qm94ID0gV2lkZ2V0LkJveCh7XG4gICAgICAgIGhhbGlnbjogXCJlbmRcIixcbiAgICAgICAgY2hpbGRyZW46IFtcbiAgICAgICAgICAgIE5ldHdvcmtXaWRnZXQobmV0d29ya0NvbnRyb2xsZXIpLFxuICAgICAgICAgICAgQXVkaW9XaWRnZXQoYXVkaW9Db250cm9sbGVyKSxcbiAgICAgICAgICAgIEJhdHRlcnlXaWRnZXQoYmF0dGVyeUNvbnRyb2xsZXIpLFxuICAgICAgICBdLFxuICAgIH0pO1xuXG4gICAgY29uc3QgbWFpbkxheW91dCA9IFdpZGdldC5Cb3goe1xuICAgICAgICBjbGFzc19uYW1lOiBcImJhci1jb250YWluZXJcIixcbiAgICAgICAgY2hpbGRyZW46IFtsZWZ0Qm94LCBjZW50ZXJCb3gsIHJpZ2h0Qm94XSxcbiAgICB9KTtcblxuICAgIHJldHVybiBXaWRnZXQuV2luZG93KHtcbiAgICAgICAgbW9uaXRvcixcbiAgICAgICAgbmFtZTogYGJhci0ke21vbml0b3J9YCxcbiAgICAgICAgY2xhc3NfbmFtZTogXCJiYXItd2luZG93XCIsXG4gICAgICAgIGFuY2hvcjogW1widG9wXCIsIFwibGVmdFwiLCBcInJpZ2h0XCJdLFxuICAgICAgICBleGNsdXNpdml0eTogXCJleGNsdXNpdmVcIixcbiAgICAgICAgY2hpbGQ6IG1haW5MYXlvdXQsXG4gICAgfSk7XG59XG4iLCAiaW1wb3J0IFdpZGdldCBmcm9tIFwicmVzb3VyY2U6Ly8vY29tL2dpdGh1Yi9BeWx1ci9hZ3Mvd2lkZ2V0LmpzXCI7XG5pbXBvcnQgeyBXb3Jrc3BhY2VDb250cm9sbGVyIH0gZnJvbSBcIi4uLy4uL2NvbnRyb2xsZXJzL3dvcmtzcGFjZS1jb250cm9sbGVyLmpzXCI7XG5pbXBvcnQgeyBXb3Jrc3BhY2UgfSBmcm9tIFwiLi4vLi4vLi4vLi4vY29yZS9lbnRpdGllcy93b3Jrc3BhY2UuanNcIjtcblxuZXhwb3J0IGZ1bmN0aW9uIFdvcmtzcGFjZVdpZGdldChjb250cm9sbGVyOiBXb3Jrc3BhY2VDb250cm9sbGVyKSB7XG4gICAgY29uc3QgYm94ID0gV2lkZ2V0LkJveCh7XG4gICAgICAgIGNsYXNzX25hbWU6IFwid29ya3NwYWNlcy1jb250YWluZXJcIixcbiAgICAgICAgc3BhY2luZzogNCxcbiAgICB9KTtcblxuICAgIGNvbnN0IHVwZGF0ZSA9ICh3b3Jrc3BhY2VzOiBXb3Jrc3BhY2VbXSkgPT4ge1xuICAgICAgICBib3guY2hpbGRyZW4gPSB3b3Jrc3BhY2VzLm1hcCgod3MpID0+XG4gICAgICAgICAgICBXaWRnZXQuQnV0dG9uKHtcbiAgICAgICAgICAgICAgICBjbGFzc19uYW1lOiBgd29ya3NwYWNlLWJ1dHRvbiAke3dzLmlzQWN0aXZlID8gXCJhY3RpdmVcIiA6IFwiXCJ9YCxcbiAgICAgICAgICAgICAgICBsYWJlbDogd3MubmFtZSxcbiAgICAgICAgICAgICAgICBvbl9jbGlja2VkOiAoKSA9PiBjb250cm9sbGVyLmdvVG9Xb3Jrc3BhY2Uod3MuaWQpLFxuICAgICAgICAgICAgfSlcbiAgICAgICAgKTtcbiAgICB9O1xuXG4gICAgY29uc3QgdW5zdWJzY3JpYmUgPSBjb250cm9sbGVyLnN1YnNjcmliZSh1cGRhdGUpO1xuXG4gICAgYm94LnNldHVwID0gKHNlbGYpID0+IHtcbiAgICAgICAgc2VsZi5jb25uZWN0KFwiZGVzdHJveVwiLCB1bnN1YnNjcmliZSk7XG4gICAgfTtcblxuICAgIC8vIFJlbmRlciBpbmljaWFsXG4gICAgdXBkYXRlKGNvbnRyb2xsZXIuZ2V0V29ya3NwYWNlcygpKTtcblxuICAgIHJldHVybiBib3g7XG59XG4iLCAiaW1wb3J0IFdpZGdldCBmcm9tIFwicmVzb3VyY2U6Ly8vY29tL2dpdGh1Yi9BeWx1ci9hZ3Mvd2lkZ2V0LmpzXCI7XG5pbXBvcnQgeyBBdWRpb0NvbnRyb2xsZXIgfSBmcm9tIFwiLi4vLi4vY29udHJvbGxlcnMvYXVkaW8tY29udHJvbGxlci5qc1wiO1xuaW1wb3J0IHsgQXVkaW9TdGF0ZSB9IGZyb20gXCIuLi8uLi8uLi8uLi9jb3JlL2VudGl0aWVzL2F1ZGlvLmpzXCI7XG5cbmV4cG9ydCBmdW5jdGlvbiBBdWRpb1dpZGdldChjb250cm9sbGVyOiBBdWRpb0NvbnRyb2xsZXIpIHtcbiAgICBjb25zdCBsYWJlbCA9IFdpZGdldC5MYWJlbCh7XG4gICAgICAgIGxhYmVsOiBcIlwiLFxuICAgIH0pO1xuXG4gICAgY29uc3QgYnV0dG9uID0gV2lkZ2V0LkJ1dHRvbih7XG4gICAgICAgIGNsYXNzX25hbWU6IFwiYmFyLXdpZGdldCBhdWRpby13aWRnZXRcIixcbiAgICAgICAgY2hpbGQ6IGxhYmVsLFxuICAgICAgICBvbl9jbGlja2VkOiAoKSA9PiBjb250cm9sbGVyLnRvZ2dsZU11dGUoKSxcbiAgICB9KTtcblxuICAgIGNvbnN0IHVwZGF0ZSA9IChzdGF0ZTogQXVkaW9TdGF0ZSkgPT4ge1xuICAgICAgICBpZiAoc3RhdGUuaXNNdXRlZCkge1xuICAgICAgICAgICAgbGFiZWwubGFiZWwgPSBcIlx1RDgzRFx1REQwNyBNdXRlZFwiO1xuICAgICAgICAgICAgYnV0dG9uLmNsYXNzX25hbWUgPSBcImJhci13aWRnZXQgYXVkaW8td2lkZ2V0IG11dGVkXCI7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICBsYWJlbC5sYWJlbCA9IGBcdUQ4M0RcdUREMEEgJHtzdGF0ZS52b2x1bWV9JWA7XG4gICAgICAgICAgICBidXR0b24uY2xhc3NfbmFtZSA9IFwiYmFyLXdpZGdldCBhdWRpby13aWRnZXRcIjtcbiAgICAgICAgfVxuICAgIH07XG5cbiAgICBjb25zdCB1bnN1YnNjcmliZSA9IGNvbnRyb2xsZXIuc3Vic2NyaWJlKHVwZGF0ZSk7XG5cbiAgICBidXR0b24uc2V0dXAgPSAoc2VsZikgPT4ge1xuICAgICAgICBzZWxmLmNvbm5lY3QoXCJkZXN0cm95XCIsIHVuc3Vic2NyaWJlKTtcbiAgICB9O1xuXG4gICAgLy8gUmVuZGVyIGluaWNpYWxcbiAgICB1cGRhdGUoe1xuICAgICAgICB2b2x1bWU6IGNvbnRyb2xsZXIuZ2V0Vm9sdW1lKCksXG4gICAgICAgIGlzTXV0ZWQ6IGNvbnRyb2xsZXIuaXNNdXRlZCgpLFxuICAgICAgICBzdHJlYW1OYW1lOiBcIlwiLFxuICAgIH0pO1xuXG4gICAgcmV0dXJuIGJ1dHRvbjtcbn1cbiIsICJpbXBvcnQgV2lkZ2V0IGZyb20gXCJyZXNvdXJjZTovLy9jb20vZ2l0aHViL0F5bHVyL2Fncy93aWRnZXQuanNcIjtcbmltcG9ydCB7IEJhdHRlcnlDb250cm9sbGVyIH0gZnJvbSBcIi4uLy4uL2NvbnRyb2xsZXJzL2JhdHRlcnktY29udHJvbGxlci5qc1wiO1xuaW1wb3J0IHsgQmF0dGVyeVN0YXRlIH0gZnJvbSBcIi4uLy4uLy4uLy4uL2NvcmUvZW50aXRpZXMvYmF0dGVyeS5qc1wiO1xuXG5leHBvcnQgZnVuY3Rpb24gQmF0dGVyeVdpZGdldChjb250cm9sbGVyOiBCYXR0ZXJ5Q29udHJvbGxlcikge1xuICAgIGNvbnN0IGxhYmVsID0gV2lkZ2V0LkxhYmVsKHtcbiAgICAgICAgbGFiZWw6IFwiXCIsXG4gICAgfSk7XG5cbiAgICBjb25zdCBib3ggPSBXaWRnZXQuQm94KHtcbiAgICAgICAgY2xhc3NfbmFtZTogXCJiYXItd2lkZ2V0IGJhdHRlcnktd2lkZ2V0XCIsXG4gICAgICAgIGNoaWxkcmVuOiBbbGFiZWxdLFxuICAgIH0pO1xuXG4gICAgY29uc3QgdXBkYXRlID0gKHN0YXRlOiBCYXR0ZXJ5U3RhdGUpID0+IHtcbiAgICAgICAgY29uc3QgY2hhcmdpbmdJY29uID0gc3RhdGUuaXNDaGFyZ2luZyA/IFwiXHUyNkExXCIgOiBcIlx1RDgzRFx1REQwQlwiO1xuICAgICAgICBsYWJlbC5sYWJlbCA9IGAke2NoYXJnaW5nSWNvbn0gJHtzdGF0ZS5wZXJjZW50fSVgO1xuXG4gICAgICAgIGxldCBiYXR0ZXJ5Q2xhc3MgPSBcImJhci13aWRnZXQgYmF0dGVyeS13aWRnZXRcIjtcbiAgICAgICAgaWYgKHN0YXRlLmlzQ2hhcmdpbmcpIHtcbiAgICAgICAgICAgIGJhdHRlcnlDbGFzcyArPSBcIiBjaGFyZ2luZ1wiO1xuICAgICAgICB9IGVsc2UgaWYgKHN0YXRlLnBlcmNlbnQgPD0gMTUpIHtcbiAgICAgICAgICAgIGJhdHRlcnlDbGFzcyArPSBcIiBkYW5nZXJcIjtcbiAgICAgICAgfSBlbHNlIGlmIChzdGF0ZS5wZXJjZW50IDw9IDMwKSB7XG4gICAgICAgICAgICBiYXR0ZXJ5Q2xhc3MgKz0gXCIgd2FybmluZ1wiO1xuICAgICAgICB9XG4gICAgICAgIGJveC5jbGFzc19uYW1lID0gYmF0dGVyeUNsYXNzO1xuICAgIH07XG5cbiAgICBjb25zdCB1bnN1YnNjcmliZSA9IGNvbnRyb2xsZXIuc3Vic2NyaWJlKHVwZGF0ZSk7XG5cbiAgICBib3guc2V0dXAgPSAoc2VsZikgPT4ge1xuICAgICAgICBzZWxmLmNvbm5lY3QoXCJkZXN0cm95XCIsIHVuc3Vic2NyaWJlKTtcbiAgICB9O1xuXG4gICAgLy8gUmVuZGVyIGluaWNpYWxcbiAgICB1cGRhdGUoY29udHJvbGxlci5nZXRCYXR0ZXJ5SW5mbygpKTtcblxuICAgIHJldHVybiBib3g7XG59XG4iLCAiaW1wb3J0IFdpZGdldCBmcm9tIFwicmVzb3VyY2U6Ly8vY29tL2dpdGh1Yi9BeWx1ci9hZ3Mvd2lkZ2V0LmpzXCI7XG5pbXBvcnQgeyBOZXR3b3JrQ29udHJvbGxlciB9IGZyb20gXCIuLi8uLi9jb250cm9sbGVycy9uZXR3b3JrLWNvbnRyb2xsZXIuanNcIjtcbmltcG9ydCB7IE5ldHdvcmtTdGF0ZSB9IGZyb20gXCIuLi8uLi8uLi8uLi9jb3JlL2VudGl0aWVzL25ldHdvcmsuanNcIjtcblxuZXhwb3J0IGZ1bmN0aW9uIE5ldHdvcmtXaWRnZXQoY29udHJvbGxlcjogTmV0d29ya0NvbnRyb2xsZXIpIHtcbiAgICBjb25zdCBsYWJlbCA9IFdpZGdldC5MYWJlbCh7XG4gICAgICAgIGxhYmVsOiBcIlwiLFxuICAgIH0pO1xuXG4gICAgY29uc3QgYnV0dG9uID0gV2lkZ2V0LkJ1dHRvbih7XG4gICAgICAgIGNsYXNzX25hbWU6IFwiYmFyLXdpZGdldCBuZXR3b3JrLXdpZGdldFwiLFxuICAgICAgICBjaGlsZDogbGFiZWwsXG4gICAgICAgIG9uX2NsaWNrZWQ6ICgpID0+IGNvbnRyb2xsZXIudG9nZ2xlV2lmaSgpLFxuICAgIH0pO1xuXG4gICAgY29uc3QgdXBkYXRlID0gKHN0YXRlOiBOZXR3b3JrU3RhdGUpID0+IHtcbiAgICAgICAgaWYgKCFzdGF0ZS5pc0Nvbm5lY3RlZCkge1xuICAgICAgICAgICAgbGFiZWwubGFiZWwgPSBcIlx1RDgzRFx1RENFMSBEZXNjb25lY3RhZG9cIjtcbiAgICAgICAgICAgIGJ1dHRvbi5jbGFzc19uYW1lID0gXCJiYXItd2lkZ2V0IG5ldHdvcmstd2lkZ2V0IGRpc2Nvbm5lY3RlZFwiO1xuICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICB9XG5cbiAgICAgICAgaWYgKHN0YXRlLnR5cGUgPT09IFwid2lmaVwiKSB7XG4gICAgICAgICAgICBsYWJlbC5sYWJlbCA9IGBcdUQ4M0RcdURDRjYgJHtzdGF0ZS5zc2lkIHx8IFwiV2lmaVwifWA7XG4gICAgICAgIH0gZWxzZSBpZiAoc3RhdGUudHlwZSA9PT0gXCJ3aXJlZFwiKSB7XG4gICAgICAgICAgICBsYWJlbC5sYWJlbCA9IFwiXHVEODNEXHVERDBDIENhYmxlYWRvXCI7XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICBsYWJlbC5sYWJlbCA9IFwiXHVEODNEXHVEQ0UxIENvbmVjdGFkb1wiO1xuICAgICAgICB9XG4gICAgICAgIGJ1dHRvbi5jbGFzc19uYW1lID0gXCJiYXItd2lkZ2V0IG5ldHdvcmstd2lkZ2V0XCI7XG4gICAgfTtcblxuICAgIGNvbnN0IHVuc3Vic2NyaWJlID0gY29udHJvbGxlci5zdWJzY3JpYmUodXBkYXRlKTtcblxuICAgIGJ1dHRvbi5zZXR1cCA9IChzZWxmKSA9PiB7XG4gICAgICAgIHNlbGYuY29ubmVjdChcImRlc3Ryb3lcIiwgdW5zdWJzY3JpYmUpO1xuICAgIH07XG5cbiAgICAvLyBSZW5kZXIgaW5pY2lhbFxuICAgIHVwZGF0ZShjb250cm9sbGVyLmdldE5ldHdvcmtJbmZvKCkpO1xuXG4gICAgcmV0dXJuIGJ1dHRvbjtcbn1cbiIsICJpbXBvcnQgeyBBdWRpb1NlcnZpY2UgfSBmcm9tIFwiLi4vLi4vLi4vY29yZS9wb3J0cy9vdXRib3VuZC9hdWRpby1zZXJ2aWNlLmpzXCI7XG5pbXBvcnQgeyBBdWRpb1N0YXRlIH0gZnJvbSBcIi4uLy4uLy4uL2NvcmUvZW50aXRpZXMvYXVkaW8uanNcIjtcbmltcG9ydCBBZ3NBdWRpbyBmcm9tIFwicmVzb3VyY2U6Ly8vY29tL2dpdGh1Yi9BeWx1ci9hZ3Mvc2VydmljZS9hdWRpby5qc1wiO1xuXG5leHBvcnQgY2xhc3MgQWdzQXVkaW9BZGFwdGVyIGltcGxlbWVudHMgQXVkaW9TZXJ2aWNlIHtcbiAgICBnZXRBdWRpb1N0YXRlKCk6IEF1ZGlvU3RhdGUge1xuICAgICAgICByZXR1cm4ge1xuICAgICAgICAgICAgdm9sdW1lOiBNYXRoLnJvdW5kKChBZ3NBdWRpby5zcGVha2VyPy52b2x1bWUgfHwgMCkgKiAxMDApLFxuICAgICAgICAgICAgaXNNdXRlZDogISFBZ3NBdWRpby5zcGVha2VyPy5pc19tdXRlZCxcbiAgICAgICAgICAgIHN0cmVhbU5hbWU6IEFnc0F1ZGlvLnNwZWFrZXI/LmRlc2NyaXB0aW9uIHx8IFwiQWx0YXZveiBQcmluY2lwYWxcIixcbiAgICAgICAgfTtcbiAgICB9XG5cbiAgICBzZXRWb2x1bWUocGVyY2VudDogbnVtYmVyKTogdm9pZCB7XG4gICAgICAgIGlmIChBZ3NBdWRpby5zcGVha2VyKSB7XG4gICAgICAgICAgICBBZ3NBdWRpby5zcGVha2VyLnZvbHVtZSA9IHBlcmNlbnQgLyAxMDA7XG4gICAgICAgIH1cbiAgICB9XG5cbiAgICB0b2dnbGVNdXRlKCk6IHZvaWQge1xuICAgICAgICBpZiAoQWdzQXVkaW8uc3BlYWtlcikge1xuICAgICAgICAgICAgQWdzQXVkaW8uc3BlYWtlci5pc19tdXRlZCA9ICFBZ3NBdWRpby5zcGVha2VyLmlzX211dGVkO1xuICAgICAgICB9XG4gICAgfVxuXG4gICAgc3Vic2NyaWJlKGNhbGxiYWNrOiAoc3RhdGU6IEF1ZGlvU3RhdGUpID0+IHZvaWQpOiAoKSA9PiB2b2lkIHtcbiAgICAgICAgY29uc3QgaWQgPSBBZ3NBdWRpby5jb25uZWN0KFwic3BlYWtlci1jaGFuZ2VkXCIsICgpID0+IHtcbiAgICAgICAgICAgIGNhbGxiYWNrKHRoaXMuZ2V0QXVkaW9TdGF0ZSgpKTtcbiAgICAgICAgfSk7XG4gICAgICAgIHJldHVybiAoKSA9PiB7XG4gICAgICAgICAgICBBZ3NBdWRpby5kaXNjb25uZWN0KGlkKTtcbiAgICAgICAgfTtcbiAgICB9XG59XG4iLCAiaW1wb3J0IHsgQmF0dGVyeVNlcnZpY2UgfSBmcm9tIFwiLi4vLi4vLi4vY29yZS9wb3J0cy9vdXRib3VuZC9iYXR0ZXJ5LXNlcnZpY2UuanNcIjtcbmltcG9ydCB7IEJhdHRlcnlTdGF0ZSB9IGZyb20gXCIuLi8uLi8uLi9jb3JlL2VudGl0aWVzL2JhdHRlcnkuanNcIjtcbmltcG9ydCBBZ3NCYXR0ZXJ5IGZyb20gXCJyZXNvdXJjZTovLy9jb20vZ2l0aHViL0F5bHVyL2Fncy9zZXJ2aWNlL2JhdHRlcnkuanNcIjtcblxuZXhwb3J0IGNsYXNzIEFnc0JhdHRlcnlBZGFwdGVyIGltcGxlbWVudHMgQmF0dGVyeVNlcnZpY2Uge1xuICAgIGdldEJhdHRlcnlTdGF0ZSgpOiBCYXR0ZXJ5U3RhdGUge1xuICAgICAgICByZXR1cm4ge1xuICAgICAgICAgICAgcGVyY2VudDogQWdzQmF0dGVyeS5wZXJjZW50ID8/IDAsXG4gICAgICAgICAgICBpc0NoYXJnaW5nOiBBZ3NCYXR0ZXJ5LmNoYXJnaW5nID8/IGZhbHNlLFxuICAgICAgICAgICAgaXNDaGFyZ2VkOiBBZ3NCYXR0ZXJ5LmNoYXJnZWQgPz8gZmFsc2UsXG4gICAgICAgIH07XG4gICAgfVxuXG4gICAgc3Vic2NyaWJlKGNhbGxiYWNrOiAoc3RhdGU6IEJhdHRlcnlTdGF0ZSkgPT4gdm9pZCk6ICgpID0+IHZvaWQge1xuICAgICAgICBjb25zdCBpZCA9IEFnc0JhdHRlcnkuY29ubmVjdChcImNoYW5nZWRcIiwgKCkgPT4ge1xuICAgICAgICAgICAgY2FsbGJhY2sodGhpcy5nZXRCYXR0ZXJ5U3RhdGUoKSk7XG4gICAgICAgIH0pO1xuICAgICAgICByZXR1cm4gKCkgPT4ge1xuICAgICAgICAgICAgQWdzQmF0dGVyeS5kaXNjb25uZWN0KGlkKTtcbiAgICAgICAgfTtcbiAgICB9XG59XG4iLCAiaW1wb3J0IHsgTmV0d29ya1NlcnZpY2UgfSBmcm9tIFwiLi4vLi4vLi4vY29yZS9wb3J0cy9vdXRib3VuZC9uZXR3b3JrLXNlcnZpY2UuanNcIjtcbmltcG9ydCB7IE5ldHdvcmtTdGF0ZSB9IGZyb20gXCIuLi8uLi8uLi9jb3JlL2VudGl0aWVzL25ldHdvcmsuanNcIjtcbmltcG9ydCBBZ3NOZXR3b3JrIGZyb20gXCJyZXNvdXJjZTovLy9jb20vZ2l0aHViL0F5bHVyL2Fncy9zZXJ2aWNlL25ldHdvcmsuanNcIjtcblxuZXhwb3J0IGNsYXNzIEFnc05ldHdvcmtBZGFwdGVyIGltcGxlbWVudHMgTmV0d29ya1NlcnZpY2Uge1xuICAgIGdldE5ldHdvcmtTdGF0ZSgpOiBOZXR3b3JrU3RhdGUge1xuICAgICAgICBjb25zdCBwcmltYXJ5ID0gQWdzTmV0d29yay5wcmltYXJ5IHx8IFwibm9uZVwiO1xuICAgICAgICBjb25zdCBpc1dpZmkgPSBwcmltYXJ5ID09PSBcIndpZmlcIjtcbiAgICAgICAgY29uc3QgaXNXaXJlZCA9IHByaW1hcnkgPT09IFwid2lyZWRcIjtcblxuICAgICAgICByZXR1cm4ge1xuICAgICAgICAgICAgdHlwZTogaXNXaWZpID8gXCJ3aWZpXCIgOiAoaXNXaXJlZCA/IFwid2lyZWRcIiA6IFwibm9uZVwiKSxcbiAgICAgICAgICAgIGlzQ29ubmVjdGVkOiBBZ3NOZXR3b3JrLmNvbm5lY3Rpdml0eSA9PT0gXCJmdWxsXCIsXG4gICAgICAgICAgICBzc2lkOiBBZ3NOZXR3b3JrLndpZmk/LnNzaWQgfHwgdW5kZWZpbmVkLFxuICAgICAgICAgICAgc3RyZW5ndGg6IEFnc05ldHdvcmsud2lmaT8uc3RyZW5ndGggfHwgdW5kZWZpbmVkLFxuICAgICAgICB9O1xuICAgIH1cblxuICAgIHRvZ2dsZVdpZmkoKTogdm9pZCB7XG4gICAgICAgIGNvbnN0IGlzRW5hYmxlZCA9IEFnc05ldHdvcmsud2lmaT8uaW50ZXJuZXQgIT09IFwiZGlzY29ubmVjdGVkXCI7XG4gICAgICAgIGNvbnN0IHRhcmdldFN0YXRlID0gaXNFbmFibGVkID8gXCJvZmZcIiA6IFwib25cIjtcblxuICAgICAgICBpbXBvcnQoXCJyZXNvdXJjZTovLy9jb20vZ2l0aHViL0F5bHVyL2Fncy91dGlscy5qc1wiKVxuICAgICAgICAgICAgLnRoZW4oKG0pID0+IHtcbiAgICAgICAgICAgICAgICBtLmRlZmF1bHQuZXhlY0FzeW5jKFtcIm5tY2xpXCIsIFwicmFkaW9cIiwgXCJ3aWZpXCIsIHRhcmdldFN0YXRlXSkuY2F0Y2goY29uc29sZS5lcnJvcik7XG4gICAgICAgICAgICB9KVxuICAgICAgICAgICAgLmNhdGNoKGNvbnNvbGUuZXJyb3IpO1xuICAgIH1cblxuICAgIHN1YnNjcmliZShjYWxsYmFjazogKHN0YXRlOiBOZXR3b3JrU3RhdGUpID0+IHZvaWQpOiAoKSA9PiB2b2lkIHtcbiAgICAgICAgY29uc3QgaWQgPSBBZ3NOZXR3b3JrLmNvbm5lY3QoXCJjaGFuZ2VkXCIsICgpID0+IHtcbiAgICAgICAgICAgIGNhbGxiYWNrKHRoaXMuZ2V0TmV0d29ya1N0YXRlKCkpO1xuICAgICAgICB9KTtcbiAgICAgICAgcmV0dXJuICgpID0+IHtcbiAgICAgICAgICAgIEFnc05ldHdvcmsuZGlzY29ubmVjdChpZCk7XG4gICAgICAgIH07XG4gICAgfVxufVxuIiwgImltcG9ydCB7IFdvcmtzcGFjZVNlcnZpY2UgfSBmcm9tIFwiLi4vLi4vLi4vY29yZS9wb3J0cy9vdXRib3VuZC93b3Jrc3BhY2Utc2VydmljZS5qc1wiO1xuaW1wb3J0IHsgV29ya3NwYWNlIH0gZnJvbSBcIi4uLy4uLy4uL2NvcmUvZW50aXRpZXMvd29ya3NwYWNlLmpzXCI7XG5pbXBvcnQgQWdzSHlwcmxhbmQgZnJvbSBcInJlc291cmNlOi8vL2NvbS9naXRodWIvQXlsdXIvYWdzL3NlcnZpY2UvaHlwcmxhbmQuanNcIjtcblxuZXhwb3J0IGNsYXNzIEFnc1dvcmtzcGFjZUFkYXB0ZXIgaW1wbGVtZW50cyBXb3Jrc3BhY2VTZXJ2aWNlIHtcbiAgICBnZXRXb3Jrc3BhY2VzKCk6IFdvcmtzcGFjZVtdIHtcbiAgICAgICAgY29uc3QgYWN0aXZlSWQgPSBBZ3NIeXBybGFuZC5hY3RpdmUud29ya3NwYWNlPy5pZCA/PyAxO1xuICAgICAgICBjb25zdCByYXdXb3Jrc3BhY2VzID0gQWdzSHlwcmxhbmQud29ya3NwYWNlcyB8fCBbXTtcbiAgICAgICAgY29uc3Qgd29ya3NwYWNlc01hcCA9IG5ldyBNYXA8bnVtYmVyLCBzdHJpbmc+KCk7XG5cbiAgICAgICAgcmF3V29ya3NwYWNlcy5mb3JFYWNoKCh3KSA9PiB7XG4gICAgICAgICAgICB3b3Jrc3BhY2VzTWFwLnNldCh3LmlkLCB3Lm5hbWUgfHwgYCR7dy5pZH1gKTtcbiAgICAgICAgfSk7XG5cbiAgICAgICAgLy8gQXNlZ3VyYXIgcXVlIHBvciBsbyBtZW5vcyBsb3Mgd29ya3NwYWNlcyAxIGEgNSBlc3RcdTAwRTluIHZpc2libGVzXG4gICAgICAgIGNvbnN0IGRlZmF1bHRJZHMgPSBbMSwgMiwgMywgNCwgNV07XG4gICAgICAgIGRlZmF1bHRJZHMuZm9yRWFjaCgoaWQpID0+IHtcbiAgICAgICAgICAgIGlmICghd29ya3NwYWNlc01hcC5oYXMoaWQpKSB7XG4gICAgICAgICAgICAgICAgd29ya3NwYWNlc01hcC5zZXQoaWQsIGAke2lkfWApO1xuICAgICAgICAgICAgfVxuICAgICAgICB9KTtcblxuICAgICAgICBjb25zdCBsaXN0OiBXb3Jrc3BhY2VbXSA9IFtdO1xuICAgICAgICB3b3Jrc3BhY2VzTWFwLmZvckVhY2goKG5hbWUsIGlkKSA9PiB7XG4gICAgICAgICAgICBsaXN0LnB1c2goe1xuICAgICAgICAgICAgICAgIGlkLFxuICAgICAgICAgICAgICAgIG5hbWUsXG4gICAgICAgICAgICAgICAgaXNBY3RpdmU6IGlkID09PSBhY3RpdmVJZCxcbiAgICAgICAgICAgIH0pO1xuICAgICAgICB9KTtcblxuICAgICAgICByZXR1cm4gbGlzdC5zb3J0KChhLCBiKSA9PiBhLmlkIC0gYi5pZCk7XG4gICAgfVxuXG4gICAgY2hhbmdlV29ya3NwYWNlKGlkOiBudW1iZXIpOiB2b2lkIHtcbiAgICAgICAgQWdzSHlwcmxhbmQubWVzc2FnZUFzeW5jKGBkaXNwYXRjaCB3b3Jrc3BhY2UgJHtpZH1gKS5jYXRjaChjb25zb2xlLmVycm9yKTtcbiAgICB9XG5cbiAgICBzdWJzY3JpYmUoY2FsbGJhY2s6ICh3b3Jrc3BhY2VzOiBXb3Jrc3BhY2VbXSkgPT4gdm9pZCk6ICgpID0+IHZvaWQge1xuICAgICAgICBjb25zdCBpZCA9IEFnc0h5cHJsYW5kLmNvbm5lY3QoXCJjaGFuZ2VkXCIsICgpID0+IHtcbiAgICAgICAgICAgIGNhbGxiYWNrKHRoaXMuZ2V0V29ya3NwYWNlcygpKTtcbiAgICAgICAgfSk7XG4gICAgICAgIHJldHVybiAoKSA9PiB7XG4gICAgICAgICAgICBBZ3NIeXBybGFuZC5kaXNjb25uZWN0KGlkKTtcbiAgICAgICAgfTtcbiAgICB9XG59XG4iLCAiaW1wb3J0IHsgQXVkaW9TZXJ2aWNlIH0gZnJvbSBcIi4uLy4uLy4uL2NvcmUvcG9ydHMvb3V0Ym91bmQvYXVkaW8tc2VydmljZS5qc1wiO1xuaW1wb3J0IHsgQXVkaW9TdGF0ZSB9IGZyb20gXCIuLi8uLi8uLi9jb3JlL2VudGl0aWVzL2F1ZGlvLmpzXCI7XG5cbmV4cG9ydCBjbGFzcyBNb2NrQXVkaW9BZGFwdGVyIGltcGxlbWVudHMgQXVkaW9TZXJ2aWNlIHtcbiAgICBwcml2YXRlIHN0YXRlOiBBdWRpb1N0YXRlID0ge1xuICAgICAgICB2b2x1bWU6IDY1LFxuICAgICAgICBpc011dGVkOiBmYWxzZSxcbiAgICAgICAgc3RyZWFtTmFtZTogXCJNb2NrIFNwZWFrZXJzXCIsXG4gICAgfTtcbiAgICBwcml2YXRlIGxpc3RlbmVycyA9IG5ldyBTZXQ8KHN0YXRlOiBBdWRpb1N0YXRlKSA9PiB2b2lkPigpO1xuXG4gICAgZ2V0QXVkaW9TdGF0ZSgpOiBBdWRpb1N0YXRlIHtcbiAgICAgICAgcmV0dXJuIHsgLi4udGhpcy5zdGF0ZSB9O1xuICAgIH1cblxuICAgIHNldFZvbHVtZShwZXJjZW50OiBudW1iZXIpOiB2b2lkIHtcbiAgICAgICAgdGhpcy5zdGF0ZS52b2x1bWUgPSBNYXRoLm1heCgwLCBNYXRoLm1pbigxMDAsIHBlcmNlbnQpKTtcbiAgICAgICAgdGhpcy5ub3RpZnkoKTtcbiAgICB9XG5cbiAgICB0b2dnbGVNdXRlKCk6IHZvaWQge1xuICAgICAgICB0aGlzLnN0YXRlLmlzTXV0ZWQgPSAhdGhpcy5zdGF0ZS5pc011dGVkO1xuICAgICAgICB0aGlzLm5vdGlmeSgpO1xuICAgIH1cblxuICAgIHN1YnNjcmliZShjYWxsYmFjazogKHN0YXRlOiBBdWRpb1N0YXRlKSA9PiB2b2lkKTogKCkgPT4gdm9pZCB7XG4gICAgICAgIHRoaXMubGlzdGVuZXJzLmFkZChjYWxsYmFjayk7XG4gICAgICAgIGNhbGxiYWNrKHRoaXMuZ2V0QXVkaW9TdGF0ZSgpKTtcbiAgICAgICAgcmV0dXJuICgpID0+IHtcbiAgICAgICAgICAgIHRoaXMubGlzdGVuZXJzLmRlbGV0ZShjYWxsYmFjayk7XG4gICAgICAgIH07XG4gICAgfVxuXG4gICAgcHJpdmF0ZSBub3RpZnkoKTogdm9pZCB7XG4gICAgICAgIHRoaXMubGlzdGVuZXJzLmZvckVhY2goKGNiKSA9PiBjYih0aGlzLmdldEF1ZGlvU3RhdGUoKSkpO1xuICAgIH1cbn1cbiIsICJpbXBvcnQgeyBCYXR0ZXJ5U2VydmljZSB9IGZyb20gXCIuLi8uLi8uLi9jb3JlL3BvcnRzL291dGJvdW5kL2JhdHRlcnktc2VydmljZS5qc1wiO1xuaW1wb3J0IHsgQmF0dGVyeVN0YXRlIH0gZnJvbSBcIi4uLy4uLy4uL2NvcmUvZW50aXRpZXMvYmF0dGVyeS5qc1wiO1xuXG5leHBvcnQgY2xhc3MgTW9ja0JhdHRlcnlBZGFwdGVyIGltcGxlbWVudHMgQmF0dGVyeVNlcnZpY2Uge1xuICAgIHByaXZhdGUgc3RhdGU6IEJhdHRlcnlTdGF0ZSA9IHtcbiAgICAgICAgcGVyY2VudDogOTIsXG4gICAgICAgIGlzQ2hhcmdpbmc6IGZhbHNlLFxuICAgICAgICBpc0NoYXJnZWQ6IGZhbHNlLFxuICAgIH07XG4gICAgcHJpdmF0ZSBsaXN0ZW5lcnMgPSBuZXcgU2V0PChzdGF0ZTogQmF0dGVyeVN0YXRlKSA9PiB2b2lkPigpO1xuXG4gICAgY29uc3RydWN0b3IoKSB7XG4gICAgICAgIC8vIFNpbXVsYWNpXHUwMEYzbiBzZW5jaWxsYSBkZSBjYW1iaW9zIGVuIGJhdGVyXHUwMEVEYSBwYXJhIHZlcmlmaWNhciByZWFjdGl2aWRhZCBkZSBsYSBhcnF1aXRlY3R1cmFcbiAgICAgICAgaWYgKHR5cGVvZiBzZXRJbnRlcnZhbCAhPT0gXCJ1bmRlZmluZWRcIikge1xuICAgICAgICAgICAgc2V0SW50ZXJ2YWwoKCkgPT4ge1xuICAgICAgICAgICAgICAgIGlmICh0aGlzLnN0YXRlLmlzQ2hhcmdpbmcpIHtcbiAgICAgICAgICAgICAgICAgICAgdGhpcy5zdGF0ZS5wZXJjZW50ID0gTWF0aC5taW4oMTAwLCB0aGlzLnN0YXRlLnBlcmNlbnQgKyAxKTtcbiAgICAgICAgICAgICAgICAgICAgaWYgKHRoaXMuc3RhdGUucGVyY2VudCA9PT0gMTAwKSB7XG4gICAgICAgICAgICAgICAgICAgICAgICB0aGlzLnN0YXRlLmlzQ2hhcmdpbmcgPSBmYWxzZTtcbiAgICAgICAgICAgICAgICAgICAgICAgIHRoaXMuc3RhdGUuaXNDaGFyZ2VkID0gdHJ1ZTtcbiAgICAgICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgICAgICAgIHRoaXMuc3RhdGUucGVyY2VudCA9IE1hdGgubWF4KDAsIHRoaXMuc3RhdGUucGVyY2VudCAtIDEpO1xuICAgICAgICAgICAgICAgICAgICBpZiAodGhpcy5zdGF0ZS5wZXJjZW50ID09PSAxNSkge1xuICAgICAgICAgICAgICAgICAgICAgICAgdGhpcy5zdGF0ZS5pc0NoYXJnaW5nID0gdHJ1ZTtcbiAgICAgICAgICAgICAgICAgICAgICAgIHRoaXMuc3RhdGUuaXNDaGFyZ2VkID0gZmFsc2U7XG4gICAgICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgdGhpcy5ub3RpZnkoKTtcbiAgICAgICAgICAgIH0sIDE1MDAwKTtcbiAgICAgICAgfVxuICAgIH1cblxuICAgIGdldEJhdHRlcnlTdGF0ZSgpOiBCYXR0ZXJ5U3RhdGUge1xuICAgICAgICByZXR1cm4geyAuLi50aGlzLnN0YXRlIH07XG4gICAgfVxuXG4gICAgc3Vic2NyaWJlKGNhbGxiYWNrOiAoc3RhdGU6IEJhdHRlcnlTdGF0ZSkgPT4gdm9pZCk6ICgpID0+IHZvaWQge1xuICAgICAgICB0aGlzLmxpc3RlbmVycy5hZGQoY2FsbGJhY2spO1xuICAgICAgICBjYWxsYmFjayh0aGlzLmdldEJhdHRlcnlTdGF0ZSgpKTtcbiAgICAgICAgcmV0dXJuICgpID0+IHtcbiAgICAgICAgICAgIHRoaXMubGlzdGVuZXJzLmRlbGV0ZShjYWxsYmFjayk7XG4gICAgICAgIH07XG4gICAgfVxuXG4gICAgcHJpdmF0ZSBub3RpZnkoKTogdm9pZCB7XG4gICAgICAgIHRoaXMubGlzdGVuZXJzLmZvckVhY2goKGNiKSA9PiBjYih0aGlzLmdldEJhdHRlcnlTdGF0ZSgpKSk7XG4gICAgfVxufVxuIiwgImltcG9ydCB7IEF1ZGlvVXNlQ2FzZSB9IGZyb20gXCIuLi9wb3J0cy9pbmJvdW5kL2F1ZGlvLXVzZWNhc2UuanNcIjtcbmltcG9ydCB7IEF1ZGlvU2VydmljZSB9IGZyb20gXCIuLi9wb3J0cy9vdXRib3VuZC9hdWRpby1zZXJ2aWNlLmpzXCI7XG5pbXBvcnQgeyBBdWRpb1N0YXRlIH0gZnJvbSBcIi4uL2VudGl0aWVzL2F1ZGlvLmpzXCI7XG5cbmV4cG9ydCBjbGFzcyBNYW5hZ2VBdWRpbyBpbXBsZW1lbnRzIEF1ZGlvVXNlQ2FzZSB7XG4gICAgY29uc3RydWN0b3IocHJpdmF0ZSBhdWRpb1NlcnZpY2U6IEF1ZGlvU2VydmljZSkge31cblxuICAgIGdldFZvbHVtZSgpOiBudW1iZXIge1xuICAgICAgICByZXR1cm4gdGhpcy5hdWRpb1NlcnZpY2UuZ2V0QXVkaW9TdGF0ZSgpLnZvbHVtZTtcbiAgICB9XG5cbiAgICBpc011dGVkKCk6IGJvb2xlYW4ge1xuICAgICAgICByZXR1cm4gdGhpcy5hdWRpb1NlcnZpY2UuZ2V0QXVkaW9TdGF0ZSgpLmlzTXV0ZWQ7XG4gICAgfVxuXG4gICAgc2V0Vm9sdW1lKHBlcmNlbnQ6IG51bWJlcik6IHZvaWQge1xuICAgICAgICB0aGlzLmF1ZGlvU2VydmljZS5zZXRWb2x1bWUocGVyY2VudCk7XG4gICAgfVxuXG4gICAgdG9nZ2xlTXV0ZSgpOiB2b2lkIHtcbiAgICAgICAgdGhpcy5hdWRpb1NlcnZpY2UudG9nZ2xlTXV0ZSgpO1xuICAgIH1cblxuICAgIG9uQXVkaW9DaGFuZ2VkKGNhbGxiYWNrOiAoc3RhdGU6IEF1ZGlvU3RhdGUpID0+IHZvaWQpOiAoKSA9PiB2b2lkIHtcbiAgICAgICAgcmV0dXJuIHRoaXMuYXVkaW9TZXJ2aWNlLnN1YnNjcmliZShjYWxsYmFjayk7XG4gICAgfVxufVxuIiwgImltcG9ydCB7IEJhdHRlcnlVc2VDYXNlIH0gZnJvbSBcIi4uL3BvcnRzL2luYm91bmQvYmF0dGVyeS11c2VjYXNlLmpzXCI7XG5pbXBvcnQgeyBCYXR0ZXJ5U2VydmljZSB9IGZyb20gXCIuLi9wb3J0cy9vdXRib3VuZC9iYXR0ZXJ5LXNlcnZpY2UuanNcIjtcbmltcG9ydCB7IEJhdHRlcnlTdGF0ZSB9IGZyb20gXCIuLi9lbnRpdGllcy9iYXR0ZXJ5LmpzXCI7XG5cbmV4cG9ydCBjbGFzcyBNYW5hZ2VCYXR0ZXJ5IGltcGxlbWVudHMgQmF0dGVyeVVzZUNhc2Uge1xuICAgIGNvbnN0cnVjdG9yKHByaXZhdGUgYmF0dGVyeVNlcnZpY2U6IEJhdHRlcnlTZXJ2aWNlKSB7fVxuXG4gICAgZ2V0QmF0dGVyeUluZm8oKTogQmF0dGVyeVN0YXRlIHtcbiAgICAgICAgcmV0dXJuIHRoaXMuYmF0dGVyeVNlcnZpY2UuZ2V0QmF0dGVyeVN0YXRlKCk7XG4gICAgfVxuXG4gICAgb25CYXR0ZXJ5Q2hhbmdlZChjYWxsYmFjazogKHN0YXRlOiBCYXR0ZXJ5U3RhdGUpID0+IHZvaWQpOiAoKSA9PiB2b2lkIHtcbiAgICAgICAgcmV0dXJuIHRoaXMuYmF0dGVyeVNlcnZpY2Uuc3Vic2NyaWJlKGNhbGxiYWNrKTtcbiAgICB9XG59XG4iLCAiaW1wb3J0IHsgTmV0d29ya1VzZUNhc2UgfSBmcm9tIFwiLi4vcG9ydHMvaW5ib3VuZC9uZXR3b3JrLXVzZWNhc2UuanNcIjtcbmltcG9ydCB7IE5ldHdvcmtTZXJ2aWNlIH0gZnJvbSBcIi4uL3BvcnRzL291dGJvdW5kL25ldHdvcmstc2VydmljZS5qc1wiO1xuaW1wb3J0IHsgTmV0d29ya1N0YXRlIH0gZnJvbSBcIi4uL2VudGl0aWVzL25ldHdvcmsuanNcIjtcblxuZXhwb3J0IGNsYXNzIE1hbmFnZU5ldHdvcmsgaW1wbGVtZW50cyBOZXR3b3JrVXNlQ2FzZSB7XG4gICAgY29uc3RydWN0b3IocHJpdmF0ZSBuZXR3b3JrU2VydmljZTogTmV0d29ya1NlcnZpY2UpIHt9XG5cbiAgICBnZXROZXR3b3JrSW5mbygpOiBOZXR3b3JrU3RhdGUge1xuICAgICAgICByZXR1cm4gdGhpcy5uZXR3b3JrU2VydmljZS5nZXROZXR3b3JrU3RhdGUoKTtcbiAgICB9XG5cbiAgICB0b2dnbGVXaWZpKCk6IHZvaWQge1xuICAgICAgICB0aGlzLm5ldHdvcmtTZXJ2aWNlLnRvZ2dsZVdpZmkoKTtcbiAgICB9XG5cbiAgICBvbk5ldHdvcmtDaGFuZ2VkKGNhbGxiYWNrOiAoc3RhdGU6IE5ldHdvcmtTdGF0ZSkgPT4gdm9pZCk6ICgpID0+IHZvaWQge1xuICAgICAgICByZXR1cm4gdGhpcy5uZXR3b3JrU2VydmljZS5zdWJzY3JpYmUoY2FsbGJhY2spO1xuICAgIH1cbn1cbiIsICJpbXBvcnQgeyBXb3Jrc3BhY2VVc2VDYXNlIH0gZnJvbSBcIi4uL3BvcnRzL2luYm91bmQvd29ya3NwYWNlLXVzZWNhc2UuanNcIjtcbmltcG9ydCB7IFdvcmtzcGFjZVNlcnZpY2UgfSBmcm9tIFwiLi4vcG9ydHMvb3V0Ym91bmQvd29ya3NwYWNlLXNlcnZpY2UuanNcIjtcbmltcG9ydCB7IFdvcmtzcGFjZSB9IGZyb20gXCIuLi9lbnRpdGllcy93b3Jrc3BhY2UuanNcIjtcblxuZXhwb3J0IGNsYXNzIE1hbmFnZVdvcmtzcGFjZXMgaW1wbGVtZW50cyBXb3Jrc3BhY2VVc2VDYXNlIHtcbiAgICBjb25zdHJ1Y3Rvcihwcml2YXRlIHdvcmtzcGFjZVNlcnZpY2U6IFdvcmtzcGFjZVNlcnZpY2UpIHt9XG5cbiAgICBnZXRXb3Jrc3BhY2VzKCk6IFdvcmtzcGFjZVtdIHtcbiAgICAgICAgcmV0dXJuIHRoaXMud29ya3NwYWNlU2VydmljZS5nZXRXb3Jrc3BhY2VzKCk7XG4gICAgfVxuXG4gICAgZ29Ub1dvcmtzcGFjZShpZDogbnVtYmVyKTogdm9pZCB7XG4gICAgICAgIHRoaXMud29ya3NwYWNlU2VydmljZS5jaGFuZ2VXb3Jrc3BhY2UoaWQpO1xuICAgIH1cblxuICAgIG9uV29ya3NwYWNlc0NoYW5nZWQoY2FsbGJhY2s6ICh3b3Jrc3BhY2VzOiBXb3Jrc3BhY2VbXSkgPT4gdm9pZCk6ICgpID0+IHZvaWQge1xuICAgICAgICByZXR1cm4gdGhpcy53b3Jrc3BhY2VTZXJ2aWNlLnN1YnNjcmliZShjYWxsYmFjayk7XG4gICAgfVxufVxuIiwgIi8vIENvbnRlbmVkb3IgZGUgSW55ZWNjaVx1MDBGM24gZGUgRGVwZW5kZW5jaWFzIChTZXJ2aWNlIExvY2F0b3IgLyBESSBDb250YWluZXIpXG5pbXBvcnQgeyBBZ3NBdWRpb0FkYXB0ZXIgfSBmcm9tIFwiLi4vLi4vYWRhcHRlcnMvc2Vjb25kYXJ5L2Fncy9hZ3MtYXVkaW8tYWRhcHRlci5qc1wiO1xuaW1wb3J0IHsgQWdzQmF0dGVyeUFkYXB0ZXIgfSBmcm9tIFwiLi4vLi4vYWRhcHRlcnMvc2Vjb25kYXJ5L2Fncy9hZ3MtYmF0dGVyeS1hZGFwdGVyLmpzXCI7XG5pbXBvcnQgeyBBZ3NOZXR3b3JrQWRhcHRlciB9IGZyb20gXCIuLi8uLi9hZGFwdGVycy9zZWNvbmRhcnkvYWdzL2Fncy1uZXR3b3JrLWFkYXB0ZXIuanNcIjtcbmltcG9ydCB7IEFnc1dvcmtzcGFjZUFkYXB0ZXIgfSBmcm9tIFwiLi4vLi4vYWRhcHRlcnMvc2Vjb25kYXJ5L2Fncy9hZ3Mtd29ya3NwYWNlLWFkYXB0ZXIuanNcIjtcblxuaW1wb3J0IHsgTW9ja0F1ZGlvQWRhcHRlciB9IGZyb20gXCIuLi8uLi9hZGFwdGVycy9zZWNvbmRhcnkvbW9jay9tb2NrLWF1ZGlvLWFkYXB0ZXIuanNcIjtcbmltcG9ydCB7IE1vY2tCYXR0ZXJ5QWRhcHRlciB9IGZyb20gXCIuLi8uLi9hZGFwdGVycy9zZWNvbmRhcnkvbW9jay9tb2NrLWJhdHRlcnktYWRhcHRlci5qc1wiO1xuXG5pbXBvcnQgeyBNYW5hZ2VBdWRpbyB9IGZyb20gXCIuLi8uLi9jb3JlL3VzZWNhc2VzL21hbmFnZS1hdWRpby5qc1wiO1xuaW1wb3J0IHsgTWFuYWdlQmF0dGVyeSB9IGZyb20gXCIuLi8uLi9jb3JlL3VzZWNhc2VzL21hbmFnZS1iYXR0ZXJ5LmpzXCI7XG5pbXBvcnQgeyBNYW5hZ2VOZXR3b3JrIH0gZnJvbSBcIi4uLy4uL2NvcmUvdXNlY2FzZXMvbWFuYWdlLW5ldHdvcmsuanNcIjtcbmltcG9ydCB7IE1hbmFnZVdvcmtzcGFjZXMgfSBmcm9tIFwiLi4vLi4vY29yZS91c2VjYXNlcy9tYW5hZ2Utd29ya3NwYWNlcy5qc1wiO1xuXG5pbXBvcnQgeyBBdWRpb1VzZUNhc2UgfSBmcm9tIFwiLi4vLi4vY29yZS9wb3J0cy9pbmJvdW5kL2F1ZGlvLXVzZWNhc2UuanNcIjtcbmltcG9ydCB7IEJhdHRlcnlVc2VDYXNlIH0gZnJvbSBcIi4uLy4uL2NvcmUvcG9ydHMvaW5ib3VuZC9iYXR0ZXJ5LXVzZWNhc2UuanNcIjtcbmltcG9ydCB7IE5ldHdvcmtVc2VDYXNlIH0gZnJvbSBcIi4uLy4uL2NvcmUvcG9ydHMvaW5ib3VuZC9uZXR3b3JrLXVzZWNhc2UuanNcIjtcbmltcG9ydCB7IFdvcmtzcGFjZVVzZUNhc2UgfSBmcm9tIFwiLi4vLi4vY29yZS9wb3J0cy9pbmJvdW5kL3dvcmtzcGFjZS11c2VjYXNlLmpzXCI7XG5cbmV4cG9ydCBjbGFzcyBESUNvbnRhaW5lciB7XG4gICAgcHJpdmF0ZSBzdGF0aWMgaW5zdGFuY2U6IERJQ29udGFpbmVyO1xuXG4gICAgLy8gQ2Fzb3MgZGUgdXNvIGV4cHVlc3RvcyBhIGxhIGNhcGEgZGUgVUlcbiAgICBwdWJsaWMgYXVkaW9Vc2VDYXNlITogQXVkaW9Vc2VDYXNlO1xuICAgIHB1YmxpYyBiYXR0ZXJ5VXNlQ2FzZSE6IEJhdHRlcnlVc2VDYXNlO1xuICAgIHB1YmxpYyBuZXR3b3JrVXNlQ2FzZSE6IE5ldHdvcmtVc2VDYXNlO1xuICAgIHB1YmxpYyB3b3Jrc3BhY2VVc2VDYXNlITogV29ya3NwYWNlVXNlQ2FzZTtcblxuICAgIHByaXZhdGUgY29uc3RydWN0b3IoKSB7XG4gICAgICAgIHRoaXMuaW5pdGlhbGl6ZSgpO1xuICAgIH1cblxuICAgIHB1YmxpYyBzdGF0aWMgZ2V0SW5zdGFuY2UoKTogRElDb250YWluZXIge1xuICAgICAgICBpZiAoIURJQ29udGFpbmVyLmluc3RhbmNlKSB7XG4gICAgICAgICAgICBESUNvbnRhaW5lci5pbnN0YW5jZSA9IG5ldyBESUNvbnRhaW5lcigpO1xuICAgICAgICB9XG4gICAgICAgIHJldHVybiBESUNvbnRhaW5lci5pbnN0YW5jZTtcbiAgICB9XG5cbiAgICBwcml2YXRlIGluaXRpYWxpemUoKSB7XG4gICAgICAgIC8vIENhbWJpYXIgYSB0cnVlIHBhcmEgZGVzYXJyb2xsbyBoZWFkbGVzcyBvIHBydWViYXMgc2luIGVudG9ybm8gR1RLL0FHU1xuICAgICAgICBjb25zdCB1c2VNb2NrID0gZmFsc2U7XG5cbiAgICAgICAgY29uc3QgYXVkaW9TZXJ2aWNlID0gdXNlTW9jayA/IG5ldyBNb2NrQXVkaW9BZGFwdGVyKCkgOiBuZXcgQWdzQXVkaW9BZGFwdGVyKCk7XG4gICAgICAgIGNvbnN0IGJhdHRlcnlTZXJ2aWNlID0gdXNlTW9jayA/IG5ldyBNb2NrQmF0dGVyeUFkYXB0ZXIoKSA6IG5ldyBBZ3NCYXR0ZXJ5QWRhcHRlcigpO1xuICAgICAgICBjb25zdCBuZXR3b3JrU2VydmljZSA9IG5ldyBBZ3NOZXR3b3JrQWRhcHRlcigpO1xuICAgICAgICBjb25zdCB3b3Jrc3BhY2VTZXJ2aWNlID0gbmV3IEFnc1dvcmtzcGFjZUFkYXB0ZXIoKTtcblxuICAgICAgICAvLyBJbnllY2NpXHUwMEYzbiBkZSBkZXBlbmRlbmNpYXMgbGltcGlhIGVuIGxhIGluc3RhbmNpYWNpXHUwMEYzbiBkZSBjYXNvcyBkZSB1c29cbiAgICAgICAgdGhpcy5hdWRpb1VzZUNhc2UgPSBuZXcgTWFuYWdlQXVkaW8oYXVkaW9TZXJ2aWNlKTtcbiAgICAgICAgdGhpcy5iYXR0ZXJ5VXNlQ2FzZSA9IG5ldyBNYW5hZ2VCYXR0ZXJ5KGJhdHRlcnlTZXJ2aWNlKTtcbiAgICAgICAgdGhpcy5uZXR3b3JrVXNlQ2FzZSA9IG5ldyBNYW5hZ2VOZXR3b3JrKG5ldHdvcmtTZXJ2aWNlKTtcbiAgICAgICAgdGhpcy53b3Jrc3BhY2VVc2VDYXNlID0gbmV3IE1hbmFnZVdvcmtzcGFjZXMod29ya3NwYWNlU2VydmljZSk7XG4gICAgfVxufVxuIiwgImltcG9ydCB7IFdvcmtzcGFjZVVzZUNhc2UgfSBmcm9tIFwiLi4vLi4vLi4vY29yZS9wb3J0cy9pbmJvdW5kL3dvcmtzcGFjZS11c2VjYXNlLmpzXCI7XG5pbXBvcnQgeyBXb3Jrc3BhY2UgfSBmcm9tIFwiLi4vLi4vLi4vY29yZS9lbnRpdGllcy93b3Jrc3BhY2UuanNcIjtcblxuZXhwb3J0IGNsYXNzIFdvcmtzcGFjZUNvbnRyb2xsZXIge1xuICAgIGNvbnN0cnVjdG9yKHByaXZhdGUgd29ya3NwYWNlVXNlQ2FzZTogV29ya3NwYWNlVXNlQ2FzZSkge31cblxuICAgIGdldFdvcmtzcGFjZXMoKTogV29ya3NwYWNlW10ge1xuICAgICAgICByZXR1cm4gdGhpcy53b3Jrc3BhY2VVc2VDYXNlLmdldFdvcmtzcGFjZXMoKTtcbiAgICB9XG5cbiAgICBnb1RvV29ya3NwYWNlKGlkOiBudW1iZXIpOiB2b2lkIHtcbiAgICAgICAgdGhpcy53b3Jrc3BhY2VVc2VDYXNlLmdvVG9Xb3Jrc3BhY2UoaWQpO1xuICAgIH1cblxuICAgIHN1YnNjcmliZShjYWxsYmFjazogKHdvcmtzcGFjZXM6IFdvcmtzcGFjZVtdKSA9PiB2b2lkKTogKCkgPT4gdm9pZCB7XG4gICAgICAgIHJldHVybiB0aGlzLndvcmtzcGFjZVVzZUNhc2Uub25Xb3Jrc3BhY2VzQ2hhbmdlZChjYWxsYmFjayk7XG4gICAgfVxufVxuIiwgImltcG9ydCB7IEF1ZGlvVXNlQ2FzZSB9IGZyb20gXCIuLi8uLi8uLi9jb3JlL3BvcnRzL2luYm91bmQvYXVkaW8tdXNlY2FzZS5qc1wiO1xuaW1wb3J0IHsgQXVkaW9TdGF0ZSB9IGZyb20gXCIuLi8uLi8uLi9jb3JlL2VudGl0aWVzL2F1ZGlvLmpzXCI7XG5cbmV4cG9ydCBjbGFzcyBBdWRpb0NvbnRyb2xsZXIge1xuICAgIGNvbnN0cnVjdG9yKHByaXZhdGUgYXVkaW9Vc2VDYXNlOiBBdWRpb1VzZUNhc2UpIHt9XG5cbiAgICBnZXRWb2x1bWUoKTogbnVtYmVyIHtcbiAgICAgICAgcmV0dXJuIHRoaXMuYXVkaW9Vc2VDYXNlLmdldFZvbHVtZSgpO1xuICAgIH1cblxuICAgIGlzTXV0ZWQoKTogYm9vbGVhbiB7XG4gICAgICAgIHJldHVybiB0aGlzLmF1ZGlvVXNlQ2FzZS5pc011dGVkKCk7XG4gICAgfVxuXG4gICAgdG9nZ2xlTXV0ZSgpOiB2b2lkIHtcbiAgICAgICAgdGhpcy5hdWRpb1VzZUNhc2UudG9nZ2xlTXV0ZSgpO1xuICAgIH1cblxuICAgIHNldFZvbHVtZShwZXJjZW50OiBudW1iZXIpOiB2b2lkIHtcbiAgICAgICAgdGhpcy5hdWRpb1VzZUNhc2Uuc2V0Vm9sdW1lKHBlcmNlbnQpO1xuICAgIH1cblxuICAgIHN1YnNjcmliZShjYWxsYmFjazogKHN0YXRlOiBBdWRpb1N0YXRlKSA9PiB2b2lkKTogKCkgPT4gdm9pZCB7XG4gICAgICAgIHJldHVybiB0aGlzLmF1ZGlvVXNlQ2FzZS5vbkF1ZGlvQ2hhbmdlZChjYWxsYmFjayk7XG4gICAgfVxufVxuIiwgImltcG9ydCB7IEJhdHRlcnlVc2VDYXNlIH0gZnJvbSBcIi4uLy4uLy4uL2NvcmUvcG9ydHMvaW5ib3VuZC9iYXR0ZXJ5LXVzZWNhc2UuanNcIjtcbmltcG9ydCB7IEJhdHRlcnlTdGF0ZSB9IGZyb20gXCIuLi8uLi8uLi9jb3JlL2VudGl0aWVzL2JhdHRlcnkuanNcIjtcblxuZXhwb3J0IGNsYXNzIEJhdHRlcnlDb250cm9sbGVyIHtcbiAgICBjb25zdHJ1Y3Rvcihwcml2YXRlIGJhdHRlcnlVc2VDYXNlOiBCYXR0ZXJ5VXNlQ2FzZSkge31cblxuICAgIGdldEJhdHRlcnlJbmZvKCk6IEJhdHRlcnlTdGF0ZSB7XG4gICAgICAgIHJldHVybiB0aGlzLmJhdHRlcnlVc2VDYXNlLmdldEJhdHRlcnlJbmZvKCk7XG4gICAgfVxuXG4gICAgc3Vic2NyaWJlKGNhbGxiYWNrOiAoc3RhdGU6IEJhdHRlcnlTdGF0ZSkgPT4gdm9pZCk6ICgpID0+IHZvaWQge1xuICAgICAgICByZXR1cm4gdGhpcy5iYXR0ZXJ5VXNlQ2FzZS5vbkJhdHRlcnlDaGFuZ2VkKGNhbGxiYWNrKTtcbiAgICB9XG59XG4iLCAiaW1wb3J0IHsgTmV0d29ya1VzZUNhc2UgfSBmcm9tIFwiLi4vLi4vLi4vY29yZS9wb3J0cy9pbmJvdW5kL25ldHdvcmstdXNlY2FzZS5qc1wiO1xuaW1wb3J0IHsgTmV0d29ya1N0YXRlIH0gZnJvbSBcIi4uLy4uLy4uL2NvcmUvZW50aXRpZXMvbmV0d29yay5qc1wiO1xuXG5leHBvcnQgY2xhc3MgTmV0d29ya0NvbnRyb2xsZXIge1xuICAgIGNvbnN0cnVjdG9yKHByaXZhdGUgbmV0d29ya1VzZUNhc2U6IE5ldHdvcmtVc2VDYXNlKSB7fVxuXG4gICAgZ2V0TmV0d29ya0luZm8oKTogTmV0d29ya1N0YXRlIHtcbiAgICAgICAgcmV0dXJuIHRoaXMubmV0d29ya1VzZUNhc2UuZ2V0TmV0d29ya0luZm8oKTtcbiAgICB9XG5cbiAgICB0b2dnbGVXaWZpKCk6IHZvaWQge1xuICAgICAgICB0aGlzLm5ldHdvcmtVc2VDYXNlLnRvZ2dsZVdpZmkoKTtcbiAgICB9XG5cbiAgICBzdWJzY3JpYmUoY2FsbGJhY2s6IChzdGF0ZTogTmV0d29ya1N0YXRlKSA9PiB2b2lkKTogKCkgPT4gdm9pZCB7XG4gICAgICAgIHJldHVybiB0aGlzLm5ldHdvcmtVc2VDYXNlLm9uTmV0d29ya0NoYW5nZWQoY2FsbGJhY2spO1xuICAgIH1cbn1cbiJdLAogICJtYXBw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
