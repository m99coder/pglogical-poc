# Docker Compose Network

When using `docker-compose up` the default network `pglogical-poc` is created with a specific IP subnet so that the containers, that are part of the network can communicate with each other using the hosts defined in `docker-compose.yaml`. In this PoC: `pgprovider` and `pgsubscriber`.

```bash
docker network inspect -v pglogical-poc_default
[
    {
        "Name": "pglogical-poc_default",
        "Id": "e87fe5b2467709b77a487e80a9a8a48bc468bad39e0ef209be3fdb26643f92ce",
        "Created": "2021-03-16T16:11:31.4978917Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "192.168.144.0/20",
                    "Gateway": "192.168.144.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": true,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "80ae5b2beb40ada3120ba98e3dc76d15cadb9f0fa0187c015b4ae60d2e3e791a": {
                "Name": "pglogical-poc-pgsubscriber-1",
                "EndpointID": "592114feb099a1d10d2cc5d7731506c0aa4b02e039431646b3ed3f050e5bf802",
                "MacAddress": "02:42:c0:a8:90:03",
                "IPv4Address": "192.168.144.3/20",
                "IPv6Address": ""
            },
            "b59e6fbe72657a6d32fc6f9ea33c58c718c259999683bd0c2d77a5781e81c949": {
                "Name": "pglogical-poc-pgprovider-1",
                "EndpointID": "42d00c26782cacf672113d320ffc61b4e237e65adfa48b5f590a74df16a5b62d",
                "MacAddress": "02:42:c0:a8:90:02",
                "IPv4Address": "192.168.144.2/20",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {
            "com.docker.compose.network": "default",
            "com.docker.compose.project": "pglogical-poc",
            "com.docker.compose.version": "1.28.5"
        }
    }
]
```

```bash
# get running processes
docker ps --format 'table {{.ID}}\t{{.Names}}'
CONTAINER ID   NAMES
80ae5b2beb40   pglogical-poc-pgsubscriber-1
b59e6fbe7265   pglogical-poc-pgprovider-1

# get hosts from pgprovider
docker exec pglogical-poc-pgprovider-1 cat /etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
192.168.144.2	b59e6fbe7265

# get hosts from pgsubscriber
docker exec pglogical-poc-pgsubscriber-1 cat /etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
192.168.144.3	80ae5b2beb40
```

```bash
# connect to other psql instance using host
docker exec -it pglogical-poc-pgprovider-1 /bin/bash
root@b59e6fbe7265:/# psql -h pgsubscriber -U replicate pg_logical_replication_results
psql (11.5 (Debian 11.5-3.pgdg90+1), server 11.10 (Debian 11.10-1.pgdg90+1))
Type "help" for help.

pg_logical_replication_results=> \l
 pg_logical_replication_results | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres                       | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0                      | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
                                |          |          |            |            | postgres=CTc/postgres
 template1                      | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
                                |          |          |            |            | postgres=CTc/postgres
pg_logical_replication_results=> exit
root@b59e6fbe7265:/# exit
exit
```
