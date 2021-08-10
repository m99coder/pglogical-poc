# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

build: ## Build containers.
	docker-compose build --force-rm --pull

start: ## Start containers.
	docker-compose up -d

wait: ## Wait for databases to be ready.
	timeout 90s bash -c "until docker exec pglogical-poc_pgprovider_1 pg_isready ; do sleep 5 ; done"
	timeout 90s bash -c "until docker exec pglogical-poc_pgsubscriber_1 pg_isready ; do sleep 5 ; done"

init: wait ## Init databases.
	docker exec -it pglogical-poc_pgprovider_1 \
		pgbench -U postgres -d pg_logical_replication -i
	docker exec -it pglogical-poc_pgsubscriber_1 \
		pgbench -U postgres -d pg_logical_replication_results -i

replicate: wait ## Run replication.
	docker exec -it pglogical-poc_pgprovider_1 \
		psql -U postgres -d pg_logical_replication -f /create-replication-set.sql
	docker exec -it pglogical-poc_pgsubscriber_1 \
		psql -U postgres -d pg_logical_replication_results -f /create-subscription.sql
	docker exec -it pglogical-poc_pgprovider_1 \
		pgbench -U postgres -d pg_logical_replication -c 10 -T 60 -r
	docker exec -it pglogical-poc_pgprovider_1 \
		psql -U postgres -d pg_logical_replication \
			-c 'SELECT COUNT(*) FROM pgbench_history WHERE tid = 1;'
	docker exec -it pglogical-poc_pgsubscriber_1 \
		psql -U postgres -d pg_logical_replication_results \
			-c 'SELECT COUNT(*) FROM pgbench_history WHERE tid = 1;'

run: start init replicate ## Start containers, init databases and run replication.

list: # List running containers.
	docker-compose ps

stop: ## Stop containers.
	docker-compose down

clean: ## Clean up containers.
	docker-compose rm --force --stop
