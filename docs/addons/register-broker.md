# Register Broker Addon

The `register-broker` addon registers the NFS broker with Cloud Foundry, making the service available for developers to use. This addon provides a convenient way to register the broker after deployment or to re-register it if the registration is lost.

## Usage

```bash
genesis do <env-name> -- addon register-broker [options]
```

## Options

| Option | Description |
|--------|-------------|
| `--skip-ssl-validation` | Skip SSL validation when connecting to the CF API. Use this when your CF deployment uses self-signed certificates. |
| `--force` or `-f` | Force re-registration even if the broker already exists. This will update the broker configuration if it has changed. |
| `--yes` or `-y` | Skip confirmation prompts. Useful for automated scripts. |

## Requirements

To use this addon successfully:

1. The Cloud Foundry CLI must be installed on the machine running the command
2. You must be logged in to Cloud Foundry with admin privileges
3. The NFS broker deployment must be running and accessible
4. The broker's static IP must be reachable from where the command is run

## Examples

### Basic Registration

```bash
# Register the broker with default options
genesis do my-env -- addon register-broker
```

### Registration with SSL Validation Disabled

```bash
# Skip SSL validation (for environments with self-signed certificates)
genesis do my-env -- addon register-broker --skip-ssl-validation
```

### Force Re-registration

```bash
# Force re-registration (updates existing broker)
genesis do my-env -- addon register-broker --force
```

### Non-interactive Registration

```bash
# Register without prompts (for automation)
genesis do my-env -- addon register-broker --yes
```

## How It Works

Under the hood, this addon:

1. Retrieves broker information from the deployment's exodus data (URL, credentials)
2. Checks if the broker is already registered with Cloud Foundry
3. Registers or updates the broker using the CF CLI
4. Enables access to the service offering

## Troubleshooting

### Common Issues

**Error: You are not logged in to Cloud Foundry**

Ensure you are logged in to Cloud Foundry with admin credentials:
```bash
cf login -a api.<system-domain> -u admin -p <password>
```

**Error: Cannot determine NFS broker password**

This occurs when the exodus data is missing. Try re-deploying the environment:
```bash
genesis deploy my-env
```

**Error: Failed to update service broker**

This could be due to connectivity issues or incorrect credentials. Check:
- Network connectivity to the CF API
- CF admin credentials are correct
- Broker URL is accessible from where the command is run

## Related Commands

- [deregister-broker](deregister-broker.md) - Removes the broker registration
- [runtime-config](runtime-config.md) - Generates a BOSH runtime config for broker registration