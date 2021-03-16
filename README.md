# pglogical-poc

> Replicate from PostgreSQL 11.5 to 11.10 using pglogical 2.2.2

## Setup

In this PoC we logically replicate from a PostgreSQL 11.5 to a PostgreSQL 11.10. Both instances running in Docker containers and communicating with each other. Both have pglogical 2.2.2 installed.

```bash
# start containers
docker-compose up -d

# in case we need to rebuilt the images use
docker-compose up -d --build

# running services
docker-compose ps

# stop containers
docker-compose down --rmi all
```

## Resources

- [PostgreSQL and the logical replication](https://blog.raveland.org/post/postgresql_lr_en/)
- [PostgreSQL replication with Docker](https://medium.com/swlh/postgresql-replication-with-docker-c6a904becf77)
- [Dockerfile](https://gist.github.com/asaaki/b07dccfd6ff6eed4c7b4ef279ade7b0c)
- [docker-pglogical](https://github.com/reediculous456/docker-pglogical/blob/master/Dockerfile)
- [Demystifying pglogical](http://thedumbtechguy.blogspot.com/2017/04/demystifying-pglogical-tutorial.html)
- [Short tutorial to setup replication using pglogical](https://gist.github.com/ratnakri/c22a7389d9fab788d7b8b12e2a6c337a)
- [How to configure pglogical](https://www.tutorialdba.com/2018/01/how-to-configure-pglogical-streaming.html)
- [PostgreSQL – logical replication with pglogical](https://blog.dbi-services.com/postgresql-logical-replication-with-pglogical/)
- [PG Phriday: Perfectly Logical](http://bonesmoses.org/2016/10/14/pg-phriday-perfectly-logical/)
