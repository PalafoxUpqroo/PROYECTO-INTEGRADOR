# Bitácora de IA (anexo obligatorio: 8 a 10 interacciones relevantes)
Formato: fecha · herramienta · solicitud · resultado · qué se aceptó/corrigió/descartó y por qué · verificación

## 1. 2026-11-04 · Claude
- **Solicitud:** diseño del esquema distribuido y carga de datos (Sprint 1).
- **Resultado:** `01_schema.sql`, `02_seed.sql`, docker-compose y `generar_datos.py`.
- **Corregido:** la carga se colgaba en una base nueva por falta de estadísticas; se añadió `ANALYZE` antes del trigger de validación y antes del UPDATE de totales.
- **Verificación:** ejecución sobre PostgreSQL 16 limpio: 50 000 reservaciones en ~8 s; un traslape y un huésped inexistente son rechazados.
- **Pendiente tuyo:** repetir la verificación en tus contenedores y anotar aquí lo que cambies.
