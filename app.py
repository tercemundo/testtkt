import streamlit as st
import pandas as pd
from datetime import datetime
import hashlib 
import sqlite3 

# Importar nuestro módulo de base de datos
import database as db 

# --- Configuración de la página ---
st.set_page_config(
    page_title="Sistema de Tickets CRUD",
    page_icon="🎫",
    layout="wide",
    initial_sidebar_state="expanded",
)

# --- Funciones de Ayuda ---

def hash_password(password):
    """Genera un hash simple para la contraseña. En producción, usar bcrypt o similar."""
    return hashlib.sha256(password.encode()).hexdigest()

def display_message(message, type="info"):
    """Muestra un mensaje en Streamlit."""
    if type == "success":
        st.success(message)
    elif type == "error":
        st.error(message)
    else:
        st.info(message)

# --- Inicializar la Base de Datos ---
db.initialize_database() 

# --- Sidebar ---
st.sidebar.title("Navegación")
menu_selection = st.sidebar.radio(
    "Ir a:",
    ("Dashboard", "Técnicos", "Clientes", "Tickets")
)

st.sidebar.markdown("---")
st.sidebar.write("Hecho con ❤️ y Streamlit")

# --- Contenido Principal ---

if menu_selection == "Dashboard":
    st.title("Dashboard")
    st.write("Bienvenido al sistema de gestión de tickets.")

    conn = db.get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()

            cursor.execute("SELECT COUNT(*) FROM tickets")
            total_tickets = cursor.fetchone()[0]

            cursor.execute("""
                SELECT COUNT(*) FROM tickets
                WHERE id_estado NOT IN (SELECT id_estado FROM estados_ticket WHERE es_final = 1)
            """)
            tickets_abiertos = cursor.fetchone()[0]

            cursor.execute("SELECT COUNT(*) FROM tecnicos WHERE activo = 1")
            tecnicos_activos = cursor.fetchone()[0]

            cursor.execute("SELECT COUNT(*) FROM clientes WHERE activo = 1")
            clientes_activos = cursor.fetchone()
            clientes_activos = clientes_activos[0] if clientes_activos else 0


            col1, col2, col3, col4 = st.columns(4)
            col1.metric("Total Tickets", total_tickets)
            col2.metric("Tickets Abiertos", tickets_abiertos)
            col3.metric("Técnicos Activos", tecnicos_activos)
            col4.metric("Clientes Activos", clientes_activos)

            st.subheader("Tickets recientes")
            recent_tickets_raw = db.get_tickets() 
            recent_tickets_df = pd.DataFrame(recent_tickets_raw)

            # --- DEPURACIÓN: Imprimir columnas ---
            print("\n--- Columnas RECIENTES en recent_tickets_df (Dashboard) ---")
            if not recent_tickets_df.empty:
                print(recent_tickets_df.columns.tolist())
            else:
                print("DataFrame de tickets recientes está vacío.")
            print("--- Fin de columnas ---")
            # --- Fin de Depuración ---

            if not recent_tickets_df.empty:
                try:
                    columnas_esperadas_dashboard = ['numero_ticket', 'titulo', 'tipo_tarea', 'estado', 'fecha_creacion']
                    columnas_validas = [col for col in columnas_esperadas_dashboard if col in recent_tickets_df.columns]
                    
                    if len(columnas_validas) == len(columnas_esperadas_dashboard):
                        st.dataframe(recent_tickets_df[columnas_esperadas_dashboard])
                    else:
                        st.warning("No todas las columnas esperadas están presentes en los tickets recientes.")
                        st.write("Columnas disponibles:")
                        st.write(recent_tickets_df.columns.tolist())
                        if columnas_validas:
                            st.dataframe(recent_tickets_df[columnas_validas])

                except KeyError as e:
                    st.error(f"Error al mostrar tickets recientes: {e}. Las columnas esperadas pueden no estar disponibles.")
                    st.write("Columnas disponibles:")
                    st.write(recent_tickets_df.columns.tolist())

            else:
                st.write("No hay tickets registrados aún.")

        except sqlite3.Error as e:
            st.error(f"Error al cargar datos del dashboard: {e}")
        finally:
            if conn:
                conn.close()
    else:
        st.error("No se pudo conectar a la base de datos para el dashboard.")


# --- CRUD para Técnicos ---
elif menu_selection == "Técnicos":
    st.title("Gestión de Técnicos")

    st.subheader("Añadir/Editar Técnico")

    tecnicos_catalog_for_select = db.get_tecnicos_catalog() 
    if not tecnicos_catalog_for_select:
        st.warning("No hay técnicos activos para mostrar en selecciones.")

    with st.form("add_tecnico_form", clear_on_submit=True):
        st.write("**Datos del Técnico**")
        nombre = st.text_input("Nombre", key="tecnico_nombre")
        apellido = st.text_input("Apellido", key="tecnico_apellido")
        email = st.text_input("Email", key="tecnico_email")
        login = st.text_input("Login", key="tecnico_login")
        password = st.text_input("Contraseña", type="password", key="tecnico_password")
        telefono = st.text_input("Teléfono", key="tecnico_telefono")
        especialidad = st.text_input("Especialidad", key="tecnico_especialidad")
        fecha_ingreso_str = st.text_input("Fecha de Ingreso (YYYY-MM-DD)", value=datetime.now().strftime("%Y-%m-%d"), key="tecnico_fecha_ingreso")

        submitted_add = st.form_submit_button("Añadir Técnico")

        if submitted_add:
            if not all([nombre, apellido, email, login, password, fecha_ingreso_str]):
                st.error("Por favor, complete todos los campos obligatorios.")
            else:
                try:
                    fecha_ingreso = datetime.strptime(fecha_ingreso_str, "%Y-%m-%d").date()
                    hashed_password = hash_password(password)
                    if db.add_tecnico(nombre, apellido, email, login, hashed_password, telefono, especialidad, fecha_ingreso):
                        display_message("Técnico añadido con éxito.", "success")
                        st.experimental_rerun()
                    else:
                        display_message("Error al añadir técnico. El email o login ya existen.", "error")
                except ValueError:
                    st.error("Formato de fecha de ingreso inválido. Use YYY-MM-DD.")

    st.markdown("---")

    st.subheader("Listado de Técnicos")
    tecnicos_data = db.get_tecnicos()
    tecnicos_df = pd.DataFrame(tecnicos_data)

    if not tecnicos_df.empty:
        if 'fecha_ingreso' in tecnicos_df.columns:
            tecnicos_df['fecha_ingreso'] = pd.to_datetime(tecnicos_df['fecha_ingreso']).dt.strftime('%Y-%m-%d')
        if 'created_at' in tecnicos_df.columns:
            tecnicos_df['created_at'] = pd.to_datetime(tecnicos_df['created_at']).dt.strftime('%Y-%m-%d %H:%M')
        if 'updated_at' in tecnicos_df.columns:
            tecnicos_df['updated_at'] = pd.to_datetime(tecnicos_df['updated_at']).dt.strftime('%Y-%m-%d %H:%M')

        cols_to_show = ['nombre', 'apellido', 'email', 'login', 'especialidad', 'activo', 'fecha_ingreso']
        cols_to_show_presentes = [col for col in cols_to_show if col in tecnicos_df.columns]
        st.dataframe(tecnicos_df[cols_to_show_presentes])

        st.subheader("Acciones sobre Técnicos")
        with st.expander("Editar/Eliminar Técnico"):
            # Verificar si 'id_tecnico' existe antes de usarlo
            if 'id_tecnico' in tecnicos_df.columns:
                tecnico_ids_list = tecnicos_df['id_tecnico'].tolist()
                
                tecnico_id_to_manage = st.selectbox(
                    "Selecciona un técnico para editar/eliminar", 
                    options=tecnico_ids_list, 
                    format_func=lambda x: f"{tecnicos_df.loc[tecnicos_df['id_tecnico'] == x, 'nombre'].iloc[0]} {tecnicos_df.loc[tecnicos_df['id_tecnico'] == x, 'apellido'].iloc[0]} (ID: {x})" if x in tecnico_ids_list and not tecnicos_df.empty else "Selecciona un técnico",
                    key="manage_tecnico_select"
                )

                if tecnico_id_to_manage:
                    tecnico_data = db.get_tecnico_by_id(tecnico_id_to_manage)
                    if tecnico_data:
                        with st.form(f"edit_tecnico_form_{tecnico_id_to_manage}", clear_on_submit=False):
                            st.write(f"**Editando Técnico: {tecnico_data['nombre']} {tecnico_data['apellido']}**")
                            edit_nombre = st.text_input("Nombre", value=tecnico_data['nombre'], key=f"edit_nombre_{tecnico_id_to_manage}")
                            edit_apellido = st.text_input("Apellido", value=tecnico_data['apellido'], key=f"edit_apellido_{tecnico_id_to_manage}")
                            edit_email = st.text_input("Email", value=tecnico_data['email'], key=f"edit_email_{tecnico_id_to_manage}")
                            edit_login = st.text_input("Login", value=tecnico_data['login'], key=f"edit_login_{tecnico_id_to_manage}")
                            edit_telefono = st.text_input("Teléfono", value=tecnico_data['telefono'] if tecnico_data['telefono'] else "", key=f"edit_telefono_{tecnico_id_to_manage}")
                            edit_especialidad = st.text_input("Especialidad", value=tecnico_data['especialidad'] if tecnico_data['especialidad'] else "", key=f"edit_especialidad_{tecnico_id_to_manage}")
                            edit_fecha_ingreso_str = st.text_input("Fecha de Ingreso (YYYY-MM-DD)", value=tecnico_data['fecha_ingreso'], key=f"edit_fecha_ingreso_{tecnico_id_to_manage}")
                            edit_activo = st.checkbox("Activo", value=bool(tecnico_data['activo']), key=f"edit_activo_{tecnico_id_to_manage}")

                            col1, col2 = st.columns(2)
                            with col1:
                                submitted_edit = st.form_submit_button("Guardar Cambios")
                            with col2:
                                submitted_delete = st.form_submit_button("Eliminar Técnico")

                            if submitted_edit:
                                if not all([edit_nombre, edit_apellido, edit_email, edit_login, edit_fecha_ingreso_str]):
                                    st.error("Por favor, complete todos los campos obligatorios.")
                                else:
                                    try:
                                        fecha_ingreso_edit = datetime.strptime(edit_fecha_ingreso_str, "%Y-%m-%d").date()
                                        if db.update_tecnico(tecnico_id_to_manage, edit_nombre, edit_apellido, edit_email, edit_login, edit_telefono, edit_especialidad, fecha_ingreso_edit, int(edit_activo)):
                                            display_message("Técnico actualizado con éxito.", "success")
                                            st.experimental_rerun()
                                        else:
                                            display_message("Error al actualizar técnico. Verifique los datos (ej. email/login duplicados).", "error")
                                    except ValueError:
                                        st.error("Formato de fecha de ingreso inválido. Use YYYY-MM-DD.")

                            if submitted_delete:
                                if st.button("Confirmar Eliminación", key=f"confirm_delete_{tecnico_id_to_manage}"):
                                    if db.delete_tecnico(tecnico_id_to_manage):
                                        display_message("Técnico eliminado con éxito.", "success")
                                        st.experimental_rerun()
                                    else:
                                        display_message("Error al eliminar técnico. Puede tener tickets asignados.", "error")
                else:
                    st.error(f"No se pudieron cargar los datos del técnico con ID {tecnico_id_to_manage}.")
    else:
        st.info("Aún no hay técnicos registrados.")

# --- CRUD para Clientes ---
elif menu_selection == "Clientes":
    st.title("Gestión de Clientes")

    st.subheader("Añadir/Editar Cliente")

    clientes_catalog_list = db.get_clientes() 
    clientes_catalog_dict = {c['id_cliente']: c['nombre_empresa'] for c in clientes_catalog_list} 
    
    tecnicos_catalog = db.get_tecnicos_catalog() 
    tipos_tarea_catalog = db.get_tipos_tarea_catalog() 
    prioridades_catalog = db.get_prioridades_catalog() 
    estados_ticket_catalog = db.get_estados_ticket_catalog() 

    with st.form("add_cliente_form", clear_on_submit=True):
        st.write("**Datos del Cliente**")
        nombre_empresa = st.text_input("Nombre de Empresa", key="cliente_nombre_empresa")
        contacto_principal = st.text_input("Contacto Principal", key="cliente_contacto_principal")
        email = st.text_input("Email", key="cliente_email")
        telefono = st.text_input("Teléfono", key="cliente_telefono")
        direccion = st.text_area("Dirección", key="cliente_direccion")
        ciudad = st.text_input("Ciudad", key="cliente_ciudad")
        pais = st.text_input("País", value="España", key="cliente_pais")

        submitted_add = st.form_submit_button("Añadir Cliente")

        if submitted_add:
            if not nombre_empresa:
                st.error("El nombre de la empresa es obligatorio.")
            else:
                if db.add_cliente(nombre_empresa, contacto_principal, email, telefono, direccion, ciudad, pais):
                    display_message("Cliente añadido con éxito.", "success")
                    st.experimental_rerun()
                else:
                    display_message("Error al añadir cliente.", "error")

    st.markdown("---")

    st.subheader("Listado de Clientes")
    clientes_data = db.get_clientes()
    clientes_df = pd.DataFrame(clientes_data)

    if not clientes_df.empty:
        if 'created_at' in clientes_df.columns:
            clientes_df['created_at'] = pd.to_datetime(clientes_df['created_at']).dt.strftime('%Y-%m-%d %H:%M')
        if 'updated_at' in clientes_df.columns:
            clientes_df['updated_at'] = pd.to_datetime(clientes_df['updated_at']).dt.strftime('%Y-%m-%d %H:%M')

        cols_to_show = ['nombre_empresa', 'contacto_principal', 'email', 'telefono', 'ciudad', 'pais', 'activo']
        cols_to_show_presentes = [col for col in cols_to_show if col in clientes_df.columns]
        st.dataframe(clientes_df[cols_to_show_presentes])

        st.subheader("Acciones sobre Clientes")
        with st.expander("Editar/Eliminar Cliente"):
            # Verificar si 'id_cliente' existe antes de usarlo
            if 'id_cliente' in clientes_df.columns:
                cliente_ids_list = clientes_df['id_cliente'].tolist()
                
                cliente_id_to_manage = st.selectbox(
                    "Selecciona un cliente para editar/eliminar", 
                    options=cliente_ids_list, 
                    format_func=lambda x: clientes_catalog_dict.get(x, f"Cliente ID {x}") if x in clientes_catalog_dict and not clientes_df.empty else "Selecciona un cliente",
                    key="manage_cliente_select"
                )

                if cliente_id_to_manage:
                    cliente_data = db.get_cliente_by_id(cliente_id_to_manage)
                    if cliente_data:
                        with st.form(f"edit_cliente_form_{cliente_id_to_manage}", clear_on_submit=False):
                            st.write(f"**Editando Cliente: {cliente_data['nombre_empresa']}**")
                            edit_nombre_empresa = st.text_input("Nombre de Empresa", value=cliente_data['nombre_empresa'], key=f"edit_cliente_nombre_{cliente_id_to_manage}")
                            edit_contacto_principal = st.text_input("Contacto Principal", value=cliente_data['contacto_principal'] if cliente_data['contacto_principal'] else "", key=f"edit_cliente_contacto_{cliente_id_to_manage}")
                            edit_email = st.text_input("Email", value=cliente_data['email'] if cliente_data['email'] else "", key=f"edit_cliente_email_{cliente_id_to_manage}")
                            edit_telefono = st.text_input("Teléfono", value=cliente_data['telefono'] if cliente_data['telefono'] else "", key=f"edit_cliente_telefono_{cliente_id_to_manage}")
                            edit_direccion = st.text_area("Dirección", value=cliente_data['direccion'] if cliente_data['direccion'] else "", key=f"edit_cliente_direccion_{cliente_id_to_manage}")
                            edit_ciudad = st.text_input("Ciudad", value=cliente_data['ciudad'] if cliente_data['ciudad'] else "", key=f"edit_cliente_ciudad_{cliente_id_to_manage}")
                            edit_pais = st.text_input("País", value=cliente_data['pais'], key=f"edit_cliente_pais_{cliente_id_to_manage}")
                            edit_activo = st.checkbox("Activo", value=bool(cliente_data['activo']), key=f"edit_cliente_activo_{cliente_id_to_manage}")

                            col1, col2 = st.columns(2)
                            with col1:
                                submitted_edit = st.form_submit_button("Guardar Cambios")
                            with col2:
                                submitted_delete = st.form_submit_button("Eliminar Cliente")

                            if submitted_edit:
                                if not edit_nombre_empresa:
                                    st.error("El nombre de la empresa es obligatorio.")
                                else:
                                    if db.update_cliente(cliente_id_to_manage, edit_nombre_empresa, edit_contacto_principal, edit_email, edit_telefono, edit_direccion, edit_ciudad, edit_pais, int(edit_activo)):
                                        display_message("Cliente actualizado con éxito.", "success")
                                        st.experimental_rerun()
                                    else:
                                        display_message("Error al actualizar cliente.", "error")

                            if submitted_delete:
                                if st.button("Confirmar Eliminación", key=f"confirm_delete_cliente_{cliente_id_to_manage}"):
                                    if db.delete_cliente(cliente_id_to_manage):
                                        display_message("Cliente eliminado con éxito.", "success")
                                        st.experimental_rerun()
                                    else:
                                        display_message("Error al eliminar cliente. Puede tener tickets asociados.", "error")
                else:
                    st.error(f"No se pudieron cargar los datos del cliente con ID {cliente_id_to_manage}.")
    else:
        st.info("Aún no hay clientes registrados.")

# --- CRUD para Tickets ---
elif menu_selection == "Tickets":
    st.title("Gestión de Tickets")

    clientes_catalog_list = db.get_clientes() 
    clientes_catalog_dict = {c['id_cliente']: c['nombre_empresa'] for c in clientes_catalog_list} 
    
    tecnicos_catalog = db.get_tecnicos_catalog() 
    tipos_tarea_catalog = db.get_tipos_tarea_catalog() 
    prioridades_catalog = db.get_prioridades_catalog() 
    estados_ticket_catalog = db.get_estados_ticket_catalog() 

    # --- Crear Ticket ---
    st.subheader("Crear Nuevo Ticket")
    with st.form("add_ticket_form", clear_on_submit=True):
        st.write("**Información del Ticket**")
        numero_ticket = st.text_input("Número de Ticket", help="Ej: TK-001", key="ticket_numero")

        cliente_seleccionado_id = st.selectbox(
            "Cliente",
            options=list(clientes_catalog_dict.keys()), 
            format_func=lambda x: clientes_catalog_dict.get(x, "Selecciona un cliente"),
            key="ticket_cliente"
        )

        tecnico_asignado_id = st.selectbox(
            "Técnico Asignado",
            options=[None] + list(tecnicos_catalog.keys()), 
            format_func=lambda x: "Sin asignar" if x is None else tecnicos_catalog.get(x, "Desconocido"),
            key="ticket_tecnico_asignado"
        )

        tipo_tarea_id = st.selectbox(
            "Tipo de Tarea",
            options=list(tipos_tarea_catalog.keys()),
            format_func=lambda x: tipos_tarea_catalog.get(x, "Selecciona un tipo"),
            key="ticket_tipo_tarea"
        )

        prioridad_id = st.selectbox(
            "Prioridad",
            options=list(prioridades_catalog.keys()),
            format_func=lambda x: prioridades_catalog.get(x, "Selecciona prioridad"),
            key="ticket_prioridad"
        )

        estado_id = st.selectbox(
            "Estado",
            options=list(estados_ticket_catalog.keys()),
            format_func=lambda x: estados_ticket_catalog.get(x, "Selecciona estado"),
            key="ticket_estado"
        )

        titulo = st.text_input("Título del Ticket", key="ticket_titulo")
        descripcion = st.text_area("Descripción", key="ticket_descripcion")
        tiempo_estimado_horas = st.number_input("Tiempo Estimado (horas)", min_value=0.0, step=0.1, format="%.2f", key="ticket_tiempo_estimado")

        submitted_add = st.form_submit_button("Crear Ticket")

        if submitted_add:
            if not all([numero_ticket, cliente_seleccionado_id, tipo_tarea_id, prioridad_id, estado_id, titulo]):
                st.error("Por favor, complete los campos obligatorios (Número de Ticket, Cliente, Tipo Tarea, Prioridad, Estado, Título).")
            else:
                if db.add_ticket(numero_ticket, cliente_seleccionado_id, tecnico_asignado_id, tipo_tarea_id, prioridad_id, estado_id, titulo, descripcion, tiempo_estimado_horas):
                    display_message("Ticket creado con éxito.", "success")
                    st.experimental_rerun()
                else:
                    display_message("Error al crear ticket. Verifique el número de ticket (debe ser único).", "error")

    st.markdown("---")

    # --- Listar Tickets ---
    st.subheader("Listado de Tickets")
    tickets_data = db.get_tickets()
    tickets_df = pd.DataFrame(tickets_data)

    if not tickets_df.empty:
        for col in ['fecha_creacion']: 
            if col in tickets_df.columns:
                tickets_df[col] = pd.to_datetime(tickets_df[col]).dt.strftime('%Y-%m-%d %H:%M')

        columnas_esperadas_lista = ['numero_ticket', 'nombre_empresa', 'tecnico_asignado', 'tipo_tarea', 'prioridad', 'estado', 'titulo', 'fecha_creacion']
        
        # --- DEPURACIÓN: Verificar qué columnas están realmente disponibles ---
        print("\n--- Columnas en tickets_df (Listado de Tickets) ---")
        if not tickets_df.empty:
            print(tickets_df.columns.tolist())
        else:
            print("DataFrame de tickets está vacío.")
        print("--- Fin de columnas ---")
        # --- Fin de Depuración ---

        columnas_presentes_lista = [col for col in columnas_esperadas_lista if col in tickets_df.columns]
        
        if len(columnas_presentes_lista) == len(columnas_esperadas_lista):
            st.dataframe(tickets_df[columnas_esperadas_lista], use_container_width=True)
        else:
            st.warning("No todas las columnas esperadas están presentes en el listado de tickets.")
            st.write("Columnas disponibles:")
            st.write(tickets_df.columns.tolist()) 
            if columnas_presentes_lista:
                st.dataframe(tickets_df[columnas_presentes_lista], use_container_width=True)

        # --- Editar/Eliminar Ticket ---
        st.subheader("Acciones sobre Tickets")
        with st.expander("Editar/Eliminar Ticket"):
            
            # Primero, verifica si 'id_ticket' está en el DataFrame antes de usarlo
            if 'id_ticket' in tickets_df.columns:
                ticket_ids = tickets_df['id_ticket'].tolist()
                
                if ticket_ids:
                    ticket_display_map = {}
                    for index, row in tickets_df.iterrows():
                        display_text = f"Ticket ID {row['id_ticket']}" 
                        if 'numero_ticket' in row and 'titulo' in row:
                            display_text = f"{row['numero_ticket']} - {row['titulo']}"
                        elif 'numero_ticket' in row:
                            display_text = f"{row['numero_ticket']} (ID: {row['id_ticket']})"
                        
                        ticket_display_map[row['id_ticket']] = display_text

                    ticket_id_to_manage = st.selectbox(
                        "Selecciona un ticket para editar/eliminar",
                        options=ticket_ids,
                        format_func=lambda x: ticket_display_map.get(x, f"Ticket ID {x}"), 
                        key="manage_ticket_select"
                    )

                    if ticket_id_to_manage:
                        ticket_data = db.get_ticket_by_id(ticket_id_to_manage)
                        if ticket_data:
                            with st.form(f"edit_ticket_form_{ticket_id_to_manage}", clear_on_submit=False):
                                st.write(f"**Editando Ticket: {ticket_data.get('numero_ticket', 'N/A')}**")

                                edit_numero_ticket = st.text_input("Número de Ticket", value=ticket_data.get('numero_ticket', ''), key=f"edit_tk_numero_{ticket_id_to_manage}")

                                # --- Selectores de Edición ---
                                edit_cliente_id = st.selectbox(
                                    "Cliente",
                                    options=list(clientes_catalog_dict.keys()),
                                    index=list(clientes_catalog_dict.keys()).index(ticket_data['id_cliente']) if ticket_data['id_cliente'] in clientes_catalog_dict else 0,
                                    format_func=lambda x: clientes_catalog_dict.get(x, "Selecciona un cliente"),
                                    key=f"edit_tk_cliente_{ticket_id_to_manage}"
                                )

                                edit_tecnico_id = st.selectbox(
                                    "Técnico Asignado",
                                    options=[None] + list(tecnicos_catalog.keys()),
                                    index=([None] + list(tecnicos_catalog.keys())).index(ticket_data['id_tecnico_asignado']) if (ticket_data['id_tecnico_asignado'] in tecnicos_catalog or ticket_data['id_tecnico_asignado'] is None) else 0,
                                    format_func=lambda x: "Sin asignar" if x is None else tecnicos_catalog.get(x, "Desconocido"),
                                    key=f"edit_tk_tecnico_{ticket_id_to_manage}"
                                )

                                edit_tipo_tarea_id = st.selectbox(
                                    "Tipo de Tarea",
                                    options=list(tipos_tarea_catalog.keys()),
                                    index=list(tipos_tarea_catalog.keys()).index(ticket_data['id_tipo_tarea']) if ticket_data['id_tipo_tarea'] in tipos_tarea_catalog else 0,
                                    format_func=lambda x: tipos_tarea_catalog.get(x, "Selecciona un tipo"),
                                    key=f"edit_tk_tipo_tarea_{ticket_id_to_manage}"
                                )

                                edit_prioridad_id = st.selectbox(
                                    "Prioridad",
                                    options=list(prioridades_catalog.keys()),
                                    index=list(prioridades_catalog.keys()).index(ticket_data['id_prioridad']) if ticket_data['id_prioridad'] in prioridades_catalog else 0,
                                    format_func=lambda x: prioridades_catalog.get(x, "Selecciona prioridad"),
                                    key=f"edit_tk_prioridad_{ticket_id_to_manage}"
                                )

                                edit_estado_id = st.selectbox(
                                    "Estado",
                                    options=list(estados_ticket_catalog.keys()),
                                    index=list(estados_ticket_catalog.keys()).index(ticket_data['id_estado']) if ticket_data['id_estado'] in estados_ticket_catalog else 0,
                                    format_func=lambda x: estados_ticket_catalog.get(x, "Selecciona estado"),
                                    key=f"edit_tk_estado_{ticket_id_to_manage}"
                                )

                                edit_titulo = st.text_input("Título del Ticket", value=ticket_data.get('titulo', ''), key=f"edit_tk_titulo_{ticket_id_to_manage}")
                                edit_descripcion = st.text_area("Descripción", value=ticket_data.get('descripcion', ''), key=f"edit_tk_descripcion_{ticket_id_to_manage}")
                                
                                edit_fecha_asignacion_str = st.text_input("Fecha de Asignación (YYYY-MM-DD HH:MM:SS)", value=ticket_data.get('fecha_asignacion', '') or "", key=f"edit_tk_fecha_asignacion_{ticket_id_to_manage}")
                                edit_fecha_cierre_str = st.text_input("Fecha de Cierre (YYYY-MM-DD HH:MM:SS)", value=ticket_data.get('fecha_cierre', '') or "", key=f"edit_tk_fecha_cierre_{ticket_id_to_manage}")
                                edit_tiempo_estimado = st.number_input("Tiempo Estimado (horas)", value=ticket_data.get('tiempo_estimado_horas', 0.0) or 0.0, min_value=0.0, step=0.1, format="%.2f", key=f"edit_tk_tiempo_{ticket_id_to_manage}")

                                col1, col2 = st.columns(2)
                                with col1:
                                    submitted_edit = st.form_submit_button("Guardar Cambios")
                                with col2:
                                    submitted_delete = st.form_submit_button("Eliminar Ticket")

                                if submitted_edit:
                                    fecha_asignacion = None
                                    if edit_fecha_asignacion_str:
                                        try:
                                            fecha_asignacion = datetime.strptime(edit_fecha_asignacion_str, "%Y-%m-%d %H:%M:%S")
                                        except ValueError:
                                            st.error("Formato de Fecha de Asignación inválido. Use YYYY-MM-DD HH:MM:SS.")
                                            st.stop() 

                                    fecha_cierre = None
                                    if edit_fecha_cierre_str:
                                        try:
                                            fecha_cierre = datetime.strptime(edit_fecha_cierre_str, "%Y-%m-%d %H:%M:%S")
                                        except ValueError:
                                            st.error("Formato de Fecha de Cierre inválido. Use YYYY-MM-DD HH:MM:SS.")
                                            st.stop()

                                    if not all([edit_numero_ticket, edit_cliente_id, edit_tipo_tarea_id, edit_prioridad_id, edit_estado_id, edit_titulo]):
                                        st.error("Por favor, complete los campos obligatorios.")
                                    else:
                                        if db.update_ticket(ticket_id_to_manage, edit_numero_ticket, edit_cliente_id, edit_tecnico_id, edit_tipo_tarea_id, edit_prioridad_id, edit_estado_id, edit_titulo, edit_descripcion, fecha_asignacion, fecha_cierre, edit_tiempo_estimado):
                                            display_message("Ticket actualizado con éxito.", "success")
                                            st.experimental_rerun()
                                        else:
                                            display_message("Error al actualizar ticket. Verifique el número de ticket.", "error")

                                if submitted_delete:
                                    if st.button("Confirmar Eliminación", key=f"confirm_delete_ticket_{ticket_id_to_manage}"):
                                        if db.delete_ticket(ticket_id_to_manage):
                                            display_message("Ticket eliminado con éxito.", "success")
                                            st.experimental_rerun()
                                        else:
                                            display_message("Error al eliminar ticket.", "error")
                        else:
                            st.error(f"No se pudieron cargar los datos del ticket con ID {ticket_id_to_manage}.")
            else:
                st.error("La columna 'id_ticket' no está disponible en los datos de tickets.")
                st.write("Verifica la consulta SQL en `database.py` (función `get_tickets`) y los nombres de las columnas devueltas.")
                st.write("Columnas disponibles:")
                st.write(tickets_df.columns.tolist())


# --- BLOQUE FINAL ELSE ---
# Este bloque maneja cualquier selección de menú que no sea una de las opciones anteriores.
# Asegúrate de que esté al mismo nivel de indentación que el 'if' y los 'elif' principales.
else: 
    st.title("Página no encontrada")
    st.warning("Selecciona una opción en la barra lateral.")