#!/usr/bin/env node
/**
 * Simple JWT generator for CI testing
 * Creates a test JWT token using the AUTH_JWT_SECRET environment variable
 */

const crypto = require('crypto');

function base64UrlEncode(str) {
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function createTestJWT(secret, userId = 'test-user-ci') {
  const header = {
    alg: 'HS256',
    typ: 'JWT'
  };

  const payload = {
    sub: userId,
    email: 'test@ci.example.com',
    exp: Math.floor(Date.now() / 1000) + (60 * 60), // 1 hour expiry
    iat: Math.floor(Date.now() / 1000)
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  
  const data = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto
    .createHmac('sha256', secret)
    .update(data)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');

  return `${data}.${signature}`;
}

const secret = process.env.AUTH_JWT_SECRET;
if (!secret) {
  console.error('AUTH_JWT_SECRET environment variable is required');
  process.exit(1);
}

const userId = process.argv[2] || 'test-user-ci';
const jwt = createTestJWT(secret, userId);
console.log(jwt);
