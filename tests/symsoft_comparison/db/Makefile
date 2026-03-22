#! /usr/bin/make -f

ignore:=initdb.d/README.org

org:=$(wildcard initdb.d/*.org)
sql:=$(patsubst %.org,%.sql,$(filter-out ${ignore},${org}))

name:=localhost/dwr-spatial-cimis/symsoft-db
tag:=dirty

data_csv:=stats.csv

.PHONY: help data

help:  ## Show this help message.
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-.]+:.*## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' ${MAKEFILE_LIST}


data: ${data_csv} ## Warn if the data file is missing.
	@echo "Data file $< is present.  Ready to build the Docker image."


${data_csv}:
	rm -rf $@
	for i in ~/dwr-spatial-cimis/gdb/cimis/202401??_s/sqlite/sqlite.db; do  sqlite3 -csv $i 'select * from stats' | tee --append $@ ; done


build: tangle  ## Build Docker image with the tangled SQL files.
	docker buildx build -t ${name}:${tag} .

.PHONY:tangle
tangle:: ## Convert org-mode tangled files to their corresponding *.sql files.
tangle::${sql}

${sql}:%.sql:%.org ## Tangle %.org to %.sql
	emacs -Q --batch --eval "(progn (require 'ob-tangle)\
	    (dolist (file command-line-args-left)\
	      (with-current-buffer (find-file-noselect file)\
	        (org-babel-tangle))))" "$<"

.PHONY: clean
clean:  ## Remove all tangled SQL files, and the Docker image.
	rm -f ${sql}
	docker rmi ${name}:${tag} || true

.PHONY: server-net
server-net: ## Run a PostgreSQL container on a docker network 'symsoftnet'.
	docker run --rm -d --name symsoft -e POSTGRES_PASSWORD=symsoft ${name}:${tag}
	docker network create symsoftnet
	docker network connect symsoftnet symsoft

.PHONY: server
server: ## Run a PostgreSQL container on localhost port 5432.
	docker run --rm -p 5432:5432 -d --name symsoft -e POSTGRES_PASSWORD=symsoft ${name}:${tag}

.PHONY: stop
stop:  ## Stop the PostgreSQL container.
	docker stop symsoft || true

.PHONY: psql
psql:  ## Connect to the PostgreSQL container using psql.
	 docker run -it --rm --network symsoftnet ${name}:${tag} psql -h symsoft -U postgres
