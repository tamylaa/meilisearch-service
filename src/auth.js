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
export async function verifyToken(token, secret) {
    if (!token) {
        throw new Error('No token provided');
    }
    if (!secret) {
        throw new Error('AUTH_JWT_SECRET is not defined');
    }
    const [encodedHeader, encodedData, signature] = token.split('.');
    if (!encodedHeader || !encodedData || !signature) {
        throw new Error('Invalid token format');
    }
    // Create HMAC signature using Web Crypto API
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const cryptoKey = await crypto.subtle.importKey('raw', keyData, { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
    // Convert base64url to Uint8Array
    const signatureBytes = new Uint8Array(atob(signature.replace(/-/g, '+').replace(/_/g, '/'))
        .split('')
        .map(c => c.charCodeAt(0)));
    // Verify the signature
    const data = encoder.encode(`${encodedHeader}.${encodedData}`);
    const isValid = await crypto.subtle.verify('HMAC', cryptoKey, signatureBytes, data);
    if (!isValid) {
        throw new Error('Invalid token signature');
    }
    // Decode payload
    const base64UrlDecode = (str) => {
        // Add padding if needed
        str = str.replace(/-/g, '+').replace(/_/g, '/');
        while (str.length % 4) {
            str += '=';
        }
        const binaryString = atob(str);
        const bytes = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
        }
        return JSON.parse(new TextDecoder().decode(bytes));
    };
    const payload = base64UrlDecode(encodedData);
    // Check expiration
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
        throw new Error('Token expired');
    }
    return payload;
}
/**
 * Extract JWT token from request using standard priority order
 * @param {Request} request
 * @returns {string|null} JWT token or null
 */
export function extractToken(request) {
    // Priority 1: Authorization header (Bearer token)
    const authHeader = request.headers.get('Authorization');
    if (authHeader && authHeader.startsWith('Bearer ')) {
        return authHeader.substring(7);
    }
    // Priority 2: Cookie (session_token or jwt_token)
    const cookieHeader = request.headers.get('Cookie');
    if (cookieHeader) {
        const cookies = parseCookies(cookieHeader);
        return cookies.session_token || cookies.jwt_token || cookies.token;
    }
    // Priority 3: Query parameter (for webhooks/special cases only)
    const url = new URL(request.url);
    const tokenParam = url.searchParams.get('token');
    if (tokenParam) {
        return tokenParam;
    }
    return null;
}
/**
 * Parse cookies from Cookie header
 * @param {string} cookieHeader
 * @returns {Object} Parsed cookies
 */
function parseCookies(cookieHeader) {
    if (!cookieHeader)
        return {};
    return cookieHeader.split(';').reduce((cookies, cookie) => {
        const [key, value] = cookie.trim().split('=');
        if (key && value) {
            cookies[key] = decodeURIComponent(value);
        }
        return cookies;
    }, {});
}
/**
 * Authenticate request using JWT token
 * @param {Request} request - The incoming request
 * @param {string} jwtSecret - JWT secret for verification
 * @returns {Promise<Object>} Authentication result
 */
export async function authenticateRequest(request, jwtSecret) {
    try {
        const token = extractToken(request);
        if (!token) {
            return {
                success: false,
                error: 'Missing or invalid authorization header'
            };
        }
        const payload = await verifyToken(token, jwtSecret);
        // Extract user information from token payload (following data-service pattern)
        const user = payload.user || {
            id: payload.sub || payload.userId || payload.user_id,
            email: payload.email,
            name: payload.name
        };
        return {
            success: true,
            user: user
        };
    }
    catch (error) {
        console.error('JWT Authentication error:', error);
        return {
            success: false,
            error: 'Invalid or expired token'
        };
    }
}
