import Widget from "resource:///com/github/Aylur/ags/widget.js";
import { WorkspaceController } from "../../controllers/workspace-controller.js";
import { Workspace } from "../../../../core/entities/workspace.js";

export function WorkspaceWidget(controller: WorkspaceController) {
    const box = Widget.Box({
        class_name: "workspaces-container",
        spacing: 4,
    });

    const update = (workspaces: Workspace[]) => {
        box.children = workspaces.map((ws) =>
            Widget.Button({
                class_name: `workspace-button ${ws.isActive ? "active" : ""}`,
                label: ws.name,
                on_clicked: () => controller.goToWorkspace(ws.id),
            })
        );
    };

    const unsubscribe = controller.subscribe(update);

    box.setup = (self: any) => {
        self.connect("destroy", unsubscribe);
    };

    // Render inicial
    update(controller.getWorkspaces());

    return box;
}
