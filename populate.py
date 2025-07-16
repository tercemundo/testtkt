import sqlite3
import random
from datetime import datetime, timedelta
import hashlib

# Importamos las funciones de base de datos
import database as db 

# --- Generación de datos sintéticos ---
def generate_synthetic_data():
    """Genera datos sintéticos para técnicos, clientes y tickets."""

    # --- Generar Técnicos ---
    print("Generando 10 técnicos...")
    tecnicos_data = []
    for i in range(1, 11):
        nombre = f"Tecnico{i}"
        apellido = chr(65 + (i % 26)) # Letras A-Z para apellidos
        email = f"tecnico{i}@ejemplo.com"
        login = f"login_tec{i}"
        password_hash = hashlib.sha256("password123".encode()).hexdigest() # Contraseña simple y NO segura
        telefono = f"+34 600 000 {i:03d}"
        especialidad = random.choice(["Redes", "Sistemas", "Bases de Datos", "Seguridad", "Soporte"])
        fecha_ingreso = (datetime.now() - timedelta(days=random.randint(365, 365*5))).strftime("%Y-%m-%d")
        
        tecnicos_data.append({
            "nombre": nombre, "apellido": apellido, "email": email, "login": login,
            "password_hash": password_hash, "telefono": telefono, "especialidad": especialidad, "fecha_ingreso": fecha_ingreso
        })
    print("  -> Técnicos generados.")

    # --- Generar Clientes ---
    print("Generando 20 clientes...")
    clientes_data = []
    for i in range(1, 21):
        nombre_empresa = f"Empresa Cliente {i}"
        contacto_principal = f"Contacto {chr(65 + (i % 26))} {chr(66 + ((i+1) % 26))}"
        email = f"contacto{i}@empresa{i}.com"
        telefono = f"+34 910 000 {i:03d}"
        direccion = f"Calle Ficticia {i}, Piso {random.randint(1, 10)}"
        ciudad = random.choice(["Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao", "Zaragoza", "Málaga", "Murcia", "Palma", "Las Palmas"])
        pais = "España"
        
        clientes_data.append({
            "nombre_empresa": nombre_empresa, "contacto_principal": contacto_principal, "email": email,
            "telefono": telefono, "direccion": direccion, "ciudad": ciudad, "pais": pais
        })
    print("  -> Clientes generados.")

    # --- Obtener IDs de catálogos ---
    # Estas consultas se hacen después de que initialize_database haya intentado crear las tablas
    # y las inserciones maestras hayan tenido lugar.
    print("Obteniendo IDs de catálogos...")
    tecnico_ids, cliente_ids, tipo_tarea_ids, prioridad_ids, estado_ids = [], [], [], [], []
    estados_finales_ids_actuales = [] # Inicializar la lista para la lógica de fecha de cierre

    conn = db.get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            
            print("  - Obteniendo IDs de técnicos...")
            cursor.execute("SELECT id_tecnico FROM tecnicos")
            tecnico_ids = [row[0] for row in cursor.fetchall()]
            print(f"    Encontrados {len(tecnico_ids)} técnicos.")
            
            print("  - Obteniendo IDs de clientes...")
            cursor.execute("SELECT id_cliente FROM clientes")
            cliente_ids = [row[0] for row in cursor.fetchall()]
            print(f"    Encontrados {len(cliente_ids)} clientes.")

            print("  - Obteniendo IDs de tipos de tarea...")
            cursor.execute("SELECT id_tipo_tarea FROM tipos_tarea")
            tipo_tarea_ids = [row[0] for row in cursor.fetchall()]
            print(f"    Encontrados {len(tipo_tarea_ids)} tipos de tarea.")

            print("  - Obteniendo IDs de prioridades...")
            cursor.execute("SELECT id_prioridad FROM prioridades")
            prioridad_ids = [row[0] for row in cursor.fetchall()]
            print(f"    Encontrados {len(prioridad_ids)} prioridades.")

            print("  - Obteniendo IDs de estados de ticket...")
            cursor.execute("SELECT id_estado FROM estados_ticket")
            estado_ids = [row[0] for row in cursor.fetchall()]
            print(f"    Encontrados {len(estado_ids)} estados de ticket.")
            
            # Obtener IDs de estados finales para la lógica de fecha de cierre
            print("  - Obteniendo IDs de estados finales...")
            cursor.execute("SELECT id_estado FROM estados_ticket WHERE es_final = 1")
            estados_finales_ids_actuales = [row[0] for row in cursor.fetchall()]
            print(f"    Encontrados {len(estados_finales_ids_actuales)} estados finales.")
            
        except sqlite3.Error as e:
            print(f"ERROR obteniendo IDs de catálogos: {e}")
            return None, None, None # Indicar fallo
        finally:
            conn.close()
    else:
        print("ERROR: No se pudo obtener la conexión a la DB para obtener IDs de catálogos.")
        return None, None, None # Indicar fallo

    # --- Verificación crucial: Si alguna lista de IDs está vacía, significa que la inserción maestra falló ---
    if not (tecnico_ids and cliente_ids and tipo_tarea_ids and prioridad_ids and estado_ids):
        print("Error crítico: Faltan datos maestros después de intentar obtener IDs.")
        print("Esto generalmente significa que la función `insert_master_data_if_empty` en database.py no insertó los datos correctamente.")
        print("Revisa los mensajes de error anteriores de `database.py` para identificar qué tabla falló al insertar.")
        return None, None, None # Indicar fallo

    # --- Generar Tickets ---
    print("Generando 30 tickets...")
    tickets_data = []
    for i in range(1, 31):
        numero_ticket = f"SYN-{i:04d}"
        # Usamos random.choice() solo si las listas NO están vacías (ya verificado arriba)
        id_cliente = random.choice(cliente_ids)
        id_tecnico_asignado = random.choice(tecnico_ids + [None]) # Permitir que no tenga técnico asignado
        id_tipo_tarea = random.choice(tipo_tarea_ids)
        id_prioridad = random.choice(prioridad_ids)
        id_estado = random.choice(estado_ids)
        
        titulo = f"Ticket Sintético de Prueba #{i}"
        descripcion = f"Esta es la descripción del ticket sintético número {i}. Se generó automáticamente."
        tiempo_estimado_horas = round(random.uniform(0.5, 8.0), 2)
        
        fecha_creacion = datetime.now() - timedelta(days=random.randint(1, 30))
        
        fecha_asignacion = None
        if id_tecnico_asignado is not None:
            fecha_asignacion = fecha_creacion + timedelta(hours=random.randint(1, 24))
        
        fecha_cierre = None
        if id_estado in estados_finales_ids_actuales: # Comprueba si el estado asignado es final
            fecha_cierre = fecha_asignacion if fecha_asignacion else fecha_creacion
            fecha_cierre += timedelta(days=random.randint(0, 7), hours=random.randint(0, 23))

        tickets_data.append({
            "numero_ticket": numero_ticket, "id_cliente": id_cliente, "id_tecnico_asignado": id_tecnico_asignado,
            "id_tipo_tarea": id_tipo_tarea, "id_prioridad": id_prioridad, "id_estado": id_estado,
            "titulo": titulo, "descripcion": descripcion, "fecha_creacion": fecha_creacion,
            "fecha_asignacion": fecha_asignacion, "fecha_cierre": fecha_cierre,
            "tiempo_estimado_horas": tiempo_estimado_horas
        })
    print("  -> Tickets generados.")
    return tecnicos_data, clientes_data, tickets_data

def populate_database():
    """Inserta los datos sintéticos generados en la base de datos."""
    
    print("--- Iniciando proceso de población ---")
    # Paso 1: Inicializar la Base de Datos. Esto crea el archivo DB y las tablas maestras.
    initialization_successful = db.initialize_database()

    if not initialization_successful:
        print("Error fatal: Falló la inicialización de la base de datos. No se puede continuar con la población.")
        return

    # Paso 2: Generar Datos Sintéticos. Esta función ahora también verifica si los IDs maestros están disponibles.
    generated_data = generate_synthetic_data()

    # Si generate_synthetic_data devolvió None, significa que faltan datos maestros o hubo un error.
    if generated_data is None or any(d is None for d in generated_data):
        print("Error fatal: No se pudieron generar datos sintéticos debido a la falta de datos maestros o a un error previo.")
        print("Revisa los mensajes de error anteriores.")
        return
        
    tecnicos_data, clientes_data, tickets_data = generated_data

    # Paso 3: Insertar Datos en la DB
    conn = db.get_db_connection()
    if not conn:
        print("Error fatal: No se pudo obtener la conexión a la base de datos para la inserción. Terminando script.")
        return

    try:
        cursor = conn.cursor()

        # Insertar Técnicos
        print("Insertando técnicos...")
        for tecnico in tecnicos_data:
            try:
                cursor.execute('''
                    INSERT INTO tecnicos (nombre, apellido, email, login, password_hash, telefono, especialidad, fecha_ingreso)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (tecnico['nombre'], tecnico['apellido'], tecnico['email'], tecnico['login'], tecnico['password_hash'], tecnico['telefono'], tecnico['especialidad'], tecnico['fecha_ingreso']))
            except sqlite3.IntegrityError:
                print(f"Advertencia: Técnico {tecnico['email']} ya existe, omitiendo inserción.")
            except sqlite3.Error as e:
                print(f"Error insertando técnico {tecnico['email']}: {e}")
        print("  -> Técnicos insertados.")

        # Insertar Clientes
        print("Insertando clientes...")
        for cliente in clientes_data:
            try:
                cursor.execute('''
                    INSERT INTO clientes (nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (cliente['nombre_empresa'], cliente['contacto_principal'], cliente['email'], cliente['telefono'], cliente['direccion'], cliente['ciudad'], cliente['pais']))
            except sqlite3.Error as e:
                print(f"Error insertando cliente {cliente['nombre_empresa']}: {e}")
        print("  -> Clientes insertados.")

        # Insertar Tickets
        print("Insertando tickets...")
        for ticket in tickets_data:
            try:
                cursor.execute('''
                    INSERT INTO tickets (numero_ticket, id_cliente, id_tecnico_asignado, id_tipo_tarea, id_prioridad, id_estado, titulo, descripcion, fecha_creacion, fecha_asignacion, fecha_cierre, tiempo_estimado_horas)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    ticket['numero_ticket'], ticket['id_cliente'], ticket['id_tecnico_asignado'], ticket['id_tipo_tarea'], ticket['id_prioridad'], ticket['id_estado'],
                    ticket['titulo'], ticket['descripcion'], ticket['fecha_creacion'], ticket['fecha_asignacion'], ticket['fecha_cierre'], ticket['tiempo_estimado_horas']
                ))
            except sqlite3.IntegrityError:
                print(f"Advertencia: Ticket con número {ticket['numero_ticket']} ya existe, omitiendo inserción.")
            except sqlite3.Error as e:
                print(f"Error insertando ticket {ticket['numero_ticket']}: {e}")
        print("  -> Tickets insertados.")

        conn.commit()
        print("\n--- ¡Datos sintéticos insertados correctamente! ---")

    except sqlite3.Error as e:
        print(f"Error general durante la población de la base de datos: {e}")
        conn.rollback() # Deshacer cambios si ocurre un error
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    populate_database()