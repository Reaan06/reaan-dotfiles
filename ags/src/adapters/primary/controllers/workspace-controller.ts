import { WorkspaceUseCase } from "../../../core/ports/inbound/workspace-usecase.js";
import { Workspace } from "../../../core/entities/workspace.js";

export class WorkspaceController {
    constructor(private workspaceUseCase: WorkspaceUseCase) {}

    getWorkspaces(): Workspace[] {
        return this.workspaceUseCase.getWorkspaces();
    }

    goToWorkspace(id: number): void {
        this.workspaceUseCase.goToWorkspace(id);
    }

    subscribe(callback: (workspaces: Workspace[]) => void): () => void {
        return this.workspaceUseCase.onWorkspacesChanged(callback);
    }
}
