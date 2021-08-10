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

replicate: ## Run replication.
	timeout 90s bash -c "until docker exec pglogical-poc_pgprovider_1 pg_isready ; do sleep 5 ; done"
	timeout 90s bash -c "until docker exec pglogical-poc_pgsubscriber_1 pg_isready ; do sleep 5 ; done"
	docker exec -it pglogical-poc_pgprovider_1 \
		psql -U postgres -d pg_logical_replication -f /replication.sql
	docker exec -it pglogical-poc_pgsubscriber_1 \
		psql -U postgres -d pg_logical_replication_results -f /replication.sql
	docker exec -it pglogical-poc_pgprovider_1 \
		psql -U postgres -d pg_logical_replication \
			-c 'INSERT INTO posts (SELECT generate_series(1001, 2000), FLOOR(random()*50)+1);'
	docker exec -it pglogical-poc_pgprovider_1 \
		psql -U postgres -d pg_logical_replication \
			-c 'INSERT INTO comments (SELECT generate_series(201, 400), FLOOR(random()*1000)+1, 1, (ROUND(random())::int)::boolean);'
	docker exec -it pglogical-poc_pgprovider_1 \
		psql -U postgres -d pg_logical_replication \
			-c 'UPDATE comments SET user_id = subquery.user_id FROM (SELECT posts.user_id, comments.id FROM posts INNER JOIN comments ON posts.id = comments.post_id) AS subquery WHERE comments.id = subquery.id;'

run: start replicate ## Start containers and run replication.

list: # List running containers.
	docker-compose ps

stop: ## Stop containers.
	docker-compose down

clean: ## Clean up containers.
	docker-compose rm --force --stop
