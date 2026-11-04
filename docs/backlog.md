# Product backlog (copiar cada historia como Issue en GitHub Projects)

| ID | Historia de usuario | Criterios de aceptación | Sprint |
|---|---|---|---|
| HU-01 | Como gerente quiero un modelo relacional normalizado para tener datos consistentes | Existen huéspedes, habitaciones, tarifas, temporadas, reservaciones, pagos y servicios con PK/FK/CHECK | 1 |
| HU-02 | Como desarrollador quiero herencia, tipos compuestos, arreglos y JSONB para modelar tipos de huésped y habitación | INHERITS en huésped y habitación; tipo `direccion`; `amenidades text[]`; `preferencias jsonb` | 1 |
| HU-03 | Como DBA quiero 50 000 reservaciones de prueba | Generador reproducible; carga ≥ 50 000 sin traslapes | 1 |
| HU-04 | Como recepcionista quiero ver disponibilidad y ocupación | Vistas que devuelven habitaciones libres por rango y % de ocupación por sede | 2 |
| HU-05 | Como DBA quiero consultas rápidas | EXPLAIN ANALYZE antes/después con índices B-tree y GiST documentado | 2 |
| HU-06 | Como recepcionista quiero reservar, hacer check-in/out y cancelar | Funciones PL/pgSQL; rechazan estados inválidos | 2 |
| HU-07 | Como auditor quiero bitácora y totales automáticos | Triggers registran cambios y recalculan total | 2 |
| HU-08 | Como gerente quiero cero sobreventa | Restricción de exclusión; error ante traslape | 2 |
| HU-09 | Como gerente quiero que dos canales no reserven la misma habitación a la vez | Script con hilos: exactamente 1 éxito, el resto rechazado | 3 |
| HU-10 | Como DBA quiero respaldos y recuperación a un punto en el tiempo | pg_basebackup + WAL archivado; restauración a hora indicada verificada | 3 |
| HU-11 | Como dirección quiero ocupación consolidada | Nodo central con replicación lógica y partición por sede | 3 |
| HU-12 | Como analista quiero consultar las 3 sedes juntas | postgres_fdw con consulta distribuida | 3 |
| HU-13 | Como recepcionista quiero mover una reservación entre sedes | Transacción en dos fases: o se mueve completa o no se mueve | 3 |
| HU-14 | Como usuario quiero un cliente sencillo | Script Python con menú que demuestra HU-06, 08, 09, 12 | 4 |
| HU-15 | Como alumno entrego documentación completa | PDF con estructura pedida, manuales, bitácora IA, referencias IEEE | 4 |
