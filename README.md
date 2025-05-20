# NFS-Broker Genesis Kit

This Genesis Kit deploys the [Cloud Foundry NFS Broker][1], which allows Cloud Foundry applications to mount existing NFS volumes via the CF volume services feature. The broker is deployed as a single VM via BOSH, backed by persistent disk storage to manage the service-broker state.

> **Note:** If you have a MySQL or PostgreSQL service available in your Cloud Foundry, you may prefer deploying the NFS broker as a CF application with a database backend for high availability. This Genesis Kit is ideal for environments where a standalone broker is preferred or where database services aren't readily available.

## Architecture Overview

```
+------------------+       +------------------+       +------------------+
|                  |       |                  |       |                  |
|  Cloud Foundry   | <---> |   NFS Broker     | <---> |   External NFS   |
|  Applications    |       |   Service        |       |   Servers        |
|                  |       |                  |       |                  |
+------------------+       +------------------+       +------------------+
```

The NFS Broker acts as an intermediary service broker between Cloud Foundry applications and external NFS servers. It enables applications to mount NFS shares that exist outside of Cloud Foundry. The broker does not provision new NFS shares; it connects applications to existing NFS infrastructure.

## Prerequisites

* Genesis v2.6.0 or later
* A BOSH director with stemcells and cloud config
* Network connectivity from the broker VM to Cloud Foundry
* Network connectivity from Cloud Foundry application containers to external NFS servers
* Cloud Foundry deployment with volume services support
* Access to existing NFS servers/shares that should be mounted

## Quick Start

To use it, you don't even need to clone this repository! Just run the following:

```bash
# Create a nfs-broker-deployments repo using the latest version of the nfs-broker kit
genesis init --kit nfs-broker

# Create a nfs-broker-deployments repo using v1.0.0 of the nfs-broker kit
genesis init --kit nfs-broker/1.0.0

# Create a my-nfs-broker-configs repo using the latest version of the nfs-broker kit
genesis init --kit nfs-broker -d my-nfs-broker-configs
```

Once created, you can create a new environment and deploy:

```bash
# Create a new environment file
genesis new my-env

# Deploy the environment
genesis deploy my-env
```

After deployment, you can register the broker with Cloud Foundry:

```bash
# Register the broker with Cloud Foundry
genesis do my-env -- addon register-broker
```

## Features

* Service broker for mounting existing NFS volumes
* Support for both NFSv3 and NFSv4 protocols
* Integration with Cloud Foundry volume services
* Persistent broker state management
* Built-in broker registration with Cloud Foundry
* Addon commands for managing broker registration

## Parameters

### Required Parameters

* **params.system_domain** - The system domain of the Cloud Foundry deployment that this broker will be registered with (e.g., `system.bosh-lite.com`). This value is used to determine the Cloud Controller API domain and to register the broker's route (`nfs-broker.<system-domain>`).

* **params.cf_admin_pass** - A Vault path to a key that contains the Cloud Foundry admin password, used to authenticate to Cloud Foundry for registering the broker. For example: `secret/us/east/prod/cf/adminuser:password`.

* **params.static_ip** - Static IP address for the NFS broker VM (added during environment creation).

### Optional Parameters

* **params.cf_admin_user** - The username to authenticate to Cloud Foundry with, for registering the broker. Defaults to `admin`.

* **params.cf_deployment** - The name of the BOSH deployment for Cloud Foundry, which this environment will register with. It is used for finding the `nats` BOSH link. The default value will be the environment name concatenated with `cf`. For example, for `us-west-prod`, it will be `us-west-prod-cf`.

* **params.skip_ssl_validation** - Defines whether or not SSL certificates will be validated when registering the service broker. Off by default (certs are checked). Turn this on if your Cloud Foundry is using self-signed certificates.

* **params.network** - The network to deploy the broker VM on. Defaults to `default`.

* **params.availability_zones** - What AZs to deploy the broker into. Defaults to `[z1]`.

* **params.stemcell_os** - The stemcell OS to use. Defaults to `ubuntu-xenial`.

* **params.stemcell_version** - The stemcell version to use. Defaults to `latest`.

## Cloud Config Requirements

By default, this kit uses the following VM types/networks/disk pools from your Cloud Config. Feel free to override them in your environment, if you would rather they use entities already existing in your infrastructure:

```yaml
params:
  network:   default
  disk_pool: small # should be at least 1GB
  vm_type:   small # VMs should have at least 1 CPU, and 1GB of memory
```

## Addon Commands

This kit provides several addons to help manage the NFS broker:

* **register-broker** - Registers the broker with Cloud Foundry
  ```bash
  genesis do my-env -- addon register-broker [--skip-ssl-validation] [--force]
  ```

* **deregister-broker** - Removes the broker from Cloud Foundry
  ```bash
  genesis do my-env -- addon deregister-broker [--recursive]
  ```

* **runtime-config** - Generates a BOSH runtime config for broker registration
  ```bash
  genesis do my-env -- addon runtime-config
  ```

## Cloud Foundry Service Usage

Once the broker is registered, developers can create and bind to NFS shares:

```bash
# Create a service instance
cf create-service nfs Existing my-nfs-share

# Bind the service to an application with mount parameters
cf bind-service my-app my-nfs-share -c '{
  "share": "nfs-server.example.com/export/path",
  "uid": "1000",
  "gid": "1000",
  "mount": "nfsvers=4,rsize=1048576,wsize=1048576"
}'
```

The application will have access to the NFS share at `/var/vcap/data/nfs/`.

## Troubleshooting

### Common Issues

* **Broker Registration Fails** - Ensure Cloud Foundry admin credentials are correct and connectivity exists between the broker VM and Cloud Foundry API.

* **Cannot Connect to NFS Servers** - Verify network connectivity between Cloud Foundry application containers and NFS servers. Check security groups in Cloud Foundry to ensure necessary ports (111, 2049) are allowed.

* **Mount Failures** - Verify the NFS server export path exists and is correctly specified in the bind parameters. Check that the NFS server allows access from the Cloud Foundry cell IP addresses.

## Further Reading

For more detailed information, refer to:
* [NFS Volume Release Documentation][1]
* [Cloud Foundry Volume Services Documentation](https://docs.cloudfoundry.org/devguide/services/using-vol-services.html)
* [Service Broker API Documentation](https://github.com/openservicebrokerapi/servicebroker/blob/master/spec.md)

[1]: https://github.com/cloudfoundry/nfs-volume-release