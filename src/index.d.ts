export interface Env {
    MEILISEARCH_HOST: string;
    MEILI_MASTER_KEY: string;
    MEILI_SEARCH_KEY: string;
    AUTH_JWT_SECRET: string;
}
export interface DocumentMetadata {
    id: string;
    title: string;
    summary: string;
    entities: string[];
    topics: string[];
    userId: string;
    filename: string;
    mimeType: string;
    uploadedAt: string;
    lastAnalyzed: string;
}
declare const _default: {
    fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response>;
};
export default _default;
