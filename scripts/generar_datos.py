#!/usr/bin/env python3
"""Genera huéspedes y reservaciones sintéticos (Faker) para UNA sede y los carga con COPY.

Las reservaciones se construyen recorriendo la línea de tiempo de cada habitación,
de modo que nunca se traslapan (la restricción de exclusión las aceptará todas).

Uso:
    python scripts/generar_datos.py --port 5433 --reservaciones 50000
    python scripts/generar_datos.py --port 5434 --reservaciones 8000
    python scripts/generar_datos.py --port 5435 --reservaciones 5000
"""
import argparse
import json
import random
from datetime import date, timedelta

import psycopg
from faker import Faker

INICIO = date(2023, 1, 1)
FIN = date(2027, 12, 31)
CANALES = ["web", "mostrador", "telefono", "agencia"]


def literal_direccion(f: Faker, ciudad: str) -> str:
    """Valor de texto para el tipo compuesto hotel.direccion."""
    campos = [f.street_address(), f.city_suffix() + " " + f.last_name(), ciudad,
              "Quintana Roo", f.postcode(), "México"]
    return "(" + ",".join('"' + c.replace('"', '""') + '"' for c in campos) + ")"


def preferencias(f: Faker) -> str:
    pref = {"almohada": random.choice(["suave", "firme"]),
            "piso_alto": random.random() < 0.4,
            "no_fumar": random.random() < 0.85}
    if random.random() < 0.2:
        pref["dieta"] = random.choice(["vegetariana", "vegana", "sin_gluten"])
    return json.dumps(pref)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=5433)
    ap.add_argument("--user", default="hotel_admin")
    ap.add_argument("--password", default="hotel_pass")
    ap.add_argument("--dbname", default="hotel")
    ap.add_argument("--reservaciones", type=int, default=50000)
    ap.add_argument("--semilla", type=int, default=42, help="para resultados reproducibles")
    a = ap.parse_args()

    random.seed(a.semilla)
    f = Faker("es_MX")
    Faker.seed(a.semilla)

    with psycopg.connect(host=a.host, port=a.port, user=a.user, password=a.password,
                         dbname=a.dbname) as conn:
        cur = conn.cursor()
        sede_id, ciudad = cur.execute("SELECT id, nombre FROM hotel.sede").fetchone()
        habitaciones = [r[0] for r in cur.execute("SELECT id FROM hotel.habitacion").fetchall()]
        print(f"Sede {ciudad}: {len(habitaciones)} habitaciones")

        # ---------------- huéspedes ----------------
        n_hues = max(200, a.reservaciones // 4)
        n_corp = n_hues // 5
        n_ind = n_hues - n_corp
        ids = [r[0] for r in cur.execute(
            "SELECT nextval('hotel.id_seq') FROM generate_series(1, %s)", (n_hues,)).fetchall()]
        ids_ind, ids_corp = ids[:n_ind], ids[n_ind:]

        with cur.copy("COPY hotel.huesped_individual (id, nombre, email, telefono, direccion,"
                      " preferencias, curp, fecha_nacimiento) FROM STDIN") as cp:
            for i in ids_ind:
                cp.write_row((i, f.name(), f.email(), f.phone_number(), literal_direccion(f, ciudad),
                              preferencias(f), f.bothify("????######??????##").upper(),
                              f.date_of_birth(minimum_age=18, maximum_age=85)))
        with cur.copy("COPY hotel.huesped_corporativo (id, nombre, email, telefono, direccion,"
                      " preferencias, razon_social, rfc, limite_credito) FROM STDIN") as cp:
            for i in ids_corp:
                emp = f.company()
                cp.write_row((i, emp, f.company_email(), f.phone_number(),
                              literal_direccion(f, ciudad), preferencias(f), emp + " S.A. de C.V.",
                              f.bothify("???######???").upper(), random.choice([50000, 100000, 250000])))
        print(f"Huéspedes: {n_ind} individuales + {n_corp} corporativos")
        # Sin estadísticas, el trigger de validación (que consulta huesped/habitacion)
        # usa planes pésimos y la carga se cuelga: se analiza antes de insertar reservaciones.
        conn.commit()
        cur.execute("ANALYZE")

        # ---------------- reservaciones (sin traslapes) ----------------
        hoy = date.today()
        cursor_hab = {h: INICIO + timedelta(days=random.randint(0, 5)) for h in habitaciones}
        filas = []
        activas = list(habitaciones)
        while len(filas) < a.reservaciones and activas:
            h = random.choice(activas)
            noches = random.choices(range(1, 11), weights=[10, 25, 25, 15, 10, 6, 4, 2, 2, 1])[0]
            entrada = cursor_hab[h]
            salida = entrada + timedelta(days=noches)
            if salida > FIN:
                activas.remove(h)
                continue
            cursor_hab[h] = salida + timedelta(days=random.randint(0, 3))
            if salida <= hoy:
                estado = "checkout"
            elif entrada <= hoy:
                estado = "checkin"
            else:
                estado = "confirmada"
            if estado != "checkin" and random.random() < 0.08:
                estado = "cancelada"
            filas.append((h, random.choice(ids), f"[{entrada},{salida})", estado,
                          random.choice(CANALES)))
        if len(filas) < a.reservaciones:
            print(f"AVISO: solo se pudieron generar {len(filas)} reservaciones sin traslape")

        with cur.copy("COPY hotel.reservacion (habitacion_id, huesped_id, estancia, estado, canal)"
                      " FROM STDIN") as cp:
            for fila in filas:
                cp.write_row(fila)
        print(f"Reservaciones cargadas: {len(filas)}")

        # IMPORTANTE: sin estadísticas el planificador elige un mal plan y el UPDATE
        # de abajo puede tardar minutos. Se analiza ANTES de calcular los totales.
        conn.commit()
        cur.execute("ANALYZE")
        # totales con la función de la BD (noches × tarifa × temporada)
        cur.execute("UPDATE hotel.reservacion SET total = hotel.calcular_total(habitacion_id, estancia)")
        conn.commit()
        cur.execute("ANALYZE")
        print("Totales calculados y estadísticas actualizadas (ANALYZE).")


if __name__ == "__main__":
    main()
