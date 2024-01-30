#!/usr/bin/env bash

set -v

POSTGRESQL_TARGET_ID=ttcp_Cqwd4v3Na6

boundary authenticate oidc

boundary connect postgres -target-id $POSTGRESQL_TARGET_ID -dbname northwind

# List tables in current schema
# select * from pg_catalog.pg_tables limit 10;
