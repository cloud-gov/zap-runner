# ZAP Runner Test Suite

This directory contains comprehensive test and validation scripts for the ZAP Runner project.

## Test Scripts

### 🎯 `final-validation.sh`
**Purpose**: Complete end-to-end validation of the entire project  
**Coverage**: All aspects including structure, configuration, best practices, and compliance  
**Usage**: 
```bash
cd tests
./final-validation.sh
```

### 🔍 `test-zap-config.sh`
**Purpose**: Validates ZAP configuration and best practices compliance  
**Coverage**: Dockerfile, ZAP AF configuration, add-on installation  
**Usage**:
```bash
cd tests
./test-zap-config.sh
```

### 📋 `test-documented-commands.sh`
**Purpose**: Tests all commands documented in README.md  
**Coverage**: Scripts, configurations, authentication methods, pipelines  
**Usage**:
```bash
cd tests
./test-documented-commands.sh
```

### 🏗️ `verify-project-structure.sh`
**Purpose**: Verifies all required files and directories exist  
**Coverage**: Project structure, file presence, directory organization  
**Usage**:
```bash
cd tests
./verify-project-structure.sh
```

### 🔐 `validate-scan-contexts.sh`
**Purpose**: Validates all scan context configurations  
**Coverage**: Context URLs, configurations, OpenAPI specs, pipeline references  
**Usage**:
```bash
cd tests
./validate-scan-contexts.sh
```

## Running All Tests

To run the complete test suite:

```bash
cd tests

# Run final validation (includes all checks)
./final-validation.sh

# Or run individual tests
./test-zap-config.sh
./test-documented-commands.sh
./verify-project-structure.sh
./validate-scan-contexts.sh
```

## Test Results

All scripts provide color-coded output:
- 🟢 **Green**: Test passed
- 🔴 **Red**: Test failed  
- 🟡 **Yellow**: Warning or optional item missing
- 🔵 **Blue**: Information

## Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed

## Requirements

- Python 3 with PyYAML
- Bash 4.0+
- Standard Unix utilities (grep, sed, find, etc.)

## Adding New Tests

When adding new test scripts:
1. Place them in this `tests/` directory
2. Use relative paths (`../`) to reference project files
3. Follow the existing naming convention: `test-*.sh` or `validate-*.sh`
4. Include proper exit codes (0 for success, 1 for failure)
5. Add documentation to this README

## CI Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example Concourse task
- task: validate-configuration
  config:
    platform: linux
    image_resource:
      type: registry-image
      source:
        repository: python
        tag: 3.9-slim
    inputs:
      - name: zap-runner
    run:
      path: bash
      args:
        - -c
        - |
          cd zap-runner/tests
          ./final-validation.sh
```

## Troubleshooting

If tests fail with "file not found" errors:
- Ensure you're running from the `tests/` directory
- Check that all project files are present in the parent directory
- Verify Python and required modules are installed

For Docker-related tests:
- Some tests skip Docker builds to save time
- Run `docker build -t zap-runner ..` manually to test the build