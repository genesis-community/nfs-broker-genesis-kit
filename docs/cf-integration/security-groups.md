# Cloud Foundry Security Groups for NFS

This document explains how to configure Cloud Foundry security groups to allow applications to connect to NFS servers when using the NFS Broker.

## Overview

Cloud Foundry uses security groups to control outbound network access from application containers. For applications to communicate with external NFS servers, you must configure appropriate security groups that allow traffic to the NFS server IP addresses on the required ports.

## Required Ports for NFS

NFS requires several ports to be open for proper operation:

| Protocol | Port | Service | Description |
|----------|------|---------|-------------|
| TCP | 111 | portmapper/rpcbind | Maps RPC services to the ports they're listening on |
| UDP | 111 | portmapper/rpcbind | Maps RPC services to the ports they're listening on |
| TCP | 2049 | nfs | Main NFS service port |
| UDP | 2049 | nfs | Main NFS service port |
| TCP | 635 | mountd | Mount daemon (may use different ports) |
| UDP | 635 | mountd | Mount daemon (may use different ports) |
| TCP | 4045 | nlockmgr | Lock manager for NFS (may use different ports) |
| UDP | 4045 | nlockmgr | Lock manager for NFS (may use different ports) |
| TCP | 32803 | status | Status monitoring (may use different ports) |
| UDP | 32803 | status | Status monitoring (may use different ports) |

> **Note:** Some NFS server configurations may use different ports for mountd, nlockmgr, and status services. Check your NFS server configuration to determine the exact ports needed.

## Creating a Security Group

### Basic Security Group

For a basic NFS setup, create a security group that allows access to the primary NFS ports:

```json
[
  {
    "protocol": "tcp",
    "destination": "NFS-SERVER-IP/32",
    "ports": "111,2049"
  },
  {
    "protocol": "udp",
    "destination": "NFS-SERVER-IP/32",
    "ports": "111,2049"
  }
]
```

Replace `NFS-SERVER-IP` with the IP address of your NFS server.

### Comprehensive Security Group

For more complex NFS setups, you may need to include additional ports:

```json
[
  {
    "protocol": "tcp",
    "destination": "NFS-SERVER-IP/32",
    "ports": "111,2049,635,4045,32803"
  },
  {
    "protocol": "udp",
    "destination": "NFS-SERVER-IP/32",
    "ports": "111,2049,635,4045,32803"
  }
]
```

### Multiple NFS Servers

If your applications need to access multiple NFS servers, you can include all of them in the security group:

```json
[
  {
    "protocol": "tcp",
    "destination": "NFS-SERVER-1-IP/32",
    "ports": "111,2049"
  },
  {
    "protocol": "udp",
    "destination": "NFS-SERVER-1-IP/32",
    "ports": "111,2049"
  },
  {
    "protocol": "tcp",
    "destination": "NFS-SERVER-2-IP/32",
    "ports": "111,2049"
  },
  {
    "protocol": "udp",
    "destination": "NFS-SERVER-2-IP/32",
    "ports": "111,2049"
  }
]
```

### IP Range

If your NFS servers are in a contiguous IP range, you can use CIDR notation:

```json
[
  {
    "protocol": "tcp",
    "destination": "192.168.1.0/24",
    "ports": "111,2049"
  },
  {
    "protocol": "udp",
    "destination": "192.168.1.0/24",
    "ports": "111,2049"
  }
]
```

This allows access to any IP in the 192.168.1.0/24 subnet.

## Applying Security Groups

### Creating and Applying the Security Group

1. Save your security group JSON to a file, e.g., `nfs-security-group.json`

2. Create the security group:
   ```bash
   cf create-security-group nfs-access nfs-security-group.json
   ```

3. Apply the security group to all spaces in an organization:
   ```bash
   cf bind-security-group nfs-access ORG_NAME --space-name SPACE_NAME
   ```

4. Or apply to all spaces in all organizations:
   ```bash
   cf bind-security-group nfs-access ORG_NAME --globally
   ```

### Applying to Running Applications

Security group changes only affect new application instances. To apply changes to running applications, you must restart them:

```bash
cf restart APP_NAME
```

Or, to restart all applications in a space:

```bash
cf apps | grep started | awk '{print $1}' | xargs -n 1 cf restart
```

## Verifying Security Group Configuration

To verify security groups:

1. List all security groups:
   ```bash
   cf security-groups
   ```

2. View details of a specific security group:
   ```bash
   cf security-group nfs-access
   ```

3. Check which security groups apply to a space:
   ```bash
   cf space-security-groups SPACE_NAME
   ```

4. Test connectivity from an application:
   ```bash
   cf ssh APP_NAME -c "nc -zv NFS-SERVER-IP 2049"
   ```

## Troubleshooting

### Common Issues

#### Application Can't Connect to NFS Server

If your application logs show connectivity issues to the NFS server:

1. Verify the security group is correctly configured:
   ```bash
   cf security-group nfs-access
   ```

2. Ensure the security group is bound to the space:
   ```bash
   cf space-security-groups SPACE_NAME
   ```

3. Confirm the NFS server IP is correct and listening on the expected ports:
   ```bash
   cf ssh APP_NAME -c "nc -zv NFS-SERVER-IP 2049"
   ```

4. Check if your NFS server firewall allows connections from Cloud Foundry:
   ```bash
   # On the NFS server
   iptables -L | grep ACCEPT
   ```

#### RPC Connection Errors

If you see errors related to RPC or portmapper:

1. Ensure port 111 is included in your security group
2. Verify the NFS server has portmapper/rpcbind running
3. Check for any firewall rules blocking RPC traffic

#### Changes to Security Group Not Taking Effect

If changes to security groups aren't taking effect:

1. Restart the affected applications
2. Verify the security group is bound to the correct spaces
3. Check for conflicting security group rules

## Best Practices

1. **Least Privilege**: Only open the specific ports required for NFS communication to specific NFS server IPs
2. **Use Specific IP Addresses**: Avoid using overly broad CIDR ranges
3. **Document Your Configuration**: Keep track of which security groups are for which NFS servers
4. **Regular Auditing**: Periodically review security groups to ensure they reflect current requirements
5. **Test Before Production**: Verify NFS connectivity in a non-production space before deploying to production

## Advanced Configuration

### Using ASGs with NFS Volume Services

When using the NFS volume service with the broker, the same security group requirements apply. The broker doesn't eliminate the need for proper security group configuration.

### Dynamic IP Environments

In environments where NFS server IPs might change:

1. Use DNS names in your application configuration
2. Update security groups whenever IPs change
3. Consider using a more stable networking solution for NFS servers

## Related Topics

- [Application Binding](application-binding.md) - How applications bind to and use NFS shares
- [Broker Registration](broker-registration.md) - How the broker registers with Cloud Foundry