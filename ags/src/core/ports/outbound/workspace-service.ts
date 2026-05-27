import { Workspace } from "../../entities/workspace.js";

export interface WorkspaceService {
    getWorkspaces(): Workspace[];
    changeWorkspace(id: number): void;
    subscribe(callback: (workspaces: Workspace[]) => void): () => void;
}
