-- =====================================================================
-- 02_seed.sql · Datos base de una sede (DML)
-- Variables: sede_id, sede_nombre, n_hab, precio_estandar, precio_suite
-- Los precios y cantidades son datos de ejemplo (ficticios) del proyecto.
-- =====================================================================
\set ON_ERROR_STOP on
SET search_path = hotel, public;

INSERT INTO sede (id, nombre, direccion)
VALUES (:sede_id, :'sede_nombre',
        ROW(NULL, NULL, :'sede_nombre', 'Quintana Roo', NULL, 'México')::direccion);

INSERT INTO tarifa (tipo, precio_base) VALUES
    ('estandar', :precio_estandar),
    ('suite',    :precio_suite);

-- Temporadas ficticias 2023-2027 (el factor multiplica la tarifa base)
INSERT INTO temporada (nombre, vigencia, factor)
SELECT 'Alta Navidad', daterange(make_date(y,12,15), make_date(y+1,1,7), '[)'), 1.50
FROM generate_series(2023, 2027) y;

INSERT INTO temporada (nombre, vigencia, factor)
SELECT 'Alta Verano', daterange(make_date(y,7,1), make_date(y,8,16), '[)'), 1.30
FROM generate_series(2023, 2027) y;

INSERT INTO servicio (nombre, precio) VALUES
    ('Desayuno buffet', 250), ('Spa',  900), ('Lavandería', 150),
    ('Traslado aeropuerto', 600), ('Minibar', 200), ('Tour guiado', 1200);

-- Habitaciones: 20 por piso; cada 5.ª es suite
INSERT INTO habitacion_estandar (numero, piso, capacidad, amenidades, tipo_cama)
SELECT ((i-1)/20 + 1) * 100 + ((i-1) % 20) + 1,
       ((i-1)/20 + 1),
       CASE WHEN i % 2 = 0 THEN 2 ELSE 3 END,
       CASE WHEN i % 3 = 0 THEN ARRAY['wifi','tv','aire_acondicionado','balcon']
                           ELSE ARRAY['wifi','tv','aire_acondicionado'] END,
       (ARRAY['queen','matrimonial','dos_camas','individual'])[1 + i % 4]
FROM generate_series(1, :n_hab) i
WHERE i % 5 <> 0;

INSERT INTO habitacion_suite (numero, piso, capacidad, amenidades, recamaras, tiene_jacuzzi, vista)
SELECT ((i-1)/20 + 1) * 100 + ((i-1) % 20) + 1,
       ((i-1)/20 + 1),
       4,
       ARRAY['wifi','tv','aire_acondicionado','minibar','cafetera','vista_panoramica'],
       1 + i % 3,
       i % 2 = 0,
       (ARRAY['mar','jardin','alberca'])[1 + i % 3]
FROM generate_series(1, :n_hab) i
WHERE i % 5 = 0;
