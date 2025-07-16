import sqlite3
from datetime import datetime
import hashlib # Necesario para el hash de contraseñas

DATABASE_NAME = 'sistema_tickets.db'

def initialize_database():
    """Crea la base de datos y las tablas si no existen."""
    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()

        # --- Creación de Tablas ---
        print("Creando tablas si no existen...")
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS tecnicos (
            id_tecnico INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre VARCHAR(100) NOT NULL,
            apellido VARCHAR(100) NOT NULL,
            email VARCHAR(150) UNIQUE NOT NULL,
            login VARCHAR(50) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            telefono VARCHAR(20),
            especialidad VARCHAR(100),
            fecha_ingreso DATE NOT NULL,
            activo INTEGER DEFAULT 1, -- 1 for TRUE, 0 for FALSE
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        ''')
        print("  -> tecnicos: OK")
        
        cursor.execute('''
        CREATE TABLE IF NOT EXISTS clientes (
            id_cliente INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre_empresa VARCHAR(200) NOT NULL,
            contacto_principal VARCHAR(150),
            email VARCHAR(150),
            telefono VARCHAR(20),
            direccion TEXT,
            ciudad VARCHAR(100),
            pais VARCHAR(100) DEFAULT 'España',
            activo INTEGER DEFAULT 1, -- 1 for TRUE, 0 for FALSE
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        ''')
        print("  -> clientes: OK")

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS tipos_tarea (
            id_tipo_tarea INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre VARCHAR(200) NOT NULL UNIQUE,
            descripcion TEXT,
            tiempo_estimado_horas REAL,
            prioridad_default VARCHAR(20) DEFAULT 'Media',
            activo INTEGER DEFAULT 1, -- 1 for TRUE, 0 for FALSE
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        ''')
        print("  -> tipos_tarea: OK")

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS modalidades_trabajo (
            id_modalidad INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre VARCHAR(50) NOT NULL UNIQUE,
            descripcion TEXT,
            activo INTEGER DEFAULT 1 -- 1 for TRUE, 0 for FALSE
        );
        ''')
        print("  -> modalidades_trabajo: OK")

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS prioridades (
            id_prioridad INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre VARCHAR(20) NOT NULL UNIQUE,
            nivel INTEGER NOT NULL,
            color_hex VARCHAR(7),
            descripcion TEXT
        );
        ''')
        print("  -> prioridades: OK")

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS estados_ticket (
            id_estado INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre VARCHAR(50) NOT NULL UNIQUE,
            descripcion TEXT,
            es_final INTEGER DEFAULT 0, -- 0 for FALSE, 1 for TRUE
            orden_flujo INTEGER
        );
        ''')
        print("  -> estados_ticket: OK")

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS tickets (
            id_ticket INTEGER PRIMARY KEY AUTOINCREMENT,
            numero_ticket VARCHAR(20) UNIQUE,
            id_cliente INTEGER NOT NULL,
            id_tecnico_asignado INTEGER,
            id_tipo_tarea INTEGER NOT NULL,
            id_prioridad INTEGER NOT NULL,
            id_estado INTEGER NOT NULL,
            titulo VARCHAR(200) NOT NULL,
            descripcion TEXT,
            fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
            fecha_asignacion DATETIME,
            fecha_cierre DATETIME,
            tiempo_estimado_horas REAL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
            FOREIGN KEY (id_tecnico_asignado) REFERENCES tecnicos(id_tecnico),
            FOREIGN KEY (id_tipo_tarea) REFERENCES tipos_tarea(id_tipo_tarea),
            FOREIGN KEY (id_prioridad) REFERENCES prioridades(id_prioridad),
            FOREIGN KEY (id_estado) REFERENCES estados_ticket(id_estado)
        );
        ''')
        print("  -> tickets: OK")

        cursor.execute('''
        CREATE TABLE IF NOT EXISTS registros_actividad (
            id_registro INTEGER PRIMARY KEY AUTOINCREMENT,
            id_ticket INTEGER NOT NULL,
            id_tecnico INTEGER NOT NULL,
            id_modalidad INTEGER NOT NULL,
            fecha_actividad DATE NOT NULL,
            tiempo_dedicado_horas REAL NOT NULL,
            descripcion_trabajo TEXT,
            observaciones TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (id_ticket) REFERENCES tickets(id_ticket),
            FOREIGN KEY (id_tecnico) REFERENCES tecnicos(id_tecnico),
            FOREIGN KEY (id_modalidad) REFERENCES modalidades_trabajo(id_modalidad)
        );
        ''')
        print("  -> registros_actividad: OK")

        # --- Índices ---
        print("Creando índices si no existen...")
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_tickets_cliente ON tickets(id_cliente);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_tickets_tecnico ON tickets(id_tecnico_asignado);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_tickets_tipo_tarea ON tickets(id_tipo_tarea);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_tickets_estado ON tickets(id_estado);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_registros_ticket ON registros_actividad(id_ticket);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_registros_tecnico ON registros_actividad(id_tecnico);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_tickets_numero ON tickets(numero_ticket);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_tickets_fecha_creacion ON tickets(fecha_creacion);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_registros_fecha ON registros_actividad(fecha_actividad);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_tecnicos_login ON tecnicos(login);')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_clientes_nombre ON clientes(nombre_empresa);')
        print("Índices creados/verificados.")

        conn.commit()
        print("Tablas y índices creados/verificados correctamente.")
        
        # Insertar datos maestros solo si las tablas estaban vacías
        insert_master_data_if_empty(conn) 
        
        return True # Indicar éxito
    except sqlite3.Error as e:
        print(f"Error al inicializar la base de datos (creación de tablas/índices): {e}")
        return False # Indicar fallo
    finally:
        if conn:
            conn.close()

def insert_master_data_if_empty(conn):
    """Inserta datos maestros solo si las tablas están vacías."""
    cursor = conn.cursor()
    
    # --- Lógica de inserción para cada tabla maestra ---
    
    # Modalidades de trabajo
    cursor.execute("SELECT COUNT(*) FROM modalidades_trabajo")
    if cursor.fetchone()[0] == 0:
        print("Insertando datos maestros: modalidades_trabajo")
        try:
            cursor.execute("INSERT INTO modalidades_trabajo (nombre, descripcion) VALUES (?, ?)", ('Presencial', 'Trabajo realizado en las instalaciones del cliente'))
            cursor.execute("INSERT INTO modalidades_trabajo (nombre, descripcion) VALUES (?, ?)", ('Remoto', 'Trabajo realizado de forma remota'))
            cursor.execute("INSERT INTO modalidades_trabajo (nombre, descripcion) VALUES (?, ?)", ('Híbrido', 'Combinación de trabajo presencial y remoto'))
            cursor.execute("INSERT INTO modalidades_trabajo (nombre, descripcion) VALUES (?, ?)", ('Telefónico', 'Soporte telefónico únicamente'))
            print("  -> Modalidades de trabajo: OK.")
        except sqlite3.Error as e:
            print(f"  -> ERROR insertando modalidades_trabajo: {e}")

    # Prioridades
    cursor.execute("SELECT COUNT(*) FROM prioridades")
    if cursor.fetchone()[0] == 0:
        print("Insertando datos maestros: prioridades")
        try:
            cursor.execute("INSERT INTO prioridades (nombre, nivel, color_hex, descripcion) VALUES (?, ?, ?, ?)", ('Crítica', 1, '#FF0000', 'Requiere atención inmediata'))
            cursor.execute("INSERT INTO prioridades (nombre, nivel, color_hex, descripcion) VALUES (?, ?, ?, ?)", ('Alta', 2, '#FF8000', 'Debe resolverse en el día'))
            cursor.execute("INSERT INTO prioridades (nombre, nivel, color_hex, descripcion) VALUES (?, ?, ?, ?)", ('Media', 3, '#FFFF00', 'Resolución en 2-3 días'))
            cursor.execute("INSERT INTO prioridades (nombre, nivel, color_hex, descripcion) VALUES (?, ?, ?, ?)", ('Baja', 4, '#00FF00', 'Puede esperar hasta una semana'))
            cursor.execute("INSERT INTO prioridades (nombre, nivel, color_hex, descripcion) VALUES (?, ?, ?, ?)", ('Muy Baja', 5, '#0080FF', 'Sin urgencia específica'))
            print("  -> Prioridades: OK.")
        except sqlite3.Error as e:
            print(f"  -> ERROR insertando prioridades: {e}")

    # Estados de ticket
    cursor.execute("SELECT COUNT(*) FROM estados_ticket")
    if cursor.fetchone()[0] == 0:
        print("Insertando datos maestros: estados_ticket")
        try:
            cursor.execute("INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES (?, ?, ?, ?)", ('Nuevo', 'Ticket recién creado', 0, 1))
            cursor.execute("INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES (?, ?, ?, ?)", ('Asignado', 'Ticket asignado a técnico', 0, 2))
            cursor.execute("INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES (?, ?, ?, ?)", ('En Progreso', 'Técnico trabajando en el ticket', 0, 3))
            cursor.execute("INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES (?, ?, ?, ?)", ('Pendiente Cliente', 'Esperando respuesta del cliente', 0, 4))
            cursor.execute("INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES (?, ?, ?, ?)", ('Resuelto', 'Problema solucionado', 1, 5))
            cursor.execute("INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES (?, ?, ?, ?)", ('Cerrado', 'Ticket cerrado y archivado', 1, 6))
            cursor.execute("INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES (?, ?, ?, ?)", ('Cancelado', 'Ticket cancelado', 1, 7))
            print("  -> Estados de ticket: OK.")
        except sqlite3.Error as e:
            print(f"  -> ERROR insertando estados_ticket: {e}")

    # Tipos de tarea
    cursor.execute("SELECT COUNT(*) FROM tipos_tarea")
    if cursor.fetchone()[0] == 0:
        print("Insertando datos maestros: tipos_tarea")
        try:
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Soporte a usuarios finales', 'Asistencia directa a usuarios con problemas técnicos', 1.5, 'Media'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Planificación y escalabilidad de TI', 'Planificación de infraestructura y crecimiento', 4.0, 'Alta'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Mantenimiento de impresoras', 'Reparación y mantenimiento de equipos de impresión', 1.0, 'Baja'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Actualización de equipos', 'Actualización de hardware y software', 2.5, 'Media'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Configuración de red', 'Configuración y mantenimiento de redes', 3.0, 'Alta'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Backup y recuperación', 'Gestión de copias de seguridad', 2.0, 'Alta'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Instalación de software', 'Instalación y configuración de aplicaciones', 1.5, 'Media'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Seguridad informática', 'Implementación de medidas de seguridad', 3.5, 'Crítica'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Migración de datos', 'Transferencia y migración de información', 4.5, 'Alta'))
            cursor.execute("INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES (?, ?, ?, ?)", ('Capacitación técnica', 'Formación a usuarios y personal técnico', 2.0, 'Baja'))
            print("  -> Tipos de tarea: OK.")
        except sqlite3.Error as e:
            print(f"  -> ERROR insertando tipos_tarea: {e}")

    # --- NUEVO: Insertar Técnicos Maestros ---
    cursor.execute("SELECT COUNT(*) FROM tecnicos")
    if cursor.fetchone()[0] == 0:
        print("Insertando datos maestros: tecnicos")
        try:
            tecnicos_maestros = [
                ("Dora", "Bermúdez", "dora.b@ejemplo.com", "dora.b", hashlib.sha256("pass1".encode()).hexdigest(), "+34111111111", "Infraestructura", "2024-01-01"),
                ("Bienvenida", "Verdejo", "bienvenida.v@ejemplo.com", "bienvenida.v", hashlib.sha256("pass2".encode()).hexdigest(), "+34222222222", "Bases de Datos", "2024-01-01"),
                ("Onofre", "Ariño", "onofre.a@ejemplo.com", "onofre.a", hashlib.sha256("pass3".encode()).hexdigest(), "+34333333333", "Cloud", "2024-01-01"),
                ("Aurelio", "Sáenz", "aurelio.s@ejemplo.com", "aurelio.s", hashlib.sha256("pass4".encode()).hexdigest(), "+34444444444", "Hardware", "2024-01-01"),
                ("Telmo", "Torrijos", "telmo.t@ejemplo.com", "telmo.t", hashlib.sha256("pass5".encode()).hexdigest(), "+34555555555", "Backup", "2024-01-01")
            ]
            cursor.executemany("INSERT INTO tecnicos (nombre, apellido, email, login, password_hash, telefono, especialidad, fecha_ingreso) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", tecnicos_maestros)
            print("  -> Técnicos: OK.")
        except sqlite3.Error as e:
            print(f"  -> ERROR insertando tecnicos: {e}")

    # Clientes (como datos maestros iniciales)
    cursor.execute("SELECT COUNT(*) FROM clientes")
    if cursor.fetchone()[0] == 0:
        print("Insertando datos maestros: clientes")
        try:
            clientes_maestros = [
                ("Empresa Tech", "Juan Perez", "juan.p@tech.com", "+34900111222", "Calle Mayor 1", "Madrid", "España"),
                ("Soluciones Digitales", "Ana García", "ana.g@digital.com", "+34900333444", "Av. Principal 10", "Barcelona", "España"),
                ("Innova Corp", "Carlos Ruiz", "carlos.r@innova.com", "+34900555666", "Plaza Central 5", "Valencia", "España"),
                ("Global Services", "Laura Fernández", "laura.f@global.com", "+34900777888", "Calle Luna 15", "Sevilla", "España"),
                ("Tech Solutions", "Pedro Gómez", "pedro.g@techsol.com", "+34900999000", "Av. Sol 20", "Bilbao", "España")
            ]
            cursor.executemany("INSERT INTO clientes (nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais) VALUES (?, ?, ?, ?, ?, ?, ?)", clientes_maestros)
            print("  -> Clientes: OK.")
        except sqlite3.Error as e:
            print(f"  -> ERROR insertando clientes: {e}")

    conn.commit()
    print("Verificación de datos maestros completada.")


# --- Funciones CRUD ---

def get_db_connection():
    """Establece y devuelve una conexión a la base de datos."""
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row # Devuelve filas como diccionarios
        return conn
    except sqlite3.Error as e:
        print(f"Error al conectar a la base de datos: {e}")
        return None

# --- CRUD para Técnicos ---
def add_tecnico(nombre, apellido, email, login, password_hash, telefono, especialidad, fecha_ingreso):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO tecnicos (nombre, apellido, email, login, password_hash, telefono, especialidad, fecha_ingreso)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (nombre, apellido, email, login, password_hash, telefono, especialidad, fecha_ingreso))
        conn.commit()
        return True
    except sqlite3.IntegrityError: # Para campos UNIQUE como email/login
        return False
    except sqlite3.Error as e:
        print(f"Error al agregar técnico: {e}")
        return False
    finally:
        conn.close()

def get_tecnicos():
    conn = get_db_connection()
    if not conn: return []
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tecnicos")
        tecnicos = cursor.fetchall()
        return tecnicos
    except sqlite3.Error as e:
        print(f"Error al obtener técnicos: {e}")
        return []
    finally:
        conn.close()

def get_tecnico_by_id(id_tecnico):
    conn = get_db_connection()
    if not conn: return None
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM tecnicos WHERE id_tecnico = ?", (id_tecnico,))
        tecnico = cursor.fetchone()
        return tecnico
    except sqlite3.Error as e:
        print(f"Error al obtener técnico por ID: {e}")
        return None
    finally:
        conn.close()

def update_tecnico(id_tecnico, nombre, apellido, email, login, telefono, especialidad, fecha_ingreso, activo):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE tecnicos
            SET nombre = ?, apellido = ?, email = ?, login = ?, telefono = ?, especialidad = ?, fecha_ingreso = ?, activo = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id_tecnico = ?
        ''', (nombre, apellido, email, login, telefono, especialidad, fecha_ingreso, activo, id_tecnico))
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    except sqlite3.Error as e:
        print(f"Error al actualizar técnico: {e}")
        return False
    finally:
        conn.close()

def delete_tecnico(id_tecnico):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM tecnicos WHERE id_tecnico = ?", (id_tecnico,))
        conn.commit()
        return True
    except sqlite3.Error as e:
        print(f"Error al eliminar técnico: {e}")
        return False
    finally:
        conn.close()

# --- CRUD para Clientes ---
def add_cliente(nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO clientes (nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais))
        conn.commit()
        return True
    except sqlite3.Error as e:
        print(f"Error al agregar cliente: {e}")
        return False
    finally:
        conn.close()

def get_clientes():
    conn = get_db_connection()
    if not conn: return []
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM clientes")
        clientes = cursor.fetchall()
        return clientes
    except sqlite3.Error as e:
        print(f"Error al obtener clientes: {e}")
        return []
    finally:
        conn.close()

def get_cliente_by_id(id_cliente):
    conn = get_db_connection()
    if not conn: return None
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM clientes WHERE id_cliente = ?", (id_cliente,))
        cliente = cursor.fetchone()
        return cliente
    except sqlite3.Error as e:
        print(f"Error al obtener cliente por ID: {e}")
        return None
    finally:
        conn.close()

def update_cliente(id_cliente, nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais, activo):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE clientes
            SET nombre_empresa = ?, contacto_principal = ?, email = ?, telefono = ?, direccion = ?, ciudad = ?, pais = ?, activo = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id_cliente = ?
        ''', (nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais, activo, id_cliente))
        conn.commit()
        return True
    except sqlite3.Error as e:
        print(f"Error al actualizar cliente: {e}")
        return False
    finally:
        conn.close()

def delete_cliente(id_cliente):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM clientes WHERE id_cliente = ?", (id_cliente,))
        conn.commit()
        return True
    except sqlite3.Error as e:
        print(f"Error al eliminar cliente: {e}")
        return False
    finally:
        conn.close()

# --- CRUD para Tickets ---
def add_ticket(numero_ticket, id_cliente, id_tecnico_asignado, id_tipo_tarea, id_prioridad, id_estado, titulo, descripcion, tiempo_estimado_horas):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO tickets (numero_ticket, id_cliente, id_tecnico_asignado, id_tipo_tarea, id_prioridad, id_estado, titulo, descripcion, tiempo_estimado_horas)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (numero_ticket, id_cliente, id_tecnico_asignado, id_tipo_tarea, id_prioridad, id_estado, titulo, descripcion, tiempo_estimado_horas))
        conn.commit()
        return True
    except sqlite3.IntegrityError: # Para numero_ticket UNIQUE
        return False
    except sqlite3.Error as e:
        print(f"Error al agregar ticket: {e}")
        return False
    finally:
        conn.close()

def get_tickets():
    conn = get_db_connection()
    if not conn: return []
    try:
        cursor = conn.cursor()
        query = """
        SELECT
            tk.id_ticket, tk.numero_ticket, c.nombre_empresa,
            t.nombre || ' ' || t.apellido AS tecnico_asignado,
            tt.nombre AS tipo_tarea, p.nombre AS prioridad,
            e.nombre AS estado, tk.titulo, tk.fecha_creacion
        FROM tickets tk
        LEFT JOIN clientes c ON tk.id_cliente = c.id_cliente
        LEFT JOIN tecnicos t ON tk.id_tecnico_asignado = t.id_tecnico
        LEFT JOIN tipos_tarea tt ON tk.id_tipo_tarea = tt.id_tipo_tarea
        LEFT JOIN prioridades p ON tk.id_prioridad = p.id_prioridad
        LEFT JOIN estados_ticket e ON tk.id_estado = e.id_estado
        ORDER BY tk.fecha_creacion DESC
        """
        cursor.execute(query)
        tickets = cursor.fetchall()
        return tickets
    except sqlite3.Error as e:
        print(f"Error al obtener tickets: {e}")
        return []
    finally:
        conn.close()

def get_ticket_by_id(id_ticket):
    conn = get_db_connection()
    if not conn: return None
    try:
        cursor = conn.cursor()
        query = """
        SELECT
            tk.*, c.nombre_empresa,
            t.nombre || ' ' || t.apellido AS tecnico_asignado,
            tt.nombre AS tipo_tarea, p.nombre AS prioridad,
            e.nombre AS estado
        FROM tickets tk
        LEFT JOIN clientes c ON tk.id_cliente = c.id_cliente
        LEFT JOIN tecnicos t ON tk.id_tecnico_asignado = t.id_tecnico
        LEFT JOIN tipos_tarea tt ON tk.id_tipo_tarea = tt.id_tipo_tarea
        LEFT JOIN prioridades p ON tk.id_prioridad = p.id_prioridad
        LEFT JOIN estados_ticket e ON tk.id_estado = e.id_estado
        WHERE tk.id_ticket = ?
        """
        cursor.execute(query, (id_ticket,))
        ticket = cursor.fetchone()
        return ticket
    except sqlite3.Error as e:
        print(f"Error al obtener ticket por ID: {e}")
        return None
    finally:
        conn.close()

def update_ticket(id_ticket, numero_ticket, id_cliente, id_tecnico_asignado, id_tipo_tarea, id_prioridad, id_estado, titulo, descripcion, fecha_asignacion, fecha_cierre, tiempo_estimado_horas):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE tickets
            SET numero_ticket = ?, id_cliente = ?, id_tecnico_asignado = ?, id_tipo_tarea = ?, id_prioridad = ?, id_estado = ?,
                titulo = ?, descripcion = ?, fecha_asignacion = ?, fecha_cierre = ?, tiempo_estimado_horas = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id_ticket = ?
        ''', (numero_ticket, id_cliente, id_tecnico_asignado, id_tipo_tarea, id_prioridad, id_estado, titulo, descripcion, fecha_asignacion, fecha_cierre, tiempo_estimado_horas, id_ticket))
        conn.commit()
        return True
    except sqlite3.Error as e:
        print(f"Error al actualizar ticket: {e}")
        return False
    finally:
        conn.close()

def delete_ticket(id_ticket):
    conn = get_db_connection()
    if not conn: return False
    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM registros_actividad WHERE id_ticket = ?", (id_ticket,)) # Considerar borrar dependientes
        cursor.execute("DELETE FROM tickets WHERE id_ticket = ?", (id_ticket,))
        conn.commit()
        return True
    except sqlite3.Error as e:
        print(f"Error al eliminar ticket: {e}")
        return False
    finally:
        conn.close()

# --- Funciones para obtener datos de catálogos ---
def get_catalog_data(table_name, id_column, name_column):
    conn = get_db_connection()
    if not conn: return {}
    try:
        cursor = conn.cursor()
        cursor.execute(f"SELECT {id_column}, {name_column} FROM {table_name} WHERE activo = 1 ORDER BY {name_column}")
        data = cursor.fetchall()
        return {row[id_column]: row[name_column] for row in data}
    except sqlite3.Error as e:
        print(f"Error al obtener datos del catálogo {table_name}: {e}")
        return {}
    finally:
        conn.close()

def get_tipos_tarea_catalog():
    return get_catalog_data('tipos_tarea', 'id_tipo_tarea', 'nombre')

def get_tecnicos_catalog():
    conn = get_db_connection()
    if not conn: return {}
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id_tecnico, nombre || ' ' || apellido AS full_name FROM tecnicos WHERE activo = 1 ORDER BY nombre")
        data = cursor.fetchall()
        return {row['id_tecnico']: row['full_name'] for row in data}
    except sqlite3.Error as e:
        print(f"Error al obtener catálogo de técnicos: {e}")
        return {}
    finally:
        conn.close()

def get_prioridades_catalog():
    return get_catalog_data('prioridades', 'id_prioridad', 'nombre')

def get_estados_ticket_catalog():
    return get_catalog_data('estados_ticket', 'id_estado', 'nombre')