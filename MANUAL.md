# NFS-Broker Genesis Kit Manual

## Introduction

The NFS-Broker Genesis Kit deploys a service broker for Cloud Foundry that allows applications to mount existing NFS volumes through Cloud Foundry's volume services feature. 

Unlike other service brokers that provision new resources, the NFS broker connects applications to existing NFS infrastructure. This enables Cloud Foundry applications to access persistent storage that exists outside of the platform, making it ideal for scenarios such as:

- Sharing files between applications
- Accessing pre-existing data stores
- Providing persistent storage that survives application restarts
- Integration with existing NFS-based workflows and systems

The broker is deployed as a single VM through BOSH, making it suitable for environments where a standalone service is preferred over running the broker as a Cloud Foundry application.

## Architecture

The NFS Broker deployment consists of the following components:

1. **NFS Broker Service** - The core broker component that implements the Service Broker API
2. **Route Registrar** - Registers routes with Cloud Foundry's routing tier
3. **Broker Registrar** - Registers the broker with the Cloud Foundry Cloud Controller

The broker does not handle NFS connections directly. Instead, it provides the configuration for Cloud Foundry's volume drivers, which run on the Diego cells and manage the actual mounting of NFS volumes to application containers.

### Component Diagram

```
+------------------------------------------------------------------------------+
|                                                                              |
|                             Cloud Foundry                                     |
|                                                                              |
|  +------------------+       +------------------+      +------------------+   |
|  |                  |       |                  |      |                  |   |
|  |  Cloud           |       |  Diego Cell     |      |  Router          |   |
|  |  Controller      |       |                 |      |                  |   |
|  |                  |       |  +------------+ |      |                  |   |
|  +--------+---------+       |  | NFS Volume | |      +---------+--------+   |
|           |                 |  | Driver     | |                |            |
|           |                 |  +------+-----+ |                |            |
+-----------|-----------------|---------|-------|----------------|------------+
            |                 |         |       |                |
            |                 |         |       |                |
            |                 v         v       |                |
            |          +-----+----------+------+|                |
            |          |                       ||                |
            |          |  Application          ||                |
            |          |  Container            ||                |
            |          |                       ||                |
            |          +-----------------------+|                |
            |                                                    |
            |                                                    |
            v                                                    v
+---------------------------+                       +---------------------------+
|                           |                       |                           |
|  NFS Broker VM            |                       |  External NFS Server      |
|                           |                       |                           |
|  +-------------------+    |                       |  +-------------------+    |
|  |                   |<---+-----------------------+->|                   |    |
|  | Service Broker    |    |                       |  | NFS Exports       |    |
|  |                   |    |                       |  |                   |    |
|  +-------------------+    |                       |  +-------------------+    |
|  |                   |    |                       |                           |
|  | Route Registrar   |    |                       +---------------------------+
|  |                   |    |
|  +-------------------+    |
|  |                   |    |
|  | Broker Registrar  |    |
|  |                   |    |
|  +-------------------+    |
|                           |
+---------------------------+
```

## Deployment Guide

### Pre-Deployment Requirements

Before deploying the NFS Broker, ensure you have:

1. A BOSH director configured with the appropriate cloud provider
2. A Cloud Foundry deployment that supports volume services
3. Network connectivity between:
   - The broker VM and Cloud Foundry (for broker registration)
   - Cloud Foundry application containers and external NFS servers
4. Access to Genesis v2.6.0 or later
5. Access to a Vault instance for credential management
6. One or more external NFS servers with exports that will be used by applications

### Deployment Steps

#### 1. Initialize the Deployment Repository

```bash
# Create a new deployment repository
genesis init --kit nfs-broker -d nfs-broker-deployments
cd nfs-broker-deployments
```

#### 2. Create a New Environment

```bash
# Create a new environment file
genesis new my-env
```

During environment creation, you'll be prompted for:
- The network to use
- A static IP address for the broker VM

This will generate an environment file at `my-env.yml` with initial configuration.

#### 3. Edit the Environment File

You'll need to further customize your environment file with required parameters:

```yaml
---
kit:
  name: nfs-broker
  version: latest
  features:
    - (( append ))

genesis:
  env: my-env

params:
  # Required parameters
  static_ip: 10.0.0.10
  system_domain: system.example.com
  cf_admin_pass: secret/path/to/cf-admin-password
  
  # Optional parameters
  cf_admin_user: admin
  cf_deployment: my-env-cf
  skip_ssl_validation: false
  
  # Cloud config overrides (if needed)
  network: default
  vm_type: small
  disk_pool: small
  availability_zones: [z1]

  # Stemcell configuration (if needed)
  stemcell_os: ubuntu-xenial
  stemcell_version: latest
```

#### 4. Deploy the Environment

```bash
# Check for potential issues
genesis check my-env

# Deploy the environment
genesis deploy my-env
```

#### 5. Register the Broker with Cloud Foundry

After deployment, the broker needs to be registered with Cloud Foundry. You can do this in one of two ways:

**Option 1: Using the addon command (recommended)**

```bash
genesis do my-env -- addon register-broker
```

**Option 2: The broker will attempt to self-register during deployment**

The manifest includes a `broker-registrar` job that attempts to register the broker during deployment. However, this may fail if there are connectivity issues or if credentials are incorrect.

### Post-Deployment Configuration

After deploying and registering the broker, you should:

1. **Enable access to the service**

```bash
cf enable-service-access nfs
```

2. **Configure appropriate security groups in Cloud Foundry**

Create a security group that allows traffic to your NFS servers:

```json
[
  {
    "protocol": "tcp",
    "destination": "192.168.1.100/32",
    "ports": "111,2049"
  },
  {
    "protocol": "udp",
    "destination": "192.168.1.100/32",
    "ports": "111,2049"
  }
]
```

Save this as `nfs-security-group.json` and apply it:

```bash
cf create-security-group nfs-access nfs-security-group.json
cf bind-security-group nfs-access org space
```

3. **Verify the broker is working**

```bash
cf service-brokers
cf service-access
```

## Configuration Reference

### Core Parameters

#### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `params.system_domain` | The system domain of the Cloud Foundry deployment | `system.example.com` |
| `params.cf_admin_pass` | Vault path to CF admin password | `secret/path/to/cf-admin-password` |
| `params.static_ip` | Static IP for the broker VM | `10.0.0.10` |

#### Optional Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `params.cf_admin_user` | Username for CF admin | `admin` | `admin` |
| `params.cf_deployment` | Name of CF deployment | `<env>-cf` | `my-env-cf` |
| `params.skip_ssl_validation` | Skip SSL certificate validation | `false` | `true` |
| `params.network` | Network for deployment | `default` | `cf` |
| `params.vm_type` | VM type from cloud config | `small` | `medium` |
| `params.disk_pool` | Disk pool from cloud config | `small` | `medium` |
| `params.availability_zones` | AZs to deploy into | `[z1]` | `[z1, z2]` |
| `params.stemcell_os` | Stemcell OS | `ubuntu-xenial` | `ubuntu-jammy` |
| `params.stemcell_version` | Stemcell version | `latest` | `621.94` |

### Network Configuration

The NFS Broker requires network connectivity to:

1. **Cloud Foundry API** - For broker registration
2. **NATS Message Bus** - For route registration
3. **External NFS Servers** - For validation (optional)

Cloud Foundry application containers will need network connectivity to the external NFS servers to mount shares.

## Addon Usage Guide

The NFS Broker Genesis Kit provides several addons to help manage the broker.

### Register Broker Addon

The `register-broker` addon registers the broker with Cloud Foundry.

**Usage:**
```bash
genesis do my-env -- addon register-broker [options]
```

**Options:**
- `--skip-ssl-validation` - Skip SSL validation when connecting to the CF API
- `--force` or `-f` - Force re-registration even if the broker already exists
- `--yes` or `-y` - Skip confirmation prompts

**Example:**
```bash
# Register with SSL validation disabled
genesis do my-env -- addon register-broker --skip-ssl-validation

# Force re-registration
genesis do my-env -- addon register-broker --force
```

### Deregister Broker Addon

The `deregister-broker` addon removes the broker registration from Cloud Foundry.

**Usage:**
```bash
genesis do my-env -- addon deregister-broker [options]
```

**Options:**
- `--recursive` or `-r` - Delete all service instances and bindings before deregistering
- `--yes` or `-y` - Skip confirmation prompts

**Example:**
```bash
# Deregister broker and all service instances
genesis do my-env -- addon deregister-broker --recursive

# Deregister without prompts
genesis do my-env -- addon deregister-broker --yes
```

### Runtime Config Addon

The `runtime-config` addon generates a BOSH runtime config for broker registration, which can be used to automate broker registration across BOSH deployments.

**Usage:**
```bash
genesis do my-env -- addon runtime-config [options]
```

**Options:**
- `--cf-deployment` - Name of CF deployment
- `--cf-api-url` - URL of CF API
- `--skip-ssl-validation` - Skip SSL validation with CF API

**Example:**
```bash
# Generate runtime config with custom CF deployment name
genesis do my-env -- addon runtime-config --cf-deployment my-cf
```

## Application Developer Guide

### Creating Service Instances

To create an NFS service instance:

```bash
cf create-service nfs Existing my-nfs-share
```

This creates a service instance that can be bound to applications, but doesn't yet specify which NFS share to mount.

### Binding Applications

When binding an application to the service instance, you must provide the NFS share details:

```bash
cf bind-service my-app my-nfs-share -c '{
  "share": "nfs-server.example.com/export/path",
  "uid": "1000",
  "gid": "1000",
  "mount": "nfsvers=4,rsize=1048576,wsize=1048576"
}'
```

**Binding parameters:**

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| `share` | NFS server and export path | Yes | `nfs-server.example.com/export/path` |
| `uid` | UID that mounted files appear to be owned by | No | `1000` |
| `gid` | GID that mounted files appear to be owned by | No | `1000` |
| `mount` | Additional mount options | No | `nfsvers=4,rsize=1048576,wsize=1048576` |

After binding, the application needs to be restaged or restarted to access the NFS share:

```bash
cf restage my-app
```

The NFS share will be mounted at: `/var/vcap/data/nfs/`

### Using NFS in Applications

Applications can access the mounted NFS share at `/var/vcap/data/nfs/`.

**Example Node.js code:**
```javascript
const fs = require('fs');
const path = '/var/vcap/data/nfs/test.txt';

// Writing to NFS
fs.writeFileSync(path, 'Hello NFS!');

// Reading from NFS
const data = fs.readFileSync(path, 'utf8');
console.log(data);
```

**Example Java code:**
```java
import java.nio.file.*;

public class NfsExample {
    public static void main(String[] args) throws Exception {
        Path path = Paths.get("/var/vcap/data/nfs/test.txt");
        
        // Writing to NFS
        Files.write(path, "Hello NFS!".getBytes());
        
        // Reading from NFS
        String content = new String(Files.readAllBytes(path));
        System.out.println(content);
    }
}
```

## Operator Guide

### Monitoring

The NFS Broker VM should be monitored for:

- **System health**: CPU, memory, disk usage
- **Process health**: Ensure the broker process is running
- **Log monitoring**: Watch for errors in `/var/vcap/sys/log/nfsbroker/nfsbroker.log`

### Backup and Restore

The NFS Broker stores its state on the persistent disk attached to the VM. To back up this state:

1. Use BOSH's backup and restore features
2. Take snapshots of the VM's persistent disk if supported by your IaaS

If the broker VM is lost, redeploying with the same IP address should restore functionality.

### Scaling Considerations

The NFS Broker is designed to run as a single instance. While it does not support horizontal scaling, you can adjust the VM size based on expected load:

- For environments with fewer than 100 service instances, the default small VM is adequate
- For environments with more instances, consider increasing the VM resources:
  ```yaml
  params:
    vm_type: medium  # or large
  ```

### Upgrading

To upgrade the NFS Broker:

1. Update your deployment repository
   ```bash
   cd nfs-broker-deployments
   git pull
   ```

2. Update the kit version in your environment file
   ```yaml
   kit:
     name: nfs-broker
     version: 1.2.0  # New version
   ```

3. Deploy the updated version
   ```bash
   genesis deploy my-env
   ```

4. Verify the upgrade
   ```bash
   genesis info my-env
   ```

## Troubleshooting Guide

### Common Issues

#### Deployment Failures

**Issue**: Deployment fails with network errors

**Solution**:
- Verify the static IP is available and in the correct subnet
- Check that the network exists in your cloud config
- Ensure BOSH director has network access to the VM

#### Broker Registration Issues

**Issue**: Broker registration fails

**Solution**:
- Verify CF admin credentials are correct
- Check network connectivity to the CF API
- If using self-signed certificates, use `--skip-ssl-validation`
- Check the broker job logs: `bosh -d my-env logs nfsbroker/0 broker-registrar`

#### Service Binding Issues

**Issue**: Applications can't bind to the service or access NFS shares

**Solution**:
- Verify security groups allow traffic to NFS servers
- Check NFS server export permissions
- Ensure the NFS server allows access from CF Diego cell IPs
- Validate the NFS export path exists
- Check application logs for mount errors
- Verify mount parameters in the binding

### Diagnostic Procedures

#### Check Broker Status

```bash
# Check BOSH deployment
bosh -d my-env instances

# Check broker process
bosh -d my-env ssh nfsbroker/0 "monit summary"

# Check broker logs
bosh -d my-env logs nfsbroker/0 nfsbroker
```

#### Verify CF Registration

```bash
# Check broker registration
cf service-brokers

# Check service access
cf service-access

# Check for existing service instances
cf services
```

#### Test NFS Connectivity

Create a test application to verify NFS connectivity:

```bash
# Create a simple test app
cf push nfs-test --no-start

# Create and bind NFS service
cf create-service nfs Existing test-nfs
cf bind-service nfs-test test-nfs -c '{
  "share": "nfs-server.example.com/export/path"
}'

# Start the app
cf start nfs-test

# Check app logs for mount issues
cf logs nfs-test --recent
```

## Support Resources

If you encounter issues not covered in this manual, you can:

- Submit issues to the [GitHub repository](https://github.com/genesis-community/nfs-broker-genesis-kit)
- Refer to the [Cloud Foundry Volume Services documentation](https://docs.cloudfoundry.org/devguide/services/using-vol-services.html)
- Check the [NFS Volume Release](https://github.com/cloudfoundry/nfs-volume-release) repository for specific NFS issues