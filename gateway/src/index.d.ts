interface Env {
    MEILISEARCH_HOST: string;
    MEILI_MASTER_KEY: string;
    MEILI_SEARCH_KEY: string;
    AUTH_JWT_SECRET: string;
    ALLOWED_ORIGINS: string;
}
declare const _default: {
    fetch(request: Request, env: Env): Promise<Response>;
};
export default _default;
