# Deregister Broker Addon

The `deregister-broker` addon removes the NFS broker registration from Cloud Foundry. This is useful when decommissioning the broker, performing maintenance, or troubleshooting issues with the broker registration.

## Usage

```bash
genesis do <env-name> -- addon deregister-broker [options]
```

## Options

| Option | Description |
|--------|-------------|
| `--recursive` or `-r` | Delete all service instances and bindings before deregistering the broker. This ensures clean removal of all resources created through the broker. |
| `--yes` or `-y` | Skip confirmation prompts. Useful for automated scripts. |

## Requirements

To use this addon successfully:

1. The Cloud Foundry CLI must be installed on the machine running the command
2. You must be logged in to Cloud Foundry with admin privileges
3. The broker must be registered with Cloud Foundry

## Examples

### Basic Deregistration

```bash
# Deregister the broker with default options
genesis do my-env -- addon deregister-broker
```

### Recursive Deregistration

```bash
# Delete all service instances and bindings before deregistering
genesis do my-env -- addon deregister-broker --recursive
```

### Non-interactive Deregistration

```bash
# Deregister without prompts (for automation)
genesis do my-env -- addon deregister-broker --yes
```

### Combining Options

```bash
# Recursively deregister without prompts
genesis do my-env -- addon deregister-broker --recursive --yes
```

## How It Works

Under the hood, this addon:

1. Retrieves broker information from the deployment's exodus data
2. Checks if the broker is registered with Cloud Foundry
3. If the recursive option is specified:
   - Finds all service instances created by this broker
   - Deletes each service instance (which automatically deletes bindings)
4. Deregisters the broker using the CF CLI

## Recursive Deregistration Process

When the `--recursive` option is used, the addon performs these additional steps:

1. Calls the CF API to get all service offerings from the broker
2. For each service offering, retrieves all service plans
3. For each service plan, finds all service instances
4. Deletes each service instance (with force flag)
5. Waits for deletion to complete before deregistering the broker

This ensures a clean removal of all resources created through the broker.

## Troubleshooting

### Common Issues

**Error: You are not logged in to Cloud Foundry**

Ensure you are logged in to Cloud Foundry with admin credentials:
```bash
cf login -a api.<system-domain> -u admin -p <password>
```

**Error: Service broker does not exist**

If the broker is already deregistered or was never registered, the addon will inform you and exit successfully.

**Error: Failed to delete service instance**

During recursive deletion, service instance deletion might fail if:
- The service instance is in use by an application
- The service instance deletion is taking too long
- CF API errors occur

In these cases, manually investigate and delete the service instances before retrying.

## Use Cases

### Maintenance

When performing maintenance on the broker or updating its configuration, deregister it first:

```bash
# Deregister broker
genesis do my-env -- addon deregister-broker

# Perform maintenance operations...

# Register broker again
genesis do my-env -- addon register-broker
```

### Decommissioning

When completely removing the broker, use recursive deregistration to clean up all resources:

```bash
# Remove all service instances and the broker registration
genesis do my-env -- addon deregister-broker --recursive

# Then delete the deployment
genesis delete my-env
```

### Troubleshooting

If the broker registration is in an inconsistent state, deregister and re-register:

```bash
genesis do my-env -- addon deregister-broker --force
genesis do my-env -- addon register-broker --force
```

## Related Commands

- [register-broker](register-broker.md) - Registers the broker with Cloud Foundry
- [runtime-config](runtime-config.md) - Generates a BOSH runtime config for broker registration