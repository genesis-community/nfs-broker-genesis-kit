# Example NFS Broker Deployment

This document provides a complete example of deploying and configuring the NFS Broker Genesis Kit for use with Cloud Foundry.

## Prerequisites

Before following this example, ensure you have:

1. A BOSH director with appropriate cloud config
2. Genesis v2.6.0 or later installed
3. A Cloud Foundry deployment
4. Access to Vault for credential management

## Step 1: Initialize the Deployment Repository

```bash
# Create a new deployment repository
genesis init --kit nfs-broker -d nfs-broker-deployments

# Change to the deployment directory
cd nfs-broker-deployments

# Initialize git repository
git init
git add .
git commit -m "Initial commit"
```

## Step 2: Create a New Environment

```bash
# Create a new environment called 'prod'
genesis new prod
```

During the interactive process, you'll be prompted for:
- The network to use (e.g., `cf-net`)
- A static IP address for the broker VM (e.g., `10.0.10.100`)

This will create an initial `prod.yml` file.

## Step 3: Configure the Environment

Edit the `prod.yml` file to add required parameters:

```yaml
---
kit:
  name: nfs-broker
  version: latest
  features:
    - (( append ))

genesis:
  env: prod

params:
  # Required parameters
  static_ip: 10.0.10.100
  system_domain: system.example.com
  cf_admin_pass: secret/cloud-foundry/cf/admin-password
  
  # Optional parameters
  cf_admin_user: admin
  cf_deployment: prod-cf
  skip_ssl_validation: false
  
  # Cloud config overrides
  network: cf-net
  vm_type: medium
  disk_pool: 10GB
  availability_zones: [z1, z2]

  # Stemcell configuration
  stemcell_os: ubuntu-xenial
  stemcell_version: latest
```

## Step 4: Check and Deploy

```bash
# Check the configuration for errors
genesis check prod

# Deploy the broker
genesis deploy prod
```

The deployment process will:
1. Generate credentials in Vault if they don't exist
2. Create a BOSH deployment manifest
3. Deploy the NFS broker using BOSH
4. Attempt to register the broker with Cloud Foundry

## Step 5: Register the Broker with Cloud Foundry

If the automatic registration during deployment fails, register manually:

```bash
# Log in to Cloud Foundry
cf login -a api.system.example.com -u admin -p $(safe get secret/cloud-foundry/cf/admin-password)

# Register the broker
genesis do prod -- addon register-broker
```

## Step 6: Configure Cloud Foundry Security Groups

Create a security group to allow access to your NFS servers:

```bash
# Create a security group file
cat > nfs-security-group.json <<EOF
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
EOF

# Create and bind the security group
cf create-security-group nfs-access nfs-security-group.json
cf bind-security-group nfs-access my-org my-space
```

## Step 7: Verify the Deployment

```bash
# Check the broker is running
bosh -d prod-nfs instances

# Verify the broker is registered with Cloud Foundry
cf service-brokers

# Check service access is enabled
cf service-access
```

You should see the NFS service listed with its Existing plan available.

## Step 8: Create and Test a Service Instance

```bash
# Create a test application
git clone https://github.com/cloudfoundry-samples/spring-music
cd spring-music
./gradlew clean assemble
cf push spring-music --no-start

# Create an NFS service instance
cf create-service nfs Existing my-nfs-share

# Bind the application to the NFS share
cf bind-service spring-music my-nfs-share -c '{
  "share": "nfs-server.example.com/export/music",
  "uid": "1000",
  "gid": "1000",
  "mount": "nfsvers=4,rsize=1048576,wsize=1048576"
}'

# Start the application
cf start spring-music

# Check the application logs for mount information
cf logs spring-music --recent | grep nfs
```

## Complete Example Configuration

### Environment File (prod.yml)

```yaml
---
kit:
  name: nfs-broker
  version: latest
  features:
    - (( append ))

genesis:
  env: prod

params:
  # Required parameters
  static_ip: 10.0.10.100
  system_domain: system.example.com
  cf_admin_pass: secret/cloud-foundry/cf/admin-password
  
  # Optional parameters
  cf_admin_user: admin
  cf_deployment: prod-cf
  skip_ssl_validation: false
  
  # Cloud config overrides
  network: cf-net
  vm_type: medium
  disk_pool: 10GB
  availability_zones: [z1, z2]

  # Stemcell configuration
  stemcell_os: ubuntu-xenial
  stemcell_version: latest
```

### Security Group Configuration (nfs-security-group.json)

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

### Service Binding Configuration

```json
{
  "share": "nfs-server.example.com/export/music",
  "uid": "1000",
  "gid": "1000",
  "mount": "nfsvers=4,rsize=1048576,wsize=1048576"
}
```

## Common Operations

### Updating the Deployment

To update the deployment with new configuration:

1. Edit the environment file (`prod.yml`)
2. Deploy the changes:
   ```bash
   genesis deploy prod
   ```

### Deregistering the Broker

To remove the broker registration:

```bash
genesis do prod -- addon deregister-broker --recursive
```

### Deleting the Deployment

To completely remove the deployment:

```bash
# Deregister the broker first
genesis do prod -- addon deregister-broker --recursive

# Delete the deployment
genesis delete prod
```

## Troubleshooting

### Broker Registration Fails

If broker registration fails:

```bash
# Check the broker VM is running
bosh -d prod-nfs instances

# Verify connectivity to Cloud Foundry API
curl -k https://api.system.example.com/v2/info

# Try registering with SSL validation disabled
genesis do prod -- addon register-broker --skip-ssl-validation
```

### Application Can't Mount NFS Share

If applications can't mount NFS shares:

```bash
# Verify security groups
cf security-groups

# Check the application logs
cf logs APP_NAME --recent

# Test connectivity from the application container
cf ssh APP_NAME -c "nc -zv NFS-SERVER-IP 2049"
```

This example provides a comprehensive deployment walkthrough that operators can follow to successfully deploy and use the NFS Broker with Cloud Foundry.