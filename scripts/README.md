# Meilisearch Scripts Directory

This directory contains the rationalized, consolidated testing and deployment scripts for the Meilisearch ecosystem.

## Core Scripts (Ready to Use)

### 🧪 `meilisearch-test-suite.ps1` - **Main Test Suite** ⭐
The primary, consolidated testing framework for the entire Meilisearch ecosystem.

**Usage:**
```powershell
# Health checks only (recommended for quick validation)
.\meilisearch-test-suite.ps1 -Health

# Complete test suite (health + search + auth)
.\meilisearch-test-suite.ps1 -All

# Show secrets configuration guide
.\meilisearch-test-suite.ps1 -Secrets

# Safe deployment with health checks
.\meilisearch-test-suite.ps1 -Deploy -Environment production
```

**Features:**
- ✅ Health checks for all services (Railway, Integration Worker, Gateway, Content Skimmer)
- ✅ Search functionality tests
- ✅ Authentication flow validation
- ✅ Safe deployment with pre-checks
- ✅ Secrets management guidance
- ✅ Environment support (production/staging)

### 🔄 `run-core-tests.ps1` - **Legacy Test Runner**
Runs the original three core test scripts in sequence.

**Usage:**
```powershell
.\run-core-tests.ps1 -Environment production
```

**Note:** Use `meilisearch-test-suite.ps1` instead for new testing - it's more comprehensive.

### 🌐 `url-checker.ps1` - **Quick URL Health Check**
Fast health check for all service endpoints.

**Usage:**
```powershell
.\url-checker.ps1
```

### 🎯 `test-actual-worker.ps1` - **Worker-Specific Test**
Tests the specific integration worker deployed by GitHub Actions.

### 🔍 `integration-test.ps1` - **Comprehensive Integration Test**
Complete integration test with detailed reporting.

## Archived Scripts

The `archived/` directory contains:
- Old duplicate scripts
- Outdated setup scripts
- Debugging scripts
- Alternative implementations

These are kept for reference but should not be used in production.

## Quick Start

For most use cases, simply run:

```powershell
# Quick health check
.\meilisearch-test-suite.ps1 -Health

# Complete validation
.\meilisearch-test-suite.ps1 -All
```

## Services Tested

- **Railway Meilisearch**: `https://meilisearch-service-production-01e0.up.railway.app`
- **Integration Worker**: `https://meilisearch-integration.tamylatrading.workers.dev`
- **Gateway Service**: `https://search.tamyla.com`
- **Content Skimmer**: `https://content-skimmer.tamylatrading.workers.dev`

## Exit Codes

- `0`: All tests passed
- `1`: Some tests failed (>80% success)
- `2`: Major failures (<80% success)
- `3`: Deployment failed

## Current Status

✅ **All health endpoints operational**  
✅ **Integration worker deployed and responding**  
✅ **Custom domain `search.tamyla.com` working**  
✅ **Railway Meilisearch available**  
✅ **Content Skimmer healthy**

The Meilisearch ecosystem is fully operational and ready for production use.
