# Base de datos distribuida para reservaciones hoteleras (Cancún · Tulum · Bacalar)

Proyecto integrador de regularización · Bases de Datos · Ingeniería en Software (UPQROO)
Alumno: Alejandro Marron Palafox · Matrícula 202300141

## Arquitectura (Sprint 1)
Tres nodos PostgreSQL en Docker, uno por sede. Cada nodo guarda solo los datos de su sede
(fragmentación horizontal, forzada con `CHECK (sede_id = ...)`). Los IDs usan una secuencia
con rango propio por nodo (sede_id × 10⁹) para no chocar al consolidar.
El nodo central de reportes y los respaldos se agregan en el Sprint 3.

| Nodo    | Puerto | Habitaciones |
|---------|--------|--------------|
| Cancún  | 5433   | 300          |
| Tulum   | 5434   | 100          |
| Bacalar | 5435   | 60           |

## Puesta en marcha
```bash
cp .env.example .env
docker compose up -d                       # crea esquema y catálogos (sql/01 y sql/02)
pip install -r requirements.txt
python scripts/generar_datos.py --port 5433 --reservaciones 50000   # Cancún
python scripts/generar_datos.py --port 5434 --reservaciones 8000    # Tulum
python scripts/generar_datos.py --port 5435 --reservaciones 5000    # Bacalar
psql -h localhost -p 5433 -U hotel_admin -d hotel                   # contraseña: hotel_pass
```
Para reiniciar desde cero: `docker compose down -v`.

## Estructura
- `sql/01_schema.sql` esquema (herencia, tipos compuestos, arreglos, JSONB, exclusión)
- `sql/02_seed.sql` datos base
- `scripts/generar_datos.py` carga masiva con Faker
- `docs/` plan, backlog, bitácora de IA y evidencias
