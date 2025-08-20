# ZAP Automation Framework Best Practices (2025)

## Recent Updates Applied

### 1. Removed Deprecated `addOns` Job ✅
- **Issue**: The `addOns` job in automation plans is deprecated and will be removed in the next major release
- **Solution**: Add-ons are now installed at Docker build time in the Dockerfile
- **Files Updated**: 
  - `Dockerfile`: Added explicit add-on installation during build
  - `ci/tasks/zap-af.yml`: Removed deprecated addOns job from automation plans

### 2. Docker Image Best Practices ✅
- **Added**: `ZAP_VERSION` build argument for version pinning flexibility
- **Ensures**: Critical add-ons (reportgenerator, openapi) are always installed
- **Supports**: Optional add-on updates via `ENABLE_ADDON_UPDATE` build arg

## Current Best Practices Implemented

### Authentication ✅
- Using replacer rules for token injection (recommended approach)
- Supporting multiple auth methods: CF UAA, OpsUAA, static headers
- Tokens acquired separately and passed to ZAP via environment

### Report Generation ✅
- Multiple format support: HTML, JSON, XML, SARIF
- Per-hostname report generation for granular tracking
- Configurable risk/confidence filtering
- Central configuration via `reporting.yml`

### Job Ordering ✅
Correct sequence maintained:
1. `options` - Global configuration
2. `replacer` - Authentication setup (when needed)
3. `import`/`openapi` - Target specification
4. `spider` - Discovery phase
5. `activeScan` - Active testing
6. `report` - Multiple format generation
7. `exitStatus` - Threshold-based exit codes

### Security & Compliance ✅
- Non-root user execution in container
- CredHub integration for secrets management
- No hardcoded credentials
- GPG signature verification in pipeline

## Recommendations for Future Improvements

### 1. Version Pinning
Consider pinning specific ZAP versions for production stability:
```bash
docker build --build-arg ZAP_VERSION=2.14.0 -t zap-runner .
```

### 2. Advanced Authentication
For more complex auth scenarios, consider:
- Session management jobs for stateful apps
- Script jobs for custom authentication flows
- User management for multi-user testing

### 3. Performance Optimization
- Implement parallel scanning for multiple contexts
- Use context-specific spider/scan configurations
- Consider passive scan wait times for large applications

### 4. Enhanced Reporting
- Implement custom report templates for specific compliance needs
- Add trend analysis across scan runs
- Integrate with additional vulnerability management platforms

### 5. Monitoring & Alerting
- Add health checks for long-running scans
- Implement scan performance metrics collection
- Set up alerts for critical findings

## ZAP AF Command Reference

### Validate Automation Plans
```bash
docker run zap-runner zap.sh -cmd -autorun /path/to/plan.yaml -autocheckplan
```

### Run with Debugging
```bash
docker run zap-runner zap.sh -cmd -autorun /path/to/plan.yaml -autoexit
```

### Generate Minimal Plan
```bash
docker run zap-runner zap.sh -cmd -autogenmin /path/to/plan.yaml
```

## Important Notes

1. **Add-on Management**: Never use the deprecated `addOns` job in automation plans. Install add-ons at build time or manually before running plans.

2. **Exit Codes**: 
   - 0 = Success (no issues found)
   - 1 = Errors occurred
   - 2 = Warnings found (even with failOnWarning: false)

3. **Path References**: Use absolute paths in Docker contexts, relative paths in automation plans for portability.

4. **Authentication Tokens**: Always use replacer rules or environment variables, never hardcode in plans.

5. **Scan Depth**: Balance thoroughness with time constraints using appropriate spider depth and scan duration limits.