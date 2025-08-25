/**
 * JWT Authentication utilities for Meilisearch service
 * Based on the same pattern used in data-service and content-store-service
 */
/**
 * Verify a JWT token using Web Crypto API
 * @param {string} token - The JWT token to verify
 * @param {string} secret - The secret key to verify the token with
 * @returns {Promise<Object>} The decoded token payload if verification is successful
 * @throws {Error} If the token is invalid or expired
 */
export declare function verifyToken(token: string, secret: string): Promise<any>;
/**
 * Extract JWT token from request using standard priority order
 * @param {Request} request
 * @returns {string|null} JWT token or null
 */
export declare function extractToken(request: Request): string | null;
/**
 * Authenticate request using JWT token
 * @param {Request} request - The incoming request
 * @param {string} jwtSecret - JWT secret for verification
 * @returns {Promise<Object>} Authentication result
 */
export declare function authenticateRequest(request: Request, jwtSecret: string): Promise<{
    success: boolean;
    user?: {
        id: string;
        email?: string;
        name?: string;
    };
    error?: string;
}>;
