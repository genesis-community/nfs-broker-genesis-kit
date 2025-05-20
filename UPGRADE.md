# Upgrading the NFS Broker Genesis Kit

This document provides instructions for upgrading the NFS Broker Genesis Kit between versions.

## General Upgrade Process

The general process for upgrading the NFS Broker Genesis Kit is:

1. Update your deployment repository
2. Update the kit version in your environment file
3. Review this document for version-specific changes
4. Deploy the updated version
5. Verify the upgrade

## Upgrading Your Deployment Repository

```bash
# Change to your deployment repository directory
cd my-nfs-broker-deployments

# Fetch the latest changes
git pull

# If using a kit version constraint, update it
genesis kit-provider use nfs-broker latest
```

## Updating Your Environment Files

Update the kit version in your environment files:

```yaml
kit:
  name: nfs-broker
  version: NEW_VERSION  # Replace with the target version
```

## Version-Specific Upgrade Notes

### Upgrading to v1.0.0

When upgrading to v1.0.0:

- The broker now requires a static IP address parameter (`params.static_ip`)
- The addon commands have been refactored to Perl modules
- No data migration is needed as the broker state is maintained on persistent disk

#### Required Actions

1. Make sure `params.static_ip` is set in your environment file
2. Use the new addon syntax: `genesis do ENV_NAME -- addon register-broker`

### Upgrading from Earlier Releases

If you're upgrading from a pre-release version or a version before v1.0.0, you should:

1. Back up your environment configs
2. Create a new deployment using v1.0.0
3. Manually transfer configuration values
4. Deploy the new version
5. Deregister the old broker
6. Register the new broker

## Pre-Upgrade Checklist

Before upgrading, check:

- [ ] You have a recent backup of your environment file
- [ ] You have reviewed version-specific changes
- [ ] You have scheduled a maintenance window if needed
- [ ] You have admin access to Cloud Foundry
- [ ] You have a backup strategy for NFS data (not managed by this kit)

## Upgrade Steps

### 1. Backup Current Configuration

```bash
# Backup your environment file
cp my-env.yml my-env.yml.bak

# Check current deployment
genesis info my-env
```

### 2. Update Kit Version

```bash
# Edit your environment file
vim my-env.yml

# Change the kit version
# kit:
#   name: nfs-broker
#   version: NEW_VERSION
```

### 3. Check Deployment for Required Changes

```bash
# Check for required parameter changes
genesis check my-env
```

### 4. Deploy the Updated Version

```bash
# Deploy the updated version
genesis deploy my-env
```

### 5. Verify the Upgrade

```bash
# Check the deployed version
genesis info my-env

# Verify broker is still registered
cf service-brokers | grep nfs

# Verify service access is still enabled
cf service-access | grep nfs
```

### 6. Test Service Functionality

To verify the upgraded broker works correctly:

```bash
# Create a test instance
cf create-service nfs Existing test-nfs-upgrade

# Create a test app
cf push test-app --no-start

# Bind the app to the service
cf bind-service test-app test-nfs-upgrade -c '{
  "share": "nfs-server.example.com/export/test",
  "uid": "1000",
  "gid": "1000"
}'

# Start the app
cf start test-app

# Check the logs for successful mounting
cf logs test-app --recent | grep nfs
```

## Rollback Procedure

If the upgrade fails or causes issues, you can roll back to the previous version:

1. Restore the previous environment file:
   ```bash
   cp my-env.yml.bak my-env.yml
   ```

2. Deploy the previous version:
   ```bash
   genesis deploy my-env
   ```

3. Verify the rollback:
   ```bash
   genesis info my-env
   ```

## Troubleshooting Upgrade Issues

### Broker Registration Problems

If the broker fails to register after upgrade:

```bash
# Manually re-register the broker
genesis do my-env -- addon register-broker --force
```

### Service Binding Issues

If applications can't bind to the service after upgrade:

1. Verify the broker is registered properly:
   ```bash
   cf service-brokers
   ```

2. Check the broker credentials haven't changed:
   ```bash
   genesis secrets my-env | grep broker
   ```

3. Re-register the broker with the current credentials:
   ```bash
   genesis do my-env -- addon register-broker --force
   ```

### Manifest Generation Errors

If you encounter manifest generation errors during `genesis deploy`:

1. Check for parameter changes between versions in the kit's README
2. Ensure all required parameters are present in your environment file
3. Try with the `--recreate` flag if VM changes are required:
   ```bash
   genesis deploy my-env --recreate
   ```

## Version History

| Version | Release Date | Notable Changes |
|---------|--------------|----------------|
| v1.0.0  | Initial OSS Release | Initial Genesis Kit release |

## Getting Help

If you encounter issues upgrading that aren't addressed in this document:

- Check the README.md for updated parameters
- Submit issues to the [GitHub repository](https://github.com/genesis-community/nfs-broker-genesis-kit)
- Consult the Genesis documentation for general upgrade guidance