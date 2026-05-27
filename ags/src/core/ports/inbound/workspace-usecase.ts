import { Workspace } from "../../entities/workspace.js";

export interface WorkspaceUseCase {
    getWorkspaces(): Workspace[];
    goToWorkspace(id: number): void;
    onWorkspacesChanged(callback: (workspaces: Workspace[]) => void): () => void;
}
