NFS-Broker Genesis Kit
======================

This is a Genesis Kit for the [Cloud Foundry NFS Broker][1]. It will
deploy the NFS Broker as a single VM via BOSH, backed by persistent
disk storage to manage the service-broker state. If you have a MySQL
or Postgres service availabile in your Cloud Foundry, you are better
off deploying the NFS broker as an app on Cloud Foundry, and connecting
it to a database, to get an HA service broker.

Quick Start
-----------

To use it, you don't even need to clone this repository!  Just run
the following (using Genesis v2):

```
# create a nfs-broker-deployments repo using the latest version of the nfs-broker kit
genesis init --kit nfs-broker

# create a nfs-broker-deployments repo using v1.0.0 of the nfs-broker kit
genesis init --kit nfs-broker/1.0.0

# create a my-nfs-broker-configs repo using the latest version of the nfs-broker kit
genesis init --kit nfs-broker -d my-nfs-broker-configs
```

Once created, refer to the deployment repo's README for information on creating

Subkits
-------

There are no subkits in this kit. It's pretty straight-forward.

Params
------

#### Base Params

- **params.system_domain** - the system domain of the Cloud Foundry that this broker
  will be registered with. For example `system.bosh-lite.com`. This value is used to
  determine the domain of the Cloud Controller API, as well as register a domain for
  the service broker itself (`nfs-broker.<system-domain>`)
- **params.cf_admin_user** - The username to authenticate to Cloud Foundry with, for
  registering the broker. Defaults to `admin`.
- **params.cf_admin_pass** - A Vault path to a key that contains the Cloud Foundry admin
  password, used to authenticate to Cloud Foundry for registering the broker. For example:
  `secret/us/east/prod/cf/adminuser:password`.
- **params.cf_deployment** - The name of the BOSH deployment for Cloud Foundry, which this
  environmet will register with. It is used for finding the `nats` BOSH link. The default
  value will be the environment name concatenated with `cf`. So, for `us-west-prod`,
  it will be `us-west-prod-cf`.
- **params.skip_ssl_validation** - Defines whether or not SSL certificates will be validated
  when registering the service broker. Off by default (certs are checked). Turn this on, if
  your Cloud Foundry is using self-signed certs.

[1]: https://github.com/cloudfoundry/nfs-volume-release
