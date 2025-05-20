# NFS Broker Architecture Overview

This document provides a detailed explanation of the NFS Broker architecture, its components, and how they interact with Cloud Foundry and external NFS infrastructure.

## System Overview

The NFS Broker Genesis Kit deploys a standalone service broker that enables Cloud Foundry applications to mount existing NFS volumes. It serves as a bridge between Cloud Foundry's volume services feature and external NFS infrastructure.

### Key Components

1. **NFS Broker Service**: The core broker component that implements the Open Service Broker API
2. **Route Registrar**: Registers routes with Cloud Foundry's routing tier
3. **Broker Registrar**: Handles registration with the Cloud Foundry Cloud Controller

### Architecture Diagram

```
+------------------------------------------------------------------------------+
|                                                                              |
|                              Cloud Foundry                                   |
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

## Component Details

### NFS Broker Service

The NFS Broker service implements the [Open Service Broker API](https://github.com/openservicebrokerapi/servicebroker/blob/master/spec.md), providing the following endpoints:

- `GET /v2/catalog`: Lists available service offerings
- `PUT /v2/service_instances/:id`: Creates a service instance
- `DELETE /v2/service_instances/:id`: Deletes a service instance
- `PUT /v2/service_instances/:id/service_bindings/:binding_id`: Binds an application to a service instance
- `DELETE /v2/service_instances/:id/service_bindings/:binding_id`: Unbinds an application from a service instance

The broker doesn't connect to the NFS server directly. Instead, it stores binding configurations that Cloud Foundry's volume driver uses to mount NFS shares.

### Route Registrar

The Route Registrar component registers the broker's HTTP routes with Cloud Foundry's routing tier, making the broker accessible at a consistent URL (typically `nfs-broker.<system-domain>`). It:

- Consumes the NATS message bus from the Cloud Foundry deployment
- Advertises the broker's routes to the GoRouter
- Maintains registration through regular heartbeats

### Broker Registrar

The Broker Registrar handles registration with the Cloud Foundry Cloud Controller during deployment. It:

- Connects to the Cloud Foundry API
- Authenticates using admin credentials
- Registers the broker with its URL, name, and credentials

## Service Configuration

The NFS Broker offers a single service with a single plan:

| Service Name | Service ID | Plan Name | Plan ID | Description |
|--------------|------------|-----------|---------|-------------|
| nfs | nfs-service-guid | Existing | Existing | A preexisting filesystem |

This configuration allows applications to mount existing NFS shares without the broker provisioning new infrastructure.

## Data Flow

### Service Instance Creation

1. A user creates a service instance with `cf create-service nfs Existing my-nfs`
2. Cloud Controller sends a provision request to the broker
3. The broker records the service instance in its state store (on persistent disk)
4. No actual NFS resources are provisioned at this stage

### Service Binding

1. A user binds an application to the service instance with binding parameters
2. Cloud Controller sends a bind request to the broker with the parameters
3. The broker validates the parameters and stores the binding information
4. Cloud Foundry's volume driver, on application staging/restaging:
   - Retrieves the binding information from the broker
   - Uses it to mount the specified NFS share into the application container

### Communication Paths

1. **CF Cloud Controller ↔ NFS Broker**: HTTP/HTTPS for broker API calls
2. **CF Router ↔ NFS Broker**: HTTP/HTTPS for routing traffic to the broker
3. **CF NATS ↔ Route Registrar**: TCP for route registration
4. **CF Applications ↔ NFS Servers**: NFS protocol (TCP/UDP ports 111, 2049, etc.)

## State Management

The NFS Broker maintains state on a persistent disk attached to the VM. This state includes:

- Service instance records
- Service binding configurations
- Broker authentication credentials

The broker does not store any NFS data; it only maintains metadata about service instances and bindings.

## Security Considerations

### Authentication

1. **Broker Authentication**: The broker authenticates with basic authentication (username/password)
2. **CF Authentication**: The broker uses CF admin credentials to register with Cloud Foundry
3. **Volume Driver Authentication**: The volume driver communicates with the broker using the broker's credentials

### Authorization

1. **Service Access**: CF administrators control service visibility via `cf enable-service-access`
2. **NFS Access**: NFS servers control access through export permissions and IP restrictions

### Network Security

1. **CF to Broker**: Controlled by CF networking (routes)
2. **CF to NFS**: Controlled by CF security groups
3. **Broker to NFS**: No direct communication (broker doesn't connect to NFS servers)

## Alternative Architectures

The standalone NFS Broker has advantages and disadvantages compared to alternative deployment models:

### Standalone Broker (This Genesis Kit)

**Advantages:**
- Simple deployment and management
- No external database dependency
- Standalone security boundary

**Disadvantages:**
- Single point of failure
- Limited scalability

### CF Application Broker with Database

**Advantages:**
- High availability
- Scaling with CF application instances
- Integrated with CF lifecycles

**Disadvantages:**
- Requires database service
- More complex configuration
- State management across instances

## Integration Points

### BOSH Integration

The kit integrates with BOSH for:
- VM lifecycle management
- Persistent disk for state storage
- Job configuration and monitoring

### Cloud Foundry Integration

The kit integrates with Cloud Foundry via:
- Service Broker API
- Route registration
- NATS message bus
- Volume Services

## Related Documentation

- [NFS Volume Release](https://github.com/cloudfoundry/nfs-volume-release)
- [Cloud Foundry Volume Services](https://docs.cloudfoundry.org/devguide/services/using-vol-services.html)
- [Open Service Broker API](https://github.com/openservicebrokerapi/servicebroker/blob/master/spec.md)