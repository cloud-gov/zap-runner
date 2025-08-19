Certainly! To support **multiple APIs** (each with its own OpenAPI specification) within your automation pipeline, we’ll set up the `ci/scan-contexts/api/` directory with everything needed. This will include:

- Multiple `openapi-*.json` files (one per API)
- A `config.yml` that defines scan behavior for all APIs
- A `urls.txt` listing the API base URLs (optional, depending on design)
- A `README.md` explaining how it's structured

Below are the **complete, production-ready files** to drop into `ci/scan-contexts/api/`—nothing omitted, everything you need.

---

## 1. `ci/scan-contexts/api/config.yml`

```yaml
# API scanning configuration for multiple OpenAPI-based APIs
AUTH_TYPE: header # Use header-based auth (via CredHub token)
SCAN_TYPE: api # Indicates OpenAPI-style API scanning
SPIDER_MAX_DEPTH: 2
MAX_SCAN_DURATION: 45
ALERT_THRESHOLD: MEDIUM
# If you want to enforce a particular base URL override,
# uncomment and adjust:
# target_override: "https://api.example.gov"

# Example mapping file names to target URLs, if needed (optional)
# openapi_specs:
#   - file: "openapi-users.json"
#     target: "https://api.example.gov/v1/users"
#   - file: "openapi-orders.json"
#     target: "https://api.example.gov/v1/orders"
```

---

## 2. `ci/scan-contexts/api/openapi-users.json`

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "Users API",
    "version": "1.0.0",
    "description": "User management endpoints"
  },
  "servers": [{ "url": "https://api.example.gov/v1/users" }],
  "paths": {
    "/users": {
      "get": {
        "summary": "List all users",
        "responses": {
          "200": {
            "description": "A list of users",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": { "$ref": "#/components/schemas/User" }
                }
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "User": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "name": { "type": "string" }
        }
      }
    }
  }
}
```

---

## 3. `ci/scan-contexts/api/openapi-orders.json`

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "Orders API",
    "version": "1.0.0",
    "description": "Order management endpoints"
  },
  "servers": [{ "url": "https://api.example.gov/v1/orders" }],
  "paths": {
    "/orders": {
      "get": {
        "summary": "List all orders",
        "responses": {
          "200": {
            "description": "A list of orders",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": { "$ref": "#/components/schemas/Order" }
                }
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "Order": {
        "type": "object",
        "properties": {
          "orderId": { "type": "string" },
          "amount": { "type": "number" }
        }
      }
    }
  }
}
```

---

## 4. `ci/scan-contexts/api/openapi-inventory.json`

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "Inventory API",
    "version": "1.0.0",
    "description": "Inventory management endpoints"
  },
  "servers": [{ "url": "https://api.example.gov/v1/inventory" }],
  "paths": {
    "/inventory": {
      "get": {
        "summary": "Get inventory levels",
        "responses": {
          "200": {
            "description": "Inventory data",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "items": {
                      "type": "array",
                      "items": { "$ref": "#/components/schemas/Item" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "Item": {
        "type": "object",
        "properties": {
          "sku": { "type": "string" },
          "count": { "type": "integer" }
        }
      }
    }
  }
}
```

---

## 5. `ci/scan-contexts/api/urls.txt`

```text
# API base URLs (optional; used if fallback behavior requires)
https://api.example.gov/v1/users
https://api.example.gov/v1/orders
https://api.example.gov/v1/inventory
```

---

## 6. `ci/scan-contexts/api/README.md`

````markdown
# API Scan Context – Multiple OpenAPI Specs

This context supports scanning _multiple_ OpenAPI-defined APIs in a single pipeline run.

## Included Files

- `config.yml`: Main context configuration (authentication, thresholds, scan type).
- `openapi-users.json`: OpenAPI spec for Users API.
- `openapi-orders.json`: OpenAPI spec for Orders API.
- `openapi-inventory.json`: OpenAPI spec for Inventory API.
- `urls.txt`: Optional list of base URLs; used if needed as fallback.

## Scanning Behavior

The automation task (`zap-af.yml`) will:

1. Locate all `openapi-*.json` files under this directory.
2. For each file:
   - Inject an `openapi` AF job to import endpoints.
   - Optionally override the target URL if this is defined in `config.yml`.
   - Run `spider`, `activeScan`, and generate reports per API.
3. Apply central user-agent, exclusions, and report settings.

## Extending

- To add another API, drop in a new `openapi-<component>.json` file with its spec.
- To override the target URL (if needed), extend `config.yml` like:

```yaml
openapi_specs:
  - file: "openapi-users.json"
    target: "https://api.example.gov/v1/users"
```
````

## References

- ZAP Automation Framework `openapi` job: import definitions from file or URL ([ZAP][1], [ZAP][2], [Google Groups][3])
- You can include multiple `openapi` jobs in a plan to import several definitions (ZAP User Group) ([Google Groups][3])

---

### Why This Setup Works

- Remote imports are handled via ZAP's Automation Framework **`openapi` job**, which allows multiple definitions. :contentReference[oaicite:10]{index=10}
- Structuring multiple specs gives you **clear, per-API reporting** and **fine-grained auth/control**.
- Your existing `zap-af.yml` logic (with dynamic template generation) will loop over these files automatically, giving proper per-API outputs.

Let me know if you'd like me to integrate loading multiple OpenAPI specs into the generator logic inside `zap-af.yml`—happy to customize that next!

[1]: https://www.zaproxy.org/docs/desktop/addons/openapi-support/automation/"OpenAPI Automation Framework Support - ZAP"
[2]: https://www.zaproxy.org/docs/desktop/addons/openapi-support/"OpenAPI Support - ZAP"
[3]: https://groups.google.com/g/zaproxy-users/c/5Ya1cafBwj8"Use OpenAPI folder in the zap automation framework"
