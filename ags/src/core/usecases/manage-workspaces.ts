import { WorkspaceUseCase } from "../ports/inbound/workspace-usecase.js";
import { WorkspaceService } from "../ports/outbound/workspace-service.js";
import { Workspace } from "../entities/workspace.js";

export class ManageWorkspaces implements WorkspaceUseCase {
    constructor(private workspaceService: WorkspaceService) {}

    getWorkspaces(): Workspace[] {
        return this.workspaceService.getWorkspaces();
    }

    goToWorkspace(id: number): void {
        this.workspaceService.changeWorkspace(id);
    }

    onWorkspacesChanged(callback: (workspaces: Workspace[]) => void): () => void {
        return this.workspaceService.subscribe(callback);
    }
}
