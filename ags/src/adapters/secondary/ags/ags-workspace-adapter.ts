import { WorkspaceService } from "../../../core/ports/outbound/workspace-service.js";
import { Workspace } from "../../../core/entities/workspace.js";
import AgsHyprland from "resource:///com/github/Aylur/ags/service/hyprland.js";

export class AgsWorkspaceAdapter implements WorkspaceService {
    getWorkspaces(): Workspace[] {
        const activeId = AgsHyprland.active.workspace?.id ?? 1;
        const rawWorkspaces = AgsHyprland.workspaces || [];
        const workspacesMap = new Map<number, string>();

        rawWorkspaces.forEach((w) => {
            workspacesMap.set(w.id, w.name || `${w.id}`);
        });

        // Asegurar que por lo menos los workspaces 1 a 5 estén visibles
        const defaultIds = [1, 2, 3, 4, 5];
        defaultIds.forEach((id) => {
            if (!workspacesMap.has(id)) {
                workspacesMap.set(id, `${id}`);
            }
        });

        const list: Workspace[] = [];
        workspacesMap.forEach((name, id) => {
            list.push({
                id,
                name,
                isActive: id === activeId,
            });
        });

        return list.sort((a, b) => a.id - b.id);
    }

    changeWorkspace(id: number): void {
        AgsHyprland.messageAsync(`dispatch workspace ${id}`).catch(console.error);
    }

    subscribe(callback: (workspaces: Workspace[]) => void): () => void {
        const id = AgsHyprland.connect("changed", () => {
            callback(this.getWorkspaces());
        });
        return () => {
            AgsHyprland.disconnect(id);
        };
    }
}
