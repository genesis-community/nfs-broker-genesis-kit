# Runtime Config Addon

The `runtime-config` addon generates a BOSH runtime config that can be used to automatically register the NFS broker with Cloud Foundry. This is useful for automated deployments and ensuring the broker is consistently registered across environment rebuilds.

## Usage

```bash
genesis do <env-name> -- addon runtime-config [options]
```

## Options

| Option | Description |
|--------|-------------|
| `--cf-deployment` | Specify the name of the Cloud Foundry deployment. Defaults to the environment name with `-cf` suffix. |
| `--cf-api-url` | Explicitly set the Cloud Foundry API URL. By default, it's determined from the system domain in exodus data. |
| `--skip-ssl-validation` | Configure the runtime config to skip SSL validation when connecting to the CF API. |

## Requirements

To use this addon successfully:

1. The NFS broker must be deployed
2. The deployment's exodus data must contain broker information (URL, credentials)
3. You must have BOSH CLI access to update runtime configs

## Examples

### Basic Runtime Config Generation

```bash
# Generate a runtime config with default options
genesis do my-env -- addon runtime-config
```

### Custom CF Deployment Name

```bash
# Specify a custom CF deployment name
genesis do my-env -- addon runtime-config --cf-deployment my-custom-cf
```

### Explicit CF API URL

```bash
# Explicitly set the CF API URL
genesis do my-env -- addon runtime-config --cf-api-url https://api.system.example.com
```

### Skip SSL Validation

```bash
# Configure to skip SSL validation
genesis do my-env -- addon runtime-config --skip-ssl-validation
```

## How It Works

This addon generates a BOSH runtime config that includes:

1. The broker-registrar job from the broker-registrar release
2. Configuration for connecting to Cloud Foundry
3. Configuration for registering the NFS broker service

The generated runtime config can be applied to your BOSH director to automate broker registration on all deployments.

## Using the Generated Runtime Config

After generating the runtime config, you can apply it to your BOSH director:

```bash
# Generate the runtime config
genesis do my-env -- addon runtime-config > nfs-broker-runtime.yml

# Apply the runtime config
bosh update-runtime-config nfs-broker-runtime.yml
```

To apply it as a named runtime config (recommended):

```bash
bosh update-runtime-config --name=nfs-broker nfs-broker-runtime.yml
```

## Advantages of Runtime Config Registration

Using a runtime config for broker registration offers several benefits:

1. **Automation** - Registration happens automatically as part of BOSH deployment
2. **Consistency** - Registration configuration is version-controlled
3. **Recovery** - If the broker VM is recreated, registration happens automatically
4. **Centralization** - Configuration is managed in one place

## Structure of the Generated Runtime Config

The generated runtime config follows this structure:

```yaml
releases:
  - name: broker-registrar
    version: "x.y.z"
    url: https://bosh.io/d/github.com/cloudfoundry-community/broker-registrar-boshrelease?v=x.y.z
    sha1: abcdef1234567890abcdef1234567890abcdef12

addons:
  - name: broker-registrar
    jobs:
      - name: broker-registrar
        release: broker-registrar
        properties:
          servicebroker:
            name: nfs-broker
            username: nfs-broker
            password: "((nfs-broker-password))"
            url: http://nfs-broker.system.example.com
          cf:
            api_url: https://api.system.example.com
            username: admin
            password: "((cf-admin-password))"
            skip_ssl_validation: false
```

## Managing Runtime Config Credentials

The generated runtime config references credentials that must be available to BOSH:

1. **NFS Broker Password** - The password for the broker
2. **CF Admin Password** - The password for the CF admin user

There are several ways to provide these credentials:

### Using Explicit Variables

```bash
bosh update-runtime-config --name=nfs-broker nfs-broker-runtime.yml \
  --var=nfs-broker-password=mypassword \
  --var=cf-admin-password=myadminpassword
```

### Using a Variables File

Create a variables file:
```yaml
# vars.yml
nfs-broker-password: mypassword
cf-admin-password: myadminpassword
```

Then apply it:
```bash
bosh update-runtime-config --name=nfs-broker nfs-broker-runtime.yml \
  --vars-file=vars.yml
```

### Using CredHub or a BOSH Variables Store

If you're using CredHub with your BOSH director, you can store the variables there:

```bash
credhub set -n /bosh-director/nfs-broker/nfs-broker-password -t password -v mypassword
credhub set -n /bosh-director/nfs-broker/cf-admin-password -t password -v myadminpassword
```

## Troubleshooting

### Common Issues

**Error: Cannot determine broker URL**

This occurs when exodus data is missing or incomplete. Try redeploying the environment:
```bash
genesis deploy my-env
```

**Runtime config applies but registration fails**

Check the BOSH logs for the runtime config job execution:
```bash
bosh -d <deployment> logs --job=broker-registrar
```

Common issues include:
- Incorrect CF API URL
- Invalid credentials
- Network connectivity issues
- SSL validation errors

## Related Commands

- [register-broker](register-broker.md) - Manually registers the broker with Cloud Foundry
- [deregister-broker](deregister-broker.md) - Removes the broker from Cloud Foundry