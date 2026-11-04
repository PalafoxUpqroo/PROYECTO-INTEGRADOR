#!/bin/bash
# Se ejecuta una sola vez, al crear el contenedor (carpeta docker-entrypoint-initdb.d)
set -e
psql -v ON_ERROR_STOP=1 \
     -v sede_id="${SEDE_ID}" \
     -v sede_nombre="${SEDE_NOMBRE}" \
     -v n_hab="${N_HAB}" \
     -v precio_estandar="${PRECIO_ESTANDAR}" \
     -v precio_suite="${PRECIO_SUITE}" \
     -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
     -f /sql/01_schema.sql -f /sql/02_seed.sql
