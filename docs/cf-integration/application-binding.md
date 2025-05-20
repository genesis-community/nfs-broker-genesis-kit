# Application Binding Guide

This guide explains how Cloud Foundry applications can bind to and use NFS volumes provided by the NFS Broker.

## Overview

The NFS Broker allows Cloud Foundry applications to mount existing NFS shares that reside outside of the platform. When an application binds to an NFS service instance, the platform mounts the specified NFS share into the application container, providing persistent file storage.

## Prerequisites

Before binding an application to an NFS share:

1. The NFS Broker must be deployed and registered with Cloud Foundry
2. An NFS service instance must be created
3. Appropriate security groups must be configured in Cloud Foundry
4. The NFS server must be accessible from the Cloud Foundry application containers
5. The NFS server must allow access from the Cloud Foundry cell IP addresses

## Creating a Service Instance

Before binding, you must create an NFS service instance:

```bash
cf create-service nfs Existing my-nfs-share
```

This doesn't specify which NFS share to use; that happens during binding.

## Binding an Application

When binding an application to the NFS service instance, you must provide parameters that specify the NFS share to mount:

```bash
cf bind-service my-app my-nfs-share -c '{
  "share": "nfs-server.example.com/export/path",
  "uid": "1000",
  "gid": "1000",
  "mount": "nfsvers=4,rsize=1048576,wsize=1048576"
}'
```

### Binding Parameters

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| `share` | The NFS server hostname or IP address and the exported directory path | Yes | `nfs-server.example.com/export/path` |
| `uid` | User ID that mounted files appear to be owned by inside the application container | No | `1000` |
| `gid` | Group ID that mounted files appear to be owned by inside the application container | No | `1000` |
| `mount` | Comma-separated list of mount options | No | `nfsvers=4,rsize=1048576,wsize=1048576` |

### Binding using Application Manifest

You can also specify binding parameters in your application's manifest:

```yaml
---
applications:
- name: my-app
  services:
  - my-nfs-share
  env:
    NFS_SHARE_JSON: |
      {
        "share": "nfs-server.example.com/export/path",
        "uid": "1000",
        "gid": "1000",
        "mount": "nfsvers=4,rsize=1048576,wsize=1048576"
      }
```

Then bind with:

```bash
cf bind-service my-app my-nfs-share -c $NFS_SHARE_JSON
```

### Common NFS Mount Options

| Option | Description | Example |
|--------|-------------|---------|
| `nfsvers` | NFS protocol version | `nfsvers=4` |
| `rsize` | Read buffer size | `rsize=1048576` |
| `wsize` | Write buffer size | `wsize=1048576` |
| `timeo` | Timeout (tenths of a second) | `timeo=600` |
| `retrans` | Number of retransmissions | `retrans=2` |
| `sec` | Security flavor | `sec=sys` |
| `ro` | Read-only mount | `ro` |
| `noatime` | Do not update access time | `noatime` |

## Activating the Binding

After binding, you must restage or restart the application to activate the binding:

```bash
cf restage my-app
```

This ensures the NFS volume is mounted within the application container.

## Accessing the NFS Share

Once mounted, the NFS share is accessible at:

```
/var/vcap/data/nfs/
```

### Example: Node.js Application

```javascript
const fs = require('fs');
const path = '/var/vcap/data/nfs/';

// Write a file to the NFS share
fs.writeFileSync(path + 'test.txt', 'Hello from NFS!');

// Read a file from the NFS share
const content = fs.readFileSync(path + 'test.txt', 'utf8');
console.log(content);
```

### Example: Java Application

```java
import java.nio.file.*;

public class NfsExample {
    public static void main(String[] args) throws Exception {
        Path nfsPath = Paths.get("/var/vcap/data/nfs/test.txt");
        
        // Write to the NFS share
        Files.write(nfsPath, "Hello from NFS!".getBytes());
        
        // Read from the NFS share
        String content = new String(Files.readAllBytes(nfsPath));
        System.out.println(content);
    }
}
```

### Example: Python Application

```python
nfs_path = "/var/vcap/data/nfs/test.txt"

# Write to the NFS share
with open(nfs_path, 'w') as f:
    f.write("Hello from NFS!")

# Read from the NFS share
with open(nfs_path, 'r') as f:
    content = f.read()
    print(content)
```

## Multiple NFS Shares

To mount multiple NFS shares, create and bind multiple service instances:

```bash
# Create first service instance
cf create-service nfs Existing nfs-share-1

# Create second service instance
cf create-service nfs Existing nfs-share-2

# Bind application to first share
cf bind-service my-app nfs-share-1 -c '{
  "share": "nfs1.example.com/export/path1"
}'

# Bind application to second share
cf bind-service my-app nfs-share-2 -c '{
  "share": "nfs2.example.com/export/path2"
}'

# Restage to apply both bindings
cf restage my-app
```

In this case, both shares will be mounted at `/var/vcap/data/nfs/` but in different subdirectories that are unique to each service binding.

## Unbinding

To unmount an NFS share, unbind the service and restage the application:

```bash
cf unbind-service my-app my-nfs-share
cf restage my-app
```

## Troubleshooting

### Common Binding Issues

#### Mount Failure

If the application fails to start after binding to an NFS share, check the application logs:

```bash
cf logs my-app --recent
```

Look for errors related to mounting the NFS share.

#### Permission Denied

If the application can't read or write to the NFS share:

1. Verify the `uid` and `gid` in the binding parameters
2. Check export permissions on the NFS server
3. Ensure the NFS server allows access from the Cloud Foundry cell IP addresses

#### Connection Timeout

If the application can't connect to the NFS server:

1. Verify network connectivity between Cloud Foundry cells and the NFS server
2. Check security groups allow traffic to the NFS server
3. Ensure the NFS server is running and accessible

#### Stale File Handles

If you see "stale file handle" errors:

1. Unbind the service
2. Rebind with the same parameters
3. Restage the application

### Validating NFS Access

You can create a simple test application to validate NFS access:

```bash
# Clone a simple test app
git clone https://github.com/cloudfoundry/nfs-volume-release.git
cd nfs-volume-release/src/persi_acceptance_tests/assets/pora

# Push the test app
cf push pora --no-start

# Create and bind NFS service
cf create-service nfs Existing test-nfs
cf bind-service pora test-nfs -c '{
  "share": "nfs-server.example.com/export/path"
}'

# Start the app
cf start pora

# Test writing to NFS
curl -k "https://pora.YOUR-CF-DOMAIN.com/write"

# Test reading from NFS
curl -k "https://pora.YOUR-CF-DOMAIN.com/read"
```

## Best Practices

1. **Mount Options**: Use appropriate NFS mount options for your workload
   - Increase `rsize` and `wsize` for better performance with large files
   - Use `noatime` to reduce write operations
   - Use `hard` mount option for reliability

2. **Error Handling**: Add error handling in your application for NFS operations
   - Handle "file not found" and permission errors
   - Implement retries for transient failures
   - Log NFS-related errors with sufficient detail

3. **Security**: Secure your NFS configuration
   - Use specific IP-based restrictions on the NFS server
   - Consider using Kerberos authentication (`sec=krb5p`) for sensitive data
   - Follow the principle of least privilege for file permissions

4. **Performance**: Optimize for your workload
   - Consider NFS caching behavior
   - Profile file access patterns
   - Monitor NFS performance and adjust parameters as needed

## Related Topics

- [Service Plans](service-plans.md) - Details about the service plans offered by the broker
- [Security Groups](security-groups.md) - Required security group configuration for NFS access
- [Developer Guide](developer-guide.md) - Comprehensive guide for application developers