-- =====================================================================
-- 01_schema.sql  ·  Esquema de una SEDE (se aplica en cada nodo)
-- Variables psql requeridas: sede_id, sede_nombre
-- Cada nodo guarda SOLO los datos de su sede (fragmentación horizontal),
-- garantizado con CHECK (sede_id = :sede_id).
-- =====================================================================
\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS btree_gist;   -- permite "=" y "&&" juntos en un índice GiST
CREATE SCHEMA IF NOT EXISTS hotel;
SET search_path = hotel, public;

SELECT format('ALTER DATABASE %I SET search_path = hotel, public', current_database()) \gexec

-- Una sola secuencia por nodo, con rango propio (sede_id * 1 000 000 000).
-- Así los IDs de Cancún, Tulum y Bacalar jamás chocan al consolidarlos en el nodo central.
SELECT format('CREATE SEQUENCE hotel.id_seq START %s', (:sede_id)::bigint * 1000000000) \gexec

-- ---------------------------------------------------------------------
-- Tipos compuestos (Unidad II)
-- ---------------------------------------------------------------------
CREATE TYPE direccion AS (
    calle   text,
    colonia text,
    ciudad  text,
    estado  text,
    cp      text,
    pais    text
);

-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------
CREATE TABLE sede (
    id        smallint PRIMARY KEY,
    nombre    text NOT NULL UNIQUE,
    direccion direccion
);

CREATE TABLE tarifa (
    id          bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    sede_id     smallint NOT NULL DEFAULT :sede_id CHECK (sede_id = :sede_id) REFERENCES sede(id),
    tipo        text NOT NULL CHECK (tipo IN ('estandar','suite')),
    precio_base numeric(10,2) NOT NULL CHECK (precio_base > 0),
    UNIQUE (sede_id, tipo)
);

CREATE TABLE temporada (
    id       bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    sede_id  smallint NOT NULL DEFAULT :sede_id CHECK (sede_id = :sede_id) REFERENCES sede(id),
    nombre   text NOT NULL,
    vigencia daterange NOT NULL,
    factor   numeric(4,2) NOT NULL CHECK (factor > 0),
    -- dos temporadas de una misma sede no pueden traslaparse
    CONSTRAINT temporada_sin_traslape EXCLUDE USING gist (sede_id WITH =, vigencia WITH &&)
);

CREATE TABLE servicio (
    id     bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    nombre text NOT NULL UNIQUE,
    precio numeric(10,2) NOT NULL CHECK (precio >= 0)
);

-- ---------------------------------------------------------------------
-- HERENCIA 1: huésped individual / corporativo (INHERITS)
-- ---------------------------------------------------------------------
CREATE TABLE huesped (
    id           bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    tipo         text NOT NULL CHECK (tipo IN ('individual','corporativo')),
    nombre       text NOT NULL,
    email        text,
    telefono     text,
    direccion    direccion,                              -- tipo compuesto
    preferencias jsonb NOT NULL DEFAULT '{}'::jsonb,     -- JSONB
    creado       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE huesped_individual (
    PRIMARY KEY (id),                                    -- la PK NO se hereda: se redefine
    tipo             text NOT NULL DEFAULT 'individual' CHECK (tipo = 'individual'),
    curp             text,
    fecha_nacimiento date
) INHERITS (huesped);

CREATE TABLE huesped_corporativo (
    PRIMARY KEY (id),
    tipo           text NOT NULL DEFAULT 'corporativo' CHECK (tipo = 'corporativo'),
    razon_social   text NOT NULL,
    rfc            text,
    limite_credito numeric(12,2) NOT NULL DEFAULT 0
) INHERITS (huesped);

-- ---------------------------------------------------------------------
-- HERENCIA 2: habitación estándar / suite (INHERITS) + arreglo de amenidades
-- ---------------------------------------------------------------------
CREATE TABLE habitacion (
    id         bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    sede_id    smallint NOT NULL DEFAULT :sede_id CHECK (sede_id = :sede_id),
    tipo       text NOT NULL CHECK (tipo IN ('estandar','suite')),
    numero     text NOT NULL,
    piso       smallint NOT NULL,
    capacidad  smallint NOT NULL CHECK (capacidad > 0),
    amenidades text[] NOT NULL DEFAULT '{}',             -- arreglo
    estado     text NOT NULL DEFAULT 'disponible'
               CHECK (estado IN ('disponible','mantenimiento','fuera_servicio'))
);

CREATE TABLE habitacion_estandar (
    PRIMARY KEY (id),
    UNIQUE (numero),
    tipo      text NOT NULL DEFAULT 'estandar' CHECK (tipo = 'estandar'),
    tipo_cama text NOT NULL DEFAULT 'queen' CHECK (tipo_cama IN ('individual','matrimonial','queen','dos_camas'))
) INHERITS (habitacion);

CREATE TABLE habitacion_suite (
    PRIMARY KEY (id),
    UNIQUE (numero),
    tipo         text NOT NULL DEFAULT 'suite' CHECK (tipo = 'suite'),
    recamaras    smallint NOT NULL DEFAULT 1 CHECK (recamaras > 0),
    tiene_jacuzzi boolean NOT NULL DEFAULT false,
    vista        text
) INHERITS (habitacion);

-- ---------------------------------------------------------------------
-- Reservaciones: rango de fechas + restricción de exclusión anti-sobreventa
-- ---------------------------------------------------------------------
CREATE TABLE reservacion (
    id            bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    sede_id       smallint NOT NULL DEFAULT :sede_id CHECK (sede_id = :sede_id) REFERENCES sede(id),
    huesped_id    bigint NOT NULL,        -- sin FK (ver trigger: las FK no "ven" las tablas hijas)
    habitacion_id bigint NOT NULL,        -- sin FK por la misma razón
    estancia      daterange NOT NULL
                  CHECK (NOT isempty(estancia) AND NOT lower_inf(estancia) AND NOT upper_inf(estancia)),
    estado        text NOT NULL DEFAULT 'confirmada'
                  CHECK (estado IN ('confirmada','checkin','checkout','cancelada')),
    canal         text NOT NULL DEFAULT 'web' CHECK (canal IN ('web','mostrador','telefono','agencia')),
    total         numeric(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    creado        timestamptz NOT NULL DEFAULT now(),
    -- NO PUEDEN existir dos reservaciones activas de la misma habitación con fechas que se traslapen
    CONSTRAINT reservacion_sin_traslape
        EXCLUDE USING gist (habitacion_id WITH =, estancia WITH &&)
        WHERE (estado <> 'cancelada')
);

CREATE TABLE pago (
    id             bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    reservacion_id bigint NOT NULL REFERENCES reservacion(id) ON DELETE CASCADE,
    monto          numeric(12,2) NOT NULL CHECK (monto > 0),
    metodo         text NOT NULL CHECK (metodo IN ('efectivo','tarjeta','transferencia')),
    fecha          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE servicio_consumido (
    id             bigint PRIMARY KEY DEFAULT nextval('hotel.id_seq'),
    reservacion_id bigint NOT NULL REFERENCES reservacion(id) ON DELETE CASCADE,
    servicio_id    bigint NOT NULL REFERENCES servicio(id),
    cantidad       integer NOT NULL DEFAULT 1 CHECK (cantidad > 0),
    fecha          timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Integridad referencial con herencia.
-- Una FK apunta solo a la tabla padre, NO a sus hijas, así que un huésped o
-- habitación guardado en huesped_individual / habitacion_suite "no existiría"
-- para la FK. Solución: trigger que consulta el padre (que sí incluye hijas).
-- ---------------------------------------------------------------------
CREATE FUNCTION valida_referencias_reservacion() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM hotel.huesped WHERE id = NEW.huesped_id) THEN
        RAISE EXCEPTION 'El huésped % no existe', NEW.huesped_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM hotel.habitacion WHERE id = NEW.habitacion_id) THEN
        RAISE EXCEPTION 'La habitación % no existe', NEW.habitacion_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_reservacion_valida_refs
    BEFORE INSERT OR UPDATE OF huesped_id, habitacion_id ON reservacion
    FOR EACH ROW EXECUTE FUNCTION valida_referencias_reservacion();

-- ---------------------------------------------------------------------
-- Cálculo de total: noches × tarifa del tipo de habitación × factor de temporada
-- (la reutilizará la función reservar() del Sprint 2)
-- ---------------------------------------------------------------------
CREATE FUNCTION calcular_total(p_habitacion bigint, p_estancia daterange) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(
               tf.precio_base * COALESCE(
                   (SELECT s.factor FROM hotel.temporada s WHERE s.vigencia @> d::date), 1)
           ), 0)::numeric(12,2)
    FROM hotel.habitacion h
    JOIN hotel.tarifa tf ON tf.tipo = h.tipo
    CROSS JOIN generate_series(lower(p_estancia), upper(p_estancia) - 1, interval '1 day') AS d
    WHERE h.id = p_habitacion
$$;
