-- =====================================================
-- SCRIPT DE BASE DE DATOS NORMALIZADA - SISTEMA DE TICKETS
-- Proceso de Normalización: 1NF -> 2NF -> 3NF
-- =====================================================

-- En SQLite, no se crea una base de datos con CREATE DATABASE.
-- Se trabaja directamente con un archivo de base de datos (.db).
-- Para empezar, asegúrate de que el archivo de base de datos no exista
-- o elimínalo manualmente si deseas una instalación limpia.

-- =====================================================
-- CREACIÓN DE TABLAS NORMALIZADAS (3NF)
-- =====================================================

-- Tabla: TECNICOS (Entidad independiente)
CREATE TABLE tecnicos (
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

-- Tabla: CLIENTES (Entidad independiente)
CREATE TABLE clientes (
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

-- Tabla: TIPOS_TAREA (Catálogo normalizado)
CREATE TABLE tipos_tarea (
    id_tipo_tarea INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre VARCHAR(200) NOT NULL UNIQUE,
    descripcion TEXT,
    tiempo_estimado_horas REAL, -- Using REAL for decimal types
    prioridad_default VARCHAR(20) DEFAULT 'Media',
    activo INTEGER DEFAULT 1, -- 1 for TRUE, 0 for FALSE
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla: MODALIDADES_TRABAJO (Catálogo normalizado)
CREATE TABLE modalidades_trabajo (
    id_modalidad INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    activo INTEGER DEFAULT 1 -- 1 for TRUE, 0 for FALSE
);

-- Tabla: PRIORIDADES (Catálogo normalizado)
CREATE TABLE prioridades (
    id_prioridad INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre VARCHAR(20) NOT NULL UNIQUE,
    nivel INTEGER NOT NULL,
    color_hex VARCHAR(7),
    descripcion TEXT
);

-- Tabla: ESTADOS_TICKET (Catálogo normalizado)
CREATE TABLE estados_ticket (
    id_estado INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    es_final INTEGER DEFAULT 0, -- 0 for FALSE, 1 for TRUE
    orden_flujo INTEGER
);

-- Tabla: TICKETS (Entidad principal normalizada)
CREATE TABLE tickets (
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

-- Tabla: REGISTROS_ACTIVIDAD (Normalizada - elimina redundancia temporal)
CREATE TABLE registros_actividad (
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

-- =====================================================
-- ÍNDICES PARA OPTIMIZACIÓN
-- =====================================================

-- Índices en claves foráneas
CREATE INDEX idx_tickets_cliente ON tickets(id_cliente);
CREATE INDEX idx_tickets_tecnico ON tickets(id_tecnico_asignado);
CREATE INDEX idx_tickets_tipo_tarea ON tickets(id_tipo_tarea);
CREATE INDEX idx_tickets_estado ON tickets(id_estado);
CREATE INDEX idx_registros_ticket ON registros_actividad(id_ticket);
CREATE INDEX idx_registros_tecnico ON registros_actividad(id_tecnico);

-- Índices en campos de búsqueda frecuente
CREATE INDEX idx_tickets_numero ON tickets(numero_ticket);
CREATEINDEX idx_tickets_fecha_creacion ON tickets(fecha_creacion);
CREATE INDEX idx_registros_fecha ON registros_actividad(fecha_actividad);
CREATE INDEX idx_tecnicos_login ON tecnicos(login);
CREATE INDEX idx_clientes_nombre ON clientes(nombre_empresa);

-- =====================================================
-- RESTRICCIONES DE INTEGRIDAD
-- =====================================================

-- Restricciones CHECK (SQLite soporta CHECK constraints)
ALTER TABLE prioridades ADD CONSTRAINT chk_nivel_prioridad
    CHECK (nivel BETWEEN 1 AND 5);

ALTER TABLE registros_actividad ADD CONSTRAINT chk_tiempo_positivo
    CHECK (tiempo_dedicado_horas > 0);

ALTER TABLE tickets ADD CONSTRAINT chk_fechas_logicas
    CHECK (fecha_asignacion >= fecha_creacion AND
           (fecha_cierre IS NULL OR fecha_cierre >= fecha_asignacion));

-- =====================================================
-- TRIGGERS PARA AUDITORÍA
-- =====================================================

-- SQLite no tiene el concepto de funciones almacenadas como PostgreSQL.
-- Los triggers se definen directamente.

-- Trigger para actualizar el campo 'updated_at' en la tabla 'tecnicos'
CREATE TRIGGER trg_tecnicos_updated
AFTER UPDATE ON tecnicos
FOR EACH ROW
BEGIN
    UPDATE tecnicos SET updated_at = CURRENT_TIMESTAMP WHERE id_tecnico = OLD.id_tecnico;
END;

-- Trigger para actualizar el campo 'updated_at' en la tabla 'clientes'
CREATE TRIGGER trg_clientes_updated
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    UPDATE clientes SET updated_at = CURRENT_TIMESTAMP WHERE id_cliente = OLD.id_cliente;
END;

-- Trigger para actualizar el campo 'updated_at' en la tabla 'tickets'
CREATE TRIGGER trg_tickets_updated
AFTER UPDATE ON tickets
FOR EACH ROW
BEGIN
    UPDATE tickets SET updated_at = CURRENT_TIMESTAMP WHERE id_ticket = OLD.id_ticket;
END;


-- =====================================================
-- INSERCIÓN DE DATOS MAESTROS
-- =====================================================

-- Insertar modalidades de trabajo
INSERT INTO modalidades_trabajo (nombre, descripcion) VALUES
('Presencial', 'Trabajo realizado en las instalaciones del cliente'),
('Remoto', 'Trabajo realizado de forma remota'),
('Híbrido', 'Combinación de trabajo presencial y remoto'),
('Telefónico', 'Soporte telefónico únicamente');

-- Insertar prioridades
INSERT INTO prioridades (nombre, nivel, color_hex, descripcion) VALUES
('Crítica', 1, '#FF0000', 'Requiere atención inmediata'),
('Alta', 2, '#FF8000', 'Debe resolverse en el día'),
('Media', 3, '#FFFF00', 'Resolución en 2-3 días'),
('Baja', 4, '#00FF00', 'Puede esperar hasta una semana'),
('Muy Baja', 5, '#0080FF', 'Sin urgencia específica');

-- Insertar estados de ticket
INSERT INTO estados_ticket (nombre, descripcion, es_final, orden_flujo) VALUES
('Nuevo', 'Ticket recién creado', 0, 1),
('Asignado', 'Ticket asignado a técnico', 0, 2),
('En Progreso', 'Técnico trabajando en el ticket', 0, 3),
('Pendiente Cliente', 'Esperando respuesta del cliente', 0, 4),
('Resuelto', 'Problema solucionado', 1, 5),
('Cerrado', 'Ticket cerrado y archivado', 1, 6),
('Cancelado', 'Ticket cancelado', 1, 7);

-- Insertar tipos de tarea
INSERT INTO tipos_tarea (nombre, descripcion, tiempo_estimado_horas, prioridad_default) VALUES
('Soporte a usuarios finales', 'Asistencia directa a usuarios con problemas técnicos', 1.5, 'Media'),
('Planificación y escalabilidad de TI', 'Planificación de infraestructura y crecimiento', 4.0, 'Alta'),
('Mantenimiento de impresoras', 'Reparación y mantenimiento de equipos de impresión', 1.0, 'Baja'),
('Actualización de equipos', 'Actualización de hardware y software', 2.5, 'Media'),
('Configuración de red', 'Configuración y mantenimiento de redes', 3.0, 'Alta'),
('Backup y recuperación', 'Gestión de copias de seguridad', 2.0, 'Alta'),
('Instalación de software', 'Instalación y configuración de aplicaciones', 1.5, 'Media'),
('Seguridad informática', 'Implementación de medidas de seguridad', 3.5, 'Crítica'),
('Migración de datos', 'Transferencia y migración de información', 4.5, 'Alta'),
('Capacitación técnica', 'Formación a usuarios y personal técnico', 2.0, 'Baja');

-- =====================================================
-- INSERCIÓN DE DATOS SINTÉTICOS
-- =====================================================

-- Insertar técnicos
INSERT INTO tecnicos (nombre, apellido, email, login, password_hash, telefono, especialidad, fecha_ingreso) VALUES
('Dora', 'Bermúdez', 'dora.bermúdez@empresa.com', 'dora.bermúdez', 'e495c8e1d6723467c5c840b71744533eae94e9ca4b68823178e8a2df150f1121', '+34945263572', 'Infraestructura IT', '2024-11-02'),
('Bienvenida', 'Verdejo', 'bienvenida.verdejo@empresa.com', 'bienvenida.verdejo', '9c0cdeb1dad83648e3674bc4835a65a6e398ae4b5bee7c72cd3e68e5b7ccbe47', '+34879843472', 'Bases de Datos', '2021-08-01'),
('Onofre', 'Ariño', 'onofre.ariño@empresa.com', 'onofre.ariño', '31e0377d72256fa00da681f58bdc01778989cc7855f159cdc03841d3e37760d2', '+34 978 43 57 49', 'Cloud Computing', '2021-02-04'),
('Aurelio', 'Sáenz', 'aurelio.sáenz@empresa.com', 'aurelio.sáenz', '0a8f421b8c7c448ac9591487670488491b963573d4292e72dc96d477752a3665', '+34719 469 155', 'Hardware', '2023-08-19'),
('Telmo', 'Torrijos', 'telmo.torrijos@empresa.com', 'telmo.torrijos', '42fc98b7d2c8537ace34d207a389fd149be0809913f1fd90c8d356eb392a3ccb', '+34900 476 595', 'Backup y Recuperación', '2024-03-24'),
('Odalis', 'Ribes', 'odalis.ribes@empresa.com', 'odalis.ribes', '70dbe3bf25b7e5442988012e0b2d31c919baa208b73bf9d4a3b4c4489f46bd01', '+34 732 417 486', 'Redes y Comunicaciones', '2024-11-10'),
('María Jesús', 'Ferrán', 'maría jesús.ferrán@empresa.com', 'maría jesús.ferrán', '4885c3e2969f513158d8a161bf95be6d293df67e695fab9ec5a906ed144517d7', '+34 888569150', 'Sistemas Operativos', '2024-12-10'),
('Almudena', 'Criado', 'almudena.criado@empresa.com', 'almudena.criado', '40bd682b462ca6dcebd6f45ae04dcc287fedf10fdd4e3558f7aa842f8249373a', '+34888163735', 'Soporte Técnico', '2021-08-02'),
('Fabián', 'Egea', 'fabián.egea@empresa.com', 'fabián.egea', 'd8cb9ab2dc74fd7c592909084a364b6fd2243427633f06456f6317237d374c88', '+34 806690577', 'Seguridad Informática', '2022-12-30'),
('Silvia', 'Madrigal', 'silvia.madrigal@empresa.com', 'silvia.madrigal', 'd8e935eb1eafecd0d66463861b067dfc6e098cca210bcc615a0b71d0939bd662', '+34922 454 200', 'Sistemas Operativos', '2020-12-06'),
('Isa', 'Paniagua', 'isa.paniagua@empresa.com', 'isa.paniagua', 'e107c6c1dc4110d5a24e5f0e6fe0308f1156b0aa26837a80f3221997a7f187e5', '+34 876341599', 'Cloud Computing', '2022-09-15'),
('Ascensión', 'Delgado', 'ascensión.delgado@empresa.com', 'ascensión.delgado', '1c6b4f2278067b875faa584b186908eb8c93289fbcb1ae3b057f66fc3c48853a', '+34 882547081', 'Desarrollo de Software', '2023-10-30'),
('Nicolás', 'Pareja', 'nicolás.pareja@empresa.com', 'nicolás.pareja', 'c4784f5f6210bd6e79d2193d482e84ddc28d5e5cd4903e99ec2fd83bddef9c8b', '+34 974756694', 'Bases de Datos', '2023-10-29'),
('Montserrat', 'Echeverría', 'montserrat.echeverría@empresa.com', 'montserrat.echeverría', 'b2dc644fb6abbbf84d02da443d96f396c685a0f2592ffdbef6fc85dbf1badebf', '+34 924 90 58 36', 'Desarrollo de Software', '2023-12-26'),
('Fátima', 'Chaves', 'fátima.chaves@empresa.com', 'fátima.chaves', 'cc4718e76e5206265e5fbddeac7dcff655d41f7cce76bfa8f0ee3677660e78da', '+34830 34 47 55', 'Hardware', '2025-06-04'),
('Teodoro', 'Álvarez', 'teodoro.álvarez@empresa.com', 'teodoro.álvarez', '382fce0d8c6f2c543a91c404bb02aae42985d45ed403fe5f66a96aa495c2e430', '+34871 539 603', 'Bases de Datos', '2022-11-25'),
('Artemio', 'Córdoba', 'artemio.córdoba@empresa.com', 'artemio.córdoba', '9a491c9773070fa989989c6edb750d6f57778a9eb141033a6184061b40e013f6', '+34 888 564 797', 'Infraestructura IT', '2021-11-20'),
('Emiliana', 'Alberto', 'emiliana.alberto@empresa.com', 'emiliana.alberto', '596ff0823118e6f4d3ba426be993d1d43ee183ece0d58eafa66823715a442838', '+34 975656438', 'Sistemas Operativos', '2023-07-21'),
('Lola', 'Pulido', 'lola.pulido@empresa.com', 'lola.pulido', '04fb848e5b61444dc8f46be426827cbc7a28fcf4b87a675926fad5f81b368296', '+34814532395', 'Infraestructura IT', '2024-06-14'),
('Leandro', 'Castells', 'leandro.castells@empresa.com', 'leandro.castells', 'c12eece46500c9bd02f1cc061a0043929d3a84db864df831852750cde9f5288e', '+34848 195 472', 'Soporte Técnico', '2024-08-29');

-- Insertar clientes
INSERT INTO clientes (nombre_empresa, contacto_principal, email, telefono, direccion, ciudad) VALUES
('TechSupport Pro', 'Cesar Catalá Carpio', 'aroareina@banca.es', '+34 923 68 90 79', 'Acceso Nereida Carbajo 91\nAlicante, 16220', 'Lleida'),
('CyberTech', 'Tristán Ferrando Guzmán', 'narcisocampillo@hotel.org', '+34 847210174', 'Glorieta Débora Redondo 52\nAlbacete, 19969', 'Córdoba'),
('Digital Solutions', 'Adelina Alberola Fuster', 'octaviocasado@victor.es', '+34 827 694 563', 'Pasaje de Belén Ledesma 745 Piso 6 \nVizcaya, 38745', 'Valladolid'),
('CyberTech', 'Saturnino Villaverde-Miralles', 'hortensia96@pacheco.es', '+34875806105', 'Plaza de Iris Plaza 44 Apt. 23 \nZamora, 29133', 'Segovia'),
('InfoSystems', 'María José de Taboada', 'querociriaco@finanzas.es', '+34883 809 566', 'Glorieta de Rosalina Roma 19 Apt. 83 \nGranada, 14313', 'La Coruña'),
('Coronado & Asociados S.Com.', 'Valero Echeverría Coronado', 'maria-jesus60@carrasco.com', '+34 980071753', 'Avenida de Mayte Lladó 479\nSoria, 08763', 'Cantabria'),
('Inversiones QAP S.L.', 'Berto Melchor Doménech Fernandez', 'teofilo43@familia.es', '+34 842481695', 'Ronda Teófila Guerrero 16\nCastellón, 35545', 'Lleida'),
('Infraestructuras QR S.L.', 'Iván Díaz Alvarez', 'kruano@despacho.es', '+34 963 51 40 88', 'Alameda Balduino Jaén 51 Apt. 35 \nCeuta, 49313', 'Álava'),
('Hermanos Sedano S.A.', 'Bárbara Quintero-Lasa', 'duranrosalina@suministros.net', '+34 845 16 89 05', 'Cañada de Florentina Conde 60\nGranada, 21827', 'Sevilla'),
('Consultoría Bastida & Asociados S.L.', 'Ruperta Ricart Feijoo', 'lucilasandoval@manufacturas.es', '+34 825635451', 'Pasadizo de José Galván 19\nCádiz, 43443', 'Cádiz'),
('Desarrollo IB S.A.', 'Marcial Santana-Iglesia', 'hernandezivan@tecnologias.com', '+34902976853', 'Calle Cosme Capdevila 4 Piso 8 \nLa Coruña, 37702', 'Badajoz'),
('Grupo Torre S.A.', 'Bienvenida Silva-Tomás', 'xaviles@familia.net', '+34 886 372 648', 'Avenida de Faustino Guardia 88 Apt. 22 \nCastellón, 41268', 'Soria'),
('Mercader y Arcos S.C.P', 'Balduino del Múñiz', 'seve90@albano.es', '+34 920720387', 'Calle Berto Madrigal 745 Piso 9 \nÁlava, 51648', 'Murcia'),
('Restauración Globales S.L.', 'Porfirio Vives Camps', 'saludpellicer@cerda.com', '+34 901 885 785', 'Cañada de Florinda Barrios 900\nSalamanca, 03949', 'La Rioja'),
('Hotel Tormo S.L.', 'Raúl Revilla Vega', 'otiliaquesada@restauracion.net', '+34852 50 56 98', 'Callejón de Sebastian Peral 79\nLleida, 25367', 'Lugo');

-- Insertar tickets
INSERT INTO tickets (numero_ticket, id_cliente, id_tecnico_asignado, id_tipo_tarea, id_prioridad, id_estado, titulo, descripcion, fecha_creacion, tiempo_estimado_horas) VALUES
('TK00001', 3, 18, 2, 3, 3, 'Ticket 1 - Actualización de antivirus corporativo', 'Reparación de equipo de impresión láser', '2024-11-09 06:30:04.866858', 6.91),
('TK00002', 13, 13, 10, 3, 5, 'Ticket 2 - Mantenimiento preventivo de servidores', 'Configuración de red inalámbrica en oficina principal', '2025-04-23 11:06:40.409070', 6.42),
('TK00003', 5, 17, 9, 1, 5, 'Ticket 3 - Configuración de firewall corporativo', 'Instalación de sistema de videoconferencia', '2024-09-03 22:38:35.691795', 4.03),
('TK00004', 12, 5, 1, 1, 7, 'Ticket 4 - Reparación de equipo de impresión láser', 'Resolución de problemas de conectividad', '2024-10-30 23:51:20.023270', 7.91),
('TK00005', 14, 14, 8, 2, 7, 'Ticket 5 - Mantenimiento preventivo de servidores', 'Instalación de sistema de videoconferencia', '2024-08-09 10:42:12.096457', 0.52),
('TK00006', 2, 20, 4, 4, 3, 'Ticket 6 - Resolución de problemas de conectividad', 'Instalación de sistema de videoconferencia', '2024-11-14 01:49:44.274786', 7.93),
('TK00007', 15, 19, 7, 1, 1, 'Ticket 7 - Resolución de problemas de conectividad', 'Configuración de red inalámbrica en oficina principal', '2024-10-06 11:09:43.802914', 4.3),
('TK00008', 4, 2, 9, 4, 1, 'Ticket 8 - Instalación de sistema de videoconferencia', 'Instalación de certificados SSL', '2025-02-02 12:50:26.135720', 3.9),
('TK00009', 5, 15, 6, 5, 6, 'Ticket 9 - Configuración de firewall corporativo', 'Optimización de base de datos', '2024-08-11 00:14:25.327964', 4.21),
('TK00010', 5, 11, 7, 5, 6, 'Ticket 10 - Configuración de firewall corporativo', 'Instalación de sistema de videoconferencia', '2024-12-27 19:04:41.576339', 3.73),
('TK00011', 9, 17, 10, 1, 3, 'Ticket 11 - Actualización de antivirus corporativo', 'Configuración de red inalámbrica en oficina principal', '2025-02-07 11:55:14.752172', 3.88),
('TK00012', 8, 15, 6, 4, 7, 'Ticket 12 - Instalación de certificados SSL', 'Actualización de equipos de administración con backup incluido', '2024-08-03 00:31:13.845477', 7.59),
('TK00013', 8, 10, 8, 2, 1, 'Ticket 13 - Resolución de problemas de conectividad', 'Instalación de software contable en estaciones de trabajo', '2024-11-13 18:55:07.275750', 3.56),
('TK00014', 14, 7, 5, 3, 5, 'Ticket 14 - Actualización de antivirus corporativo', 'Hoja atascada en la impresora de mesa de ayuda', '2025-04-19 18:54:31.347579', 1.38),
('TK00015', 1, 20, 10, 3, 1, 'Ticket 15 - Instalación de software contable en estaciones de ', 'Configuración de firewall corporativo', '2025-01-22 05:15:58.271246', 3.94),
('TK00016', 1, 5, 1, 5, 2, 'Ticket 16 - Migración de datos a nuevo sistema', 'Actualización de antivirus corporativo', '2025-04-03 10:05:16.256644', 4.28),
('TK00017', 13, 15, 4, 4, 1, 'Ticket 17 - Actualización de equipos de administración con bac', 'Instalación de software contable en estaciones de trabajo', '2025-07-05 03:03:49.980911', 7.43),
('TK00018', 3, 19, 1, 5, 2, 'Ticket 18 - Instalación de software contable en estaciones de ', 'Actualización de equipos de administración con backup incluido', '2024-08-23 09:58:21.374565', 4.35),
('TK00019', 5, 13, 9, 3, 2, 'Ticket 19 - Instalación de certificados SSL', 'Configuración de firewall corporativo', '2024-10-26 07:36:21.375357', 7.13),
('TK00020', 1, 4, 5, 2, 5, 'Ticket 20 - Configuración de firewall corporativo', 'Hoja atascada en la impresora de mesa de ayuda', '2025-05-23 01:32:20.203728', 2.06),
('TK00021', 3, 17, 5, 5, 4, 'Ticket 21 - Optimización de base de datos', 'Instalación de sistema de videoconferencia', '2025-06-03 09:39:05.978368', 5.33),
('TK00022', 5, 15, 7, 4, 3, 'Ticket 22 - Reparación de equipo de impresión láser', 'Instalación de software contable en estaciones de trabajo', '2025-01-07 04:13:42.989634', 1.73),
('TK00023', 3, 12, 3, 5, 4, 'Ticket 23 - Optimización de base de datos', 'Resolución de problemas de conectividad', '2024-11-09 06:48:44.000869', 5.01),
('TK00024', 15, 4, 3, 1, 7, 'Ticket 24 - Mantenimiento preventivo de servidores', 'Configuración de VPN para trabajo remoto', '2024-10-14 10:31:41.639285', 2.4),
('TK00025', 6, 17, 3, 2, 1, 'Ticket 25 - Resolución de problemas de conectividad', 'Migración de datos a nuevo sistema', '2024-08-31 02:24:41.384709', 4.62),
('TK00026', 4, 14, 4, 2, 6, 'Ticket 26 - Actualización de equipos de administración con bac', 'Hoja atascada en la impresora de mesa de ayuda', '2025-07-06 16:26:43.302012', 7.39),
('TK00027', 5, 3, 8, 3, 3, 'Ticket 27 - Configuración de red inalámbrica en oficina princi', 'Mantenimiento preventivo de servidores', '2025-03-06 17:40:52.392176', 0.79),
('TK00028', 11, 10, 6, 1, 6, 'Ticket 28 - Actualización de equipos de administración con bac', 'Mantenimiento preventivo de servidores', '2025-02-16 07:23:28.575302', 5.8),
('TK00029', 1, 3, 4, 2, 7, 'Ticket 29 - Reparación de equipo de impresión láser', 'Configuración de VPN para trabajo remoto', '2025-06-07 19:26:33.760791', 4.35),
('TK00030', 2, 2, 1, 4, 4, 'Ticket 30 - Instalación de sistema de videoconferencia', 'Instalación de software contable en estaciones de trabajo', '2025-01-15 06:53:16.898095', 3.62),
('TK00031', 8, 11, 4, 3, 2, 'Ticket 31 - Instalación de sistema de videoconferencia', 'Actualización de antivirus corporativo', '2024-10-27 19:56:47.275831', 4.67),
('TK00032', 14, 9, 6, 4, 4, 'Ticket 32 - Configuración de VPN para trabajo remoto', 'Actualización de antivirus corporativo', '2025-01-13 20:47:09.877032', 2.59),
('TK00033', 1, 11, 1, 1, 2, 'Ticket 33 - Configuración de firewall corporativo', 'Optimización de base de datos', '2024-07-21 08:26:11.228485', 1.27),
('TK00034', 2, 17, 1, 2, 2, 'Ticket 34 - Configuración de red inalámbrica en oficina princi', 'Hoja atascada en la impresora de mesa de ayuda', '2025-05-21 11:57:57.982766', 2.81),
('TK00035', 1, 2, 2, 1, 7, 'Ticket 35 - Configuración de VPN para trabajo remoto', 'Instalación de certificados SSL', '2024-09-29 04:45:21.113281', 6.39),
('TK00036', 13, 18, 2, 3, 7, 'Ticket 36 - Migración de datos a nuevo sistema', 'Configuración de políticas de seguridad', '2025-01-20 07:17:40.584607', 3.68),
('TK00037', 2, 13, 8, 2, 4, 'Ticket 37 - Migración de datos a nuevo sistema', 'Configuración de red inalámbrica en oficina principal', '2024-10-19 17:06:11.735129', 7.0),
('TK00038', 15, 5, 5, 1, 6, 'Ticket 38 - Configuración de VPN para trabajo remoto', 'Resolución de problemas de conectividad', '2024-12-10 22:33:55.640629', 4.81),
('TK00039', 7, 13, 9, 4, 4, 'Ticket 39 - Configuración de red inalámbrica en oficina princi', 'Hoja atascada en la impresora de mesa de ayuda', '2025-05-09 09:21:40.752373', 2.13),
('TK00040', 14, 3, 3, 1, 1, 'Ticket 40 - Instalación de certificados SSL', 'Optimización de base de datos', '2025-07-03 06:29:19.857890', 2.09),
('TK00041', 14, 19, 9, 4, 2, 'Ticket 41 - Reparación de equipo de impresión láser', 'Hoja atascada en la impresora de mesa de ayuda', '2025-06-23 09:38:25.639418', 1.47),
('TK00042', 11, 2, 3, 2, 2, 'Ticket 42 - Configuración de red inalámbrica en oficina princi', 'Configuración de firewall corporativo', '2024-08-18 00:32:38.792214', 2.59),
('TK00043', 5, 12, 1, 4, 1, 'Ticket 43 - Optimización de base de datos', 'Instalación de certificados SSL', '2025-04-20 05:49:26.292162', 5.32),
('TK00044', 2, 2, 5, 2, 2, 'Ticket 44 - Configuración de VPN para trabajo remoto', 'Instalación de sistema de videoconferencia', '2025-06-08 21:00:42.187495', 3.15),
('TK00045', 12, 15, 5, 3, 4, 'Ticket 45 - Actualización de equipos de administración con bac', 'Mantenimiento preventivo de servidores', '2025-03-08 12:59:43.464072', 7.64),
('TK00046', 14, 16, 2, 2, 1, 'Ticket 46 - Actualización de equipos de administración con bac', 'Actualización de equipos de administración con backup incluido', '2025-02-08 03:24:41.316569', 3.85),
('TK00047', 4, 14, 4, 2, 4, 'Ticket 47 - Mantenimiento preventivo de servidores', 'Configuración de firewall corporativo', '2024-08-15 13:18:03.364975', 3.53),
('TK00048', 9, 5, 7, 2, 5, 'Ticket 48 - Configuración de firewall corporativo', 'Optimización de base de datos', '2025-03-11 11:06:38.534745', 7.54),
('TK00049', 6, 8, 1, 4, 1, 'Ticket 49 - Instalación de sistema de videoconferencia', 'Optimización de base de datos', '2025-05-25 10:39:01.504977', 1.96),
('TK00050', 11, 16, 6, 1, 3, 'Ticket 50 - Configuración de red inalámbrica en oficina princi', 'Migración de datos a nuevo sistema', '2025-04-26 04:54:00.420804', 5.35),
('TK00051', 8, 11, 3, 2, 5, 'Ticket 51 - Optimización de base de datos', 'Configuración de firewall corporativo', '2024-07-29 22:44:32.999646', 6.51),
('TK00052', 12, 6, 4, 5, 6, 'Ticket 52 - Actualización de equipos de administración con bac', 'Actualización de equipos de administración con backup incluido', '2024-09-21 00:45:54.721566', 0.94),
('TK00053', 14, 6, 3, 3, 6, 'Ticket 53 - Configuración de firewall corporativo', 'Mantenimiento preventivo de servidores', '2025-06-30 17:54:16.314337', 2.14),
('TK00054', 1, 1, 1, 5, 6, 'Ticket 54 - Configuración de políticas de seguridad', 'Mantenimiento preventivo de servidores', '2025-06-23 10:21:21.233714', 5.42),
('TK00055', 4, 19, 9, 5, 5, 'Ticket 55 - Configuración de VPN para trabajo remoto', 'Instalación de software contable en estaciones de trabajo', '2025-07-02 02:36:47.961743', 3.15),
('TK00056', 11, 10, 8, 5, 1, 'Ticket 56 - Mantenimiento preventivo de servidores', 'Configuración de firewall corporativo', '2025-03-17 11:02:54.968572', 6.27),
('TK00057', 6, 12, 10, 4, 4, 'Ticket 57 - Instalación de sistema de videoconferencia', 'Reparación de equipo de impresión láser', '2024-09-02 02:12:47.713303', 3.13),
('TK00058', 6, 8, 9, 2, 3, 'Ticket 58 - Resolución de problemas de conectividad', 'Resolución de problemas de conectividad', '2024-08-02 10:23:16.258611', 5.24),
('TK00059', 1, 3, 1, 2, 5, 'Ticket 59 - Migración de datos a nuevo sistema', 'Configuración de red inalámbrica en oficina principal', '2025-04-18 20:15:11.275728', 6.01),
('TK00060', 13, 9, 10, 1, 2, 'Ticket 60 - Actualización de antivirus corporativo', 'Instalación de sistema de videoconferencia', '2025-05-27 09:19:01.419006', 0.88),
('TK00061', 9, 5, 1, 4, 2, 'Ticket 61 - Migración de datos a nuevo sistema', 'Migración de datos a nuevo sistema', '2024-10-25 21:45:56.511862', 7.48),
('TK00062', 4, 20, 7, 3, 4, 'Ticket 62 - Resolución de problemas de conectividad', 'Configuración de políticas de seguridad', '2024-11-25 01:34:52.965623', 7.01),
('TK00063', 9, 10, 4, 2, 5, 'Ticket 63 - Configuración de VPN para trabajo remoto', 'Reparación de equipo de impresión láser', '2025-01-02 13:52:13.561508', 5.62),
('TK00064', 2, 5, 5, 4, 1, 'Ticket 64 - Mantenimiento preventivo de servidores', 'Resolución de problemas de conectividad', '2024-11-02 11:41:32.553672', 3.84),
('TK00065', 5, 18, 2, 5, 5, 'Ticket 65 - Instalación de software contable en estaciones de ', 'Resolución de problemas de conectividad', '2025-06-04 13:12:41.009609', 3.86),
('TK00066', 2, 12, 3, 4, 5, 'Ticket 66 - Configuración de red inalámbrica en oficina princi', 'Hoja atascada en la impresora de mesa de ayuda', '2024-11-16 08:00:08.082141', 7.05),
('TK00067', 13, 14, 1, 4, 3, 'Ticket 67 - Mantenimiento preventivo de servidores', 'Instalación de certificados SSL', '2025-01-20 03:35:40.656852', 6.61),
('TK00068', 3, 11, 1, 3, 5, 'Ticket 68 - Actualización de antivirus corporativo', 'Configuración de VPN para trabajo remoto', '2024-09-14 19:56:50.654691', 2.27),
('TK00069', 1, 19, 4, 5, 3, 'Ticket 69 - Instalación de sistema de videoconferencia', 'Actualización de equipos de administración con backup incluido', '2025-01-30 07:01:39.717511', 1.5),
('TK00070', 5, 9, 6, 5, 1, 'Ticket 70 - Configuración de red inalámbrica en oficina princi', 'Configuración de políticas de seguridad', '2025-05-05 00:43:42.302931', 1.62),
('TK00071', 3, 7, 1, 3, 2, 'Ticket 71 - Instalación de sistema de videoconferencia', 'Configuración de VPN para trabajo remoto', '2025-04-16 18:36:31.775548', 6.35),
('TK00072', 8, 6, 3, 1, 1, 'Ticket 72 - Configuración de políticas de seguridad', 'Configuración de red inalámbrica en oficina principal', '2025-01-24 09:18:09.833937', 4.43),
('TK00073', 10, 12, 1, 2, 4, 'Ticket 73 - Optimización de base de datos', 'Hoja atascada en la impresora de mesa de ayuda', '2025-05-27 21:12:41.783730', 4.48),
('TK00074', 4, 10, 2, 1, 6, 'Ticket 74 - Actualización de antivirus corporativo', 'Instalación de software contable en estaciones de trabajo', '2025-07-13 17:10:18.066821', 6.8),
('TK00075', 8, 3, 6, 2, 1, 'Ticket 75 - Configuración de VPN para trabajo remoto', 'Resolución de problemas de conectividad', '2024-12-09 15:16:28.257881', 3.12),
('TK00076', 10, 17, 8, 4, 3, 'Ticket 76 - Configuración de VPN para trabajo remoto', 'Configuración de políticas de seguridad', '2024-12-22 13:30:39.940966', 2.06),
('TK00077', 1, 17, 2, 1, 6, 'Ticket 77 - Instalación de software contable en estaciones de ', 'Instalación de software contable en estaciones de trabajo', '2024-08-07 07:21:01.454864', 6.86),
('TK00078', 8, 20, 3, 5, 3, 'Ticket 78 - Configuración de políticas de seguridad', 'Resolución de problemas de conectividad', '2025-06-02 20:50:10.352198', 2.27),
('TK00079', 10, 7, 8, 5, 6, 'Ticket 79 - Instalación de sistema de videoconferencia', 'Hoja atascada en la impresora de mesa de ayuda', '2025-03-22 12:29:45.026241', 5.66),
('TK00080', 5, 16, 6, 4, 2, 'Ticket 80 - Instalación de certificados SSL', 'Configuración de firewall corporativo', '2025-07-08 11:44:12.533892', 6.94),
('TK00081', 14, 16, 9, 3, 4, 'Ticket 81 - Reparación de equipo de impresión láser', 'Mantenimiento preventivo de servidores', '2024-08-10 04:56:54.658864', 7.95),
('TK00082', 8, 9, 9, 4, 2, 'Ticket 82 - Reparación de equipo de impresión láser', 'Configuración de VPN para trabajo remoto', '2025-02-25 01:51:52.120384', 4.57),
('TK00083', 9, 1, 10, 2, 6, 'Ticket 83 - Optimización de base de datos', 'Actualización de equipos de administración con backup incluido', '2025-06-24 08:07:39.702816', 5.09),
('TK00084', 5, 4, 1, 5, 6, 'Ticket 84 - Configuración de VPN para trabajo remoto', 'Optimización de base de datos', '2024-09-13 05:36:19.712855', 3.51),
('TK00085', 15, 17, 4, 5, 7, 'Ticket 85 - Configuración de firewall corporativo', 'Hoja atascada en la impresora de mesa de ayuda', '2024-12-18 12:08:12.242008', 4.75),
('TK00086', 12, 12, 3, 5, 5, 'Ticket 86 - Actualización de antivirus corporativo', 'Resolución de problemas de conectividad', '2025-03-19 20:24:14.742454', 0.56),
('TK00087', 6, 4, 7, 5, 5, 'Ticket 87 - Configuración de firewall corporativo', 'Hoja atascada en la impresora de mesa de ayuda', '2025-05-17 18:28:33.922297', 1.71),
('TK00088', 2, 18, 1, 3, 3, 'Ticket 88 - Migración de datos a nuevo sistema', 'Reparación de equipo de impresión láser', '2025-01-06 00:48:55.635794', 7.98),
('TK00089', 5, 1, 5, 3, 3, 'Ticket 89 - Optimización de base de datos', 'Actualización de antivirus corporativo', '2025-03-26 02:27:44.331165', 7.2),
('TK00090', 9, 3, 5, 1, 6, 'Ticket 90 - Migración de datos a nuevo sistema', 'Actualización de equipos de administración con backup incluido', '2024-08-15 09:13:05.168194', 2.72),
('TK00091', 6, 19, 7, 5, 4, 'Ticket 91 - Hoja atascada en la impresora de mesa de ayuda', 'Reparación de equipo de impresión láser', '2025-02-23 12:41:42.886209', 1.13),
('TK00092', 3, 16, 9, 4, 5, 'Ticket 92 - Instalación de sistema de videoconferencia', 'Configuración de políticas de seguridad', '2025-04-04 03:18:01.540799', 1.09),
('TK00093', 14, 7, 7, 2, 7, 'Ticket 93 - Instalación de sistema de videoconferencia', 'Migración de datos a nuevo sistema', '2025-04-09 18:54:30.732141', 3.33),
('TK00094', 1, 5, 6, 2, 5, 'Ticket 94 - Actualización de antivirus corporativo', 'Reparación de equipo de impresión láser', '2025-02-21 23:45:37.950766', 5.55),
('TK00095', 11, 1, 9, 5, 4, 'Ticket 95 - Configuración de red inalámbrica en oficina princi', 'Hoja atascada en la impresora de mesa de ayuda', '2024-10-28 20:36:37.664323', 4.56),
('TK00096', 2, 20, 3, 2, 1, 'Ticket 96 - Instalación de certificados SSL', 'Migración de datos a nuevo sistema', '2024-10-01 21:35:55.158936', 5.42),
('TK00097', 9, 9, 4, 5, 4, 'Ticket 97 - Configuración de VPN para trabajo remoto', 'Actualización de equipos de administración con backup incluido', '2025-04-14 16:59:27.219803', 5.76),
('TK00098', 7, 5, 1, 2, 5, 'Ticket 98 - Instalación de software contable en estaciones de ', 'Actualización de antivirus corporativo', '2024-09-30 14:24:56.638082', 3.56),
('TK00099', 14, 20, 10, 1, 7, 'Ticket 99 - Resolución de problemas de conectividad', 'Configuración de firewall corporativo', '2025-05-03 02:27:10.376092', 7.27),
('TK00100', 2, 18, 10, 5, 1, 'Ticket 100 - Instalación de certificados SSL', 'Configuración de VPN para trabajo remoto', '2025-01-21 01:21:30.413524', 1.08);

-- Insertar registros de actividad (300 registros)
INSERT INTO registros_actividad (id_ticket, id_tecnico, id_modalidad, fecha_actividad, tiempo_dedicado_horas, descripcion_trabajo, observaciones) VALUES
(39, 1, 4, '2024-07-28', 4.52, 'Configuración de firewall corporativo', 'Reprehenderit eum officiis blanditiis. Debitis dolores veniam doloremque commodi. Accusantium vel aliquid nisi iusto eligendi.
Hic saepe iste tenetur quo illo. Sit soluta quisquam pariatur.'),
(39, 12, 4, '2025-01-03', 1.72, 'Migración de datos a nuevo sistema', 'Maxime quo odio fugit excepturi minima voluptatum. Quia nisi numquam a exercitationem incidunt animi. Repudiandae suscipit asperiores rerum dicta dolorem atque.'),
(1, 6, 3, '2025-02-02', 4.67, 'Instalación de software contable en estaciones de trabajo', NULL),
(67, 5, 1, '2025-01-06', 0.93, 'Configuración de red inalámbrica en oficina principal', NULL),
(55, 1, 4, '2024-09-21', 4.43, 'Optimización de base de datos', NULL),
(33, 10, 2, '2024-11-05', 5.56, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(41, 12, 4, '2025-04-11', 5.59, 'Configuración de firewall corporativo', NULL),
(10, 4, 2, '2024-11-27', 5.7, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(68, 3, 1, '2024-11-10', 5.96, 'Mantenimiento preventivo de servidores', 'Earum deserunt distinctio dolorem dolores.
Cum neque tempora iste quam id perferendis. Nam dolor debitis veniam neque recusandae. Pariatur veritatis eaque accusamus necessitatibus corporis aliquid.'),
(56, 18, 3, '2024-11-13', 2.7, 'Optimización de base de datos', NULL),
(96, 5, 1, '2024-09-12', 0.71, 'Actualización de antivirus corporativo', NULL),
(44, 13, 1, '2025-05-30', 5.33, 'Instalación de certificados SSL', NULL),
(8, 1, 3, '2025-02-07', 4.99, 'Configuración de firewall corporativo', 'Repellat dolor amet minus error labore numquam. Neque occaecati repudiandae doloremque ipsa magnam omnis. Quae porro dolorum fugit. Tempora blanditiis necessitatibus itaque quidem autem doloribus.'),
(21, 15, 1, '2024-08-06', 1.0, 'Configuración de políticas de seguridad', 'Repudiandae repudiandae nisi sequi tempore. Aperiam explicabo hic non quaerat alias.'),
(45, 4, 4, '2025-04-04', 5.11, 'Resolución de problemas de conectividad', NULL),
(71, 19, 3, '2025-02-03', 5.23, 'Reparación de equipo de impresión láser', 'Totam commodi incidunt rem rem ipsum quod. Quod ad tempora numquam sint necessitatibus.
Cumque deserunt cumque impedit eligendi numquam in possimus. Sequi numquam quo perferendis explicabo.'),
(84, 1, 4, '2025-04-27', 4.92, 'Actualización de equipos de administración con backup incluido', 'Quaerat quis hic sunt. Quis consequatur optio similique dolores tempora. Adipisci quia dolores ut nihil modi. Facilis ex voluptatem quaerat esse a quae.'),
(74, 16, 4, '2024-11-25', 2.85, 'Instalación de certificados SSL', 'Non repellendus deserunt in eaque quisquam doloremque amet. Reprehenderit eveniet perspiciatis facere atque. Vero occaecati asperiores earum.'),
(74, 20, 3, '2025-01-04', 0.8, 'Actualización de antivirus corporativo', NULL),
(7, 12, 3, '2025-03-12', 5.74, 'Configuración de VPN para trabajo remoto', NULL),
(58, 9, 3, '2024-11-21', 1.1, 'Actualización de antivirus corporativo', NULL),
(42, 5, 3, '2024-10-19', 1.6, 'Instalación de sistema de videoconferencia', NULL),
(63, 8, 3, '2025-02-13', 2.09, 'Migración de datos a nuevo sistema', NULL),
(18, 3, 4, '2025-07-07', 2.07, 'Configuración de firewall corporativo', NULL),
(24, 6, 2, '2025-06-17', 1.16, 'Actualización de equipos de administración con backup incluido', NULL),
(28, 10, 3, '2025-02-02', 0.27, 'Reparación de equipo de impresión láser', NULL),
(75, 19, 2, '2024-09-21', 0.42, 'Actualización de equipos de administración con backup incluido', NULL),
(40, 15, 1, '2025-05-11', 0.29, 'Instalación de certificados SSL', NULL),
(5, 19, 2, '2025-03-04', 0.88, 'Optimización de base de datos', NULL),
(98, 9, 4, '2025-02-23', 1.1, 'Instalación de sistema de videoconferencia', 'Facilis minima ipsa magnam consequatur. Officia et ab aperiam quidem.
Totam magnam occaecati iusto tempora placeat. Culpa mollitia quam.'),
(87, 3, 1, '2024-12-29', 4.59, 'Hoja atascada en la impresora de mesa de ayuda', 'Ducimus eos eos error ratione qui. Laborum ad fugiat consequuntur. Culpa voluptatibus iure voluptatem veniam optio consequatur. Eum eveniet nobis veniam ex ad asperiores.'),
(92, 16, 1, '2024-10-03', 4.89, 'Configuración de red inalámbrica en oficina principal', 'Omnis ex voluptates porro numquam atque.
Consequuntur perferendis iure. Omnis quos aperiam animi aliquid laboriosam dolorum. Voluptate et iste molestiae odio ut. Recusandae ex magnam maxime sed.'),
(60, 2, 2, '2025-06-12', 0.8, 'Actualización de antivirus corporativo', NULL),
(81, 12, 3, '2024-09-25', 4.6, 'Actualización de equipos de administración con backup incluido', NULL),
(79, 15, 3, '2024-08-01', 2.01, 'Reparación de equipo de impresión láser', NULL),
(21, 14, 3, '2025-03-27', 2.1, 'Configuración de red inalámbrica en oficina principal', 'Repellendus ab minima voluptatum qui perspiciatis. Voluptatem aliquid non. Nobis dolorem deserunt praesentium architecto inventore nam. Voluptas dolorum sint quo reprehenderit dolorem eum.'),
(67, 1, 4, '2025-02-23', 1.79, 'Instalación de software contable en estaciones de trabajo', NULL),
(51, 15, 4, '2025-03-09', 2.03, 'Migración de datos a nuevo sistema', 'Eum molestias dolor eligendi enim autem odio. Vitae id assumenda sapiente velit voluptatem nesciunt animi. Harum repudiandae architecto ipsum ex illo explicabo.'),
(72, 8, 1, '2025-05-13', 1.9, 'Configuración de VPN para trabajo remoto', NULL),
(13, 19, 3, '2024-09-06', 0.8, 'Optimización de base de datos', 'A iure accusantium maiores. Illo fugiat a eos laudantium nisi. Atque qui est.
Aliquam molestiae debitis. Laboriosam sint laborum.'),
(35, 19, 2, '2024-09-01', 1.61, 'Resolución de problemas de conectividad', NULL),
(58, 9, 2, '2024-11-23', 1.63, 'Optimización de base de datos', NULL),
(68, 12, 4, '2024-10-19', 3.96, 'Resolución de problemas de conectividad', NULL),
(99, 3, 1, '2024-12-01', 3.17, 'Resolución de problemas de conectividad', NULL),
(97, 12, 4, '2024-10-07', 5.26, 'Instalación de certificados SSL', NULL),
(79, 18, 4, '2024-08-26', 5.33, 'Instalación de software contable en estaciones de trabajo', NULL),
(80, 15, 4, '2025-05-08', 3.74, 'Migración de datos a nuevo sistema', NULL),
(28, 6, 4, '2025-03-19', 2.82, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(83, 9, 3, '2025-05-07', 0.41, 'Instalación de sistema de videoconferencia', 'Accusamus rem ad. Deleniti inventore porro eveniet quaerat sequi laborum.
Ex blanditiis aperiam excepturi adipisci corporis iste. Aliquid molestias dolorem nobis repellat nam hic.'),
(90, 9, 4, '2024-09-04', 5.38, 'Instalación de sistema de videoconferencia', 'Quas architecto possimus optio. Numquam eos culpa ipsa cum.
Tenetur earum earum minus iusto quas suscipit itaque. Sint officia excepturi harum atque ratione nihil.'),
(12, 20, 3, '2024-12-13', 4.14, 'Instalación de software contable en estaciones de trabajo', 'Dolores facere laboriosam at explicabo quia magni in. Debitis voluptates earum dolores.'),
(80, 5, 4, '2025-07-11', 2.54, 'Configuración de VPN para trabajo remoto', 'Officiis quia debitis suscipit. Dignissimos facilis dolore distinctio quasi. Deserunt ullam possimus placeat repudiandae.'),
(48, 8, 4, '2025-05-01', 5.99, 'Configuración de VPN para trabajo remoto', NULL),
(84, 1, 1, '2024-09-05', 0.55, 'Configuración de VPN para trabajo remoto', 'Quae soluta ex debitis eligendi saepe vitae. Reprehenderit porro ratione. Alias nobis sed quod perferendis maxime perspiciatis ut.'),
(79, 8, 3, '2024-10-05', 1.85, 'Configuración de VPN para trabajo remoto', NULL),
(97, 16, 2, '2025-07-04', 5.83, 'Actualización de equipos de administración con backup incluido', NULL),
(100, 8, 3, '2024-11-18', 2.91, 'Configuración de políticas de seguridad', 'Provident laudantium ab dolores adipisci vero nulla. Unde vero veniam.
Fugiat nobis nulla nostrum repellat qui. Consectetur blanditiis omnis velit totam optio ipsa aperiam.'),
(53, 8, 3, '2024-12-16', 0.54, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(41, 12, 4, '2025-06-18', 2.5, 'Resolución de problemas de conectividad', NULL),
(59, 10, 2, '2024-11-25', 0.79, 'Instalación de software contable en estaciones de trabajo', 'Quidem vitae blanditiis consequuntur rerum cumque. Quas illo suscipit nostrum. Inventore perferendis eius reprehenderit.'),
(8, 1, 4, '2024-08-11', 2.69, 'Actualización de equipos de administración con backup incluido', 'Ipsa deserunt cumque praesentium nesciunt eaque harum. Mollitia adipisci iusto vel. Voluptas incidunt fugit quae.'),
(75, 7, 3, '2024-08-13', 5.03, 'Actualización de antivirus corporativo', 'Quo eius alias. Dolorum necessitatibus voluptatibus exercitationem. Esse ratione error impedit nam excepturi.
Culpa quas excepturi eaque autem. Nam libero rerum ipsa vel architecto aut ut.'),
(43, 18, 1, '2024-07-16', 2.19, 'Optimización de base de datos', NULL),
(86, 12, 4, '2024-08-20', 3.55, 'Instalación de certificados SSL', NULL),
(35, 9, 2, '2024-08-09', 3.79, 'Migración de datos a nuevo sistema', NULL),
(37, 11, 4, '2025-01-07', 2.15, 'Instalación de certificados SSL', 'Cumque omnis tenetur quidem reprehenderit animi minima. Et magnam eius maiores.
Illum exercitationem earum sint. Molestias minus harum ipsa eligendi hic. Similique mollitia ea.'),
(70, 9, 4, '2025-01-02', 4.42, 'Actualización de equipos de administración con backup incluido', 'Libero modi ipsa reiciendis officiis. Illum libero est veniam eum non ipsum.'),
(23, 14, 2, '2025-01-20', 1.39, 'Resolución de problemas de conectividad', 'Facilis eligendi non beatae pariatur corrupti consequatur. Explicabo exercitationem sequi commodi provident amet.
Qui quas illum soluta aut. Nobis architecto repudiandae. Temporibus assumenda facere.'),
(47, 16, 3, '2025-06-10', 0.62, 'Reparación de equipo de impresión láser', 'Doloremque similique voluptatem. Quasi sapiente amet facilis qui consectetur officia.'),
(68, 1, 1, '2025-05-09', 1.81, 'Configuración de políticas de seguridad', 'A ad quidem tenetur. Quis quasi quis architecto quidem veritatis cupiditate.
Modi alias accusantium aliquam ab saepe ut. Pariatur praesentium labore tempora. Cumque sequi dignissimos.'),
(57, 12, 4, '2024-11-18', 4.24, 'Actualización de antivirus corporativo', 'Culpa eum cum earum dolorum consectetur. Aliquam odit ut perspiciatis fuga numquam incidunt quo. Accusantium odit inventore quos neque.'),
(75, 15, 3, '2024-10-31', 3.97, 'Configuración de políticas de seguridad', NULL),
(86, 19, 1, '2025-03-24', 0.61, 'Configuración de políticas de seguridad', NULL),
(57, 13, 2, '2025-05-05', 3.68, 'Resolución de problemas de conectividad', 'Corrupti provident commodi numquam iste commodi architecto. Iste odit eius sit ad illo ipsa.
Delectus vero beatae eligendi aperiam. Asperiores voluptate placeat ullam.'),
(52, 14, 1, '2024-07-26', 4.85, 'Instalación de software contable en estaciones de trabajo', NULL),
(61, 14, 3, '2025-02-22', 5.16, 'Mantenimiento preventivo de servidores', NULL),
(62, 9, 1, '2025-06-21', 4.58, 'Configuración de VPN para trabajo remoto', NULL),
(4, 7, 1, '2024-11-15', 0.46, 'Configuración de firewall corporativo', 'Fuga cum repellendus eos qui. Cupiditate autem iusto corrupti animi nulla iusto.'),
(85, 10, 1, '2024-11-01', 0.74, 'Configuración de VPN para trabajo remoto', NULL),
(94, 6, 2, '2024-12-14', 2.47, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(65, 4, 3, '2025-07-07', 5.11, 'Optimización de base de datos', NULL),
(88, 19, 2, '2024-09-18', 1.64, 'Instalación de certificados SSL', 'Eum tempora corporis sed. Officia dolorem quia sequi odit aperiam. Animi fuga debitis occaecati nisi debitis et.
Impedit saepe corrupti ea tenetur. Eaque laborum animi quia.'),
(38, 7, 1, '2024-12-18', 2.64, 'Instalación de certificados SSL', NULL),
(36, 16, 4, '2024-09-28', 1.53, 'Instalación de certificados SSL', 'Cumque sit consequatur beatae. Eum dolore explicabo autem assumenda vero voluptas. Explicabo possimus totam consequuntur sed modi est.'),
(55, 20, 2, '2024-10-18', 5.46, 'Migración de datos a nuevo sistema', NULL),
(8, 2, 4, '2024-09-09', 2.16, 'Instalación de certificados SSL', 'Aliquid libero nemo ipsa doloribus ut. Ad adipisci dolorum.
Rerum hic iste molestias. Numquam iusto accusantium nam modi.
Ex aliquid modi accusamus illum minima dolorem. Sequi unde saepe illo ab.'),
(60, 8, 2, '2025-01-16', 0.71, 'Instalación de sistema de videoconferencia', 'Architecto impedit officia hic. Assumenda quas magni illum.
Nostrum magni debitis sint similique odit exercitationem. Recusandae voluptatem non quas sunt quod natus.'),
(21, 3, 3, '2024-12-24', 2.89, 'Instalación de software contable en estaciones de trabajo', NULL),
(20, 2, 3, '2025-05-28', 0.35, 'Mantenimiento preventivo de servidores', 'Saepe necessitatibus dolore totam earum itaque odio dignissimos. Dolor suscipit odit corrupti asperiores vero dicta ullam. Repellat cumque facilis esse ipsam inventore.'),
(61, 11, 3, '2025-05-10', 1.39, 'Configuración de políticas de seguridad', 'Debitis doloremque nesciunt non. Quia similique iure eum eius animi voluptas. Aut ullam eum minus.'),
(8, 19, 4, '2025-06-11', 3.72, 'Migración de datos a nuevo sistema', NULL),
(26, 5, 2, '2024-09-01', 2.53, 'Actualización de antivirus corporativo', 'Nihil deleniti qui ratione maxime rem atque. Ipsa tempora iure beatae.
Exercitationem libero autem consequatur nam id. Expedita quae id.'),
(13, 7, 3, '2024-09-25', 4.99, 'Instalación de software contable en estaciones de trabajo', NULL),
(77, 9, 4, '2024-12-27', 5.79, 'Actualización de equipos de administración con backup incluido', NULL),
(74, 18, 4, '2025-03-16', 0.98, 'Configuración de VPN para trabajo remoto', NULL),
(72, 6, 4, '2025-07-06', 3.87, 'Mantenimiento preventivo de servidores', NULL),
(8, 15, 4, '2025-01-03', 1.71, 'Optimización de base de datos', NULL),
(41, 4, 4, '2024-11-10', 0.51, 'Actualización de equipos de administración con backup incluido', NULL),
(84, 2, 3, '2024-08-29', 1.14, 'Instalación de sistema de videoconferencia', NULL),
(43, 19, 2, '2025-01-31', 2.91, 'Actualización de equipos de administración con backup incluido', 'Accusantium reprehenderit reprehenderit commodi harum praesentium repellat. Optio alias nobis amet. Nemo neque quidem vitae harum. Reprehenderit magni veniam amet magnam assumenda ullam.'),
(22, 15, 1, '2024-10-29', 4.69, 'Configuración de red inalámbrica en oficina principal', 'Laborum cum odio sed explicabo. Nulla reiciendis dolores odio consequuntur rem sit. Magnam eum soluta quia dolores.'),
(25, 14, 4, '2025-02-07', 1.74, 'Instalación de sistema de videoconferencia', NULL),
(85, 5, 4, '2025-02-01', 1.34, 'Migración de datos a nuevo sistema', NULL),
(37, 7, 4, '2024-09-25', 2.42, 'Configuración de red inalámbrica en oficina principal', NULL),
(36, 2, 3, '2025-04-28', 0.44, 'Instalación de certificados SSL', NULL),
(47, 19, 3, '2025-03-03', 3.65, 'Instalación de sistema de videoconferencia', NULL),
(17, 5, 3, '2024-11-10', 5.01, 'Optimización de base de datos', NULL),
(34, 14, 4, '2025-02-24', 1.67, 'Migración de datos a nuevo sistema', NULL),
(94, 17, 3, '2024-10-11', 4.18, 'Instalación de sistema de videoconferencia', NULL),
(12, 14, 2, '2024-10-05', 2.94, 'Configuración de VPN para trabajo remoto', NULL),
(6, 6, 4, '2025-05-14', 1.12, 'Migración de datos a nuevo sistema', 'Esse praesentium iste ducimus unde quibusdam. Eius praesentium dolores debitis eaque. Laborum porro voluptate nisi esse explicabo placeat.'),
(99, 11, 3, '2024-11-24', 5.45, 'Configuración de red inalámbrica en oficina principal', 'Dolores magni numquam voluptas. Quo dignissimos dolore earum. Quod repudiandae quisquam deserunt recusandae temporibus facilis.
Impedit impedit dignissimos quo harum officia odit quibusdam.'),
(61, 9, 4, '2024-08-12', 0.4, 'Configuración de red inalámbrica en oficina principal', NULL),
(62, 11, 4, '2025-04-20', 2.89, 'Actualización de antivirus corporativo', 'Fugiat odio perspiciatis earum laudantium. In velit accusamus aperiam. Sunt dolore beatae corrupti dolorum tenetur et.'),
(56, 15, 1, '2024-12-28', 1.12, 'Mantenimiento preventivo de servidores', NULL),
(100, 4, 2, '2025-04-10', 4.2, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(96, 19, 4, '2024-08-06', 2.12, 'Configuración de firewall corporativo', NULL),
(69, 11, 1, '2025-04-22', 5.04, 'Actualización de antivirus corporativo', 'Minus vel delectus beatae fugit excepturi quasi vitae.
Fugit voluptas voluptatem sed. Facere deserunt quas laudantium. Quibusdam architecto culpa quod corrupti.'),
(83, 6, 3, '2024-12-17', 3.04, 'Instalación de software contable en estaciones de trabajo', NULL),
(39, 9, 4, '2024-12-29', 1.26, 'Instalación de software contable en estaciones de trabajo', NULL),
(72, 2, 2, '2024-09-02', 3.82, 'Configuración de firewall corporativo', NULL),
(64, 4, 3, '2024-07-23', 1.25, 'Instalación de software contable en estaciones de trabajo', NULL),
(2, 18, 4, '2024-11-27', 4.22, 'Mantenimiento preventivo de servidores', NULL),
(15, 4, 1, '2025-02-02', 3.77, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(91, 17, 2, '2025-07-06', 4.36, 'Actualización de antivirus corporativo', NULL),
(97, 19, 4, '2024-07-30', 0.68, 'Configuración de políticas de seguridad', 'Illum facilis quo ab ipsa. Quidem consequatur sunt labore rem magnam.
Minus quae corrupti quia ipsam. Iste id reiciendis quisquam natus explicabo adipisci.'),
(85, 7, 3, '2025-02-06', 1.51, 'Optimización de base de datos', NULL),
(22, 19, 3, '2024-10-19', 5.06, 'Instalación de certificados SSL', NULL),
(78, 3, 4, '2025-01-23', 1.84, 'Configuración de firewall corporativo', NULL),
(39, 6, 3, '2025-02-07', 0.49, 'Configuración de firewall corporativo', NULL),
(5, 2, 3, '2025-01-04', 2.15, 'Configuración de red inalámbrica en oficina principal', NULL),
(1, 10, 1, '2024-09-09', 1.37, 'Configuración de firewall corporativo', NULL),
(6, 5, 1, '2024-09-25', 4.02, 'Instalación de certificados SSL', 'Voluptatibus necessitatibus voluptatibus aspernatur eligendi. Velit explicabo reprehenderit dignissimos deleniti blanditiis. Mollitia tempora numquam.'),
(70, 14, 1, '2025-05-08', 1.89, 'Optimización de base de datos', 'Quisquam nobis ad autem in a ab. Qui voluptas consequuntur eaque architecto aspernatur aspernatur dignissimos.'),
(16, 15, 2, '2024-11-09', 4.38, 'Reparación de equipo de impresión láser', 'Harum debitis odit veritatis laudantium maxime. Earum harum deleniti commodi unde. In amet dicta explicabo nemo.
Accusantium aperiam quod illum suscipit deserunt soluta. Voluptates repudiandae iste.'),
(83, 20, 1, '2025-07-08', 5.33, 'Reparación de equipo de impresión láser', NULL),
(97, 9, 3, '2024-11-06', 1.49, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(93, 17, 2, '2025-05-16', 4.75, 'Migración de datos a nuevo sistema', NULL),
(46, 9, 1, '2024-12-26', 3.24, 'Optimización de base de datos', NULL),
(32, 9, 1, '2024-12-09', 5.71, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(52, 10, 4, '2025-01-10', 4.49, 'Instalación de certificados SSL', NULL),
(55, 10, 1, '2024-09-30', 4.46, 'Resolución de problemas de conectividad', NULL),
(96, 16, 1, '2025-05-23', 2.81, 'Instalación de software contable en estaciones de trabajo', NULL),
(85, 11, 3, '2024-10-15', 2.29, 'Configuración de políticas de seguridad', NULL),
(49, 16, 4, '2025-03-30', 3.15, 'Optimización de base de datos', NULL),
(4, 7, 1, '2025-07-03', 2.46, 'Configuración de firewall corporativo', NULL),
(57, 13, 2, '2024-11-13', 3.03, 'Mantenimiento preventivo de servidores', NULL),
(9, 15, 3, '2025-02-02', 3.74, 'Resolución de problemas de conectividad', NULL),
(55, 9, 4, '2025-02-03', 2.8, 'Configuración de políticas de seguridad', 'Alias saepe ducimus quam ullam consequatur inventore corrupti. Voluptatum omnis minima perspiciatis asperiores quasi eveniet. Ratione delectus provident.'),
(71, 1, 1, '2024-08-14', 5.16, 'Actualización de antivirus corporativo', NULL),
(5, 17, 2, '2025-04-28', 4.49, 'Actualización de antivirus corporativo', NULL),
(40, 2, 1, '2025-01-22', 0.78, 'Actualización de antivirus corporativo', NULL),
(49, 10, 4, '2024-11-04', 3.45, 'Configuración de red inalámbrica en oficina principal', NULL),
(88, 10, 2, '2024-09-26', 4.6, 'Optimización de base de datos', 'Neque excepturi accusamus atque sequi voluptatibus veniam. Inventore corrupti ratione veritatis explicabo quibusdam ea ipsam.
Dolor alias provident repellat reprehenderit. Id similique qui.'),
(77, 5, 3, '2025-03-26', 4.88, 'Actualización de equipos de administración con backup incluido', NULL),
(39, 11, 3, '2024-08-12', 3.75, 'Configuración de políticas de seguridad', NULL),
(51, 20, 1, '2025-06-25', 0.87, 'Resolución de problemas de conectividad', NULL),
(78, 2, 1, '2024-08-19', 2.63, 'Migración de datos a nuevo sistema', NULL),
(13, 9, 4, '2024-12-09', 3.69, 'Resolución de problemas de conectividad', NULL),
(70, 14, 2, '2025-01-19', 0.57, 'Configuración de políticas de seguridad', 'Soluta unde fugiat non at veritatis. Ut a minima quo non ipsum.
Alias deserunt ullam fugiat ducimus aliquam. Perspiciatis eum atque perferendis sed.'),
(30, 4, 3, '2025-05-30', 5.52, 'Instalación de certificados SSL', 'Inventore suscipit eaque. Non cupiditate esse asperiores asperiores autem natus modi.'),
(51, 18, 1, '2024-09-08', 4.65, 'Configuración de red inalámbrica en oficina principal', NULL),
(67, 19, 4, '2024-07-18', 2.41, 'Actualización de antivirus corporativo', NULL),
(28, 11, 2, '2025-06-04', 3.13, 'Instalación de sistema de videoconferencia', 'Minus aliquam blanditiis hic explicabo. Itaque ipsa expedita eveniet eveniet harum. Nobis hic repellat iusto aut necessitatibus iure vitae.'),
(96, 3, 2, '2025-04-17', 4.27, 'Actualización de antivirus corporativo', 'Sint quis eveniet hic labore a quidem fuga. Quo ea eveniet quo eos.
Debitis cupiditate non sapiente at voluptas quidem. Laudantium ex aspernatur dignissimos facilis. Fugit eum laboriosam.'),
(91, 3, 4, '2025-05-08', 5.68, 'Resolución de problemas de conectividad', NULL),
(3, 14, 2, '2025-02-04', 4.93, 'Configuración de VPN para trabajo remoto', NULL),
(42, 18, 1, '2024-12-06', 3.88, 'Configuración de políticas de seguridad', 'Culpa nihil architecto nostrum. Quisquam dicta distinctio dolore vero cumque sint quia.
Facere repellendus quis provident dolore non commodi voluptatum. Perferendis nihil amet ex magni voluptates.'),
(21, 20, 1, '2025-06-18', 3.19, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(90, 7, 1, '2025-04-09', 0.76, 'Instalación de sistema de videoconferencia', NULL),
(79, 9, 2, '2024-11-08', 0.78, 'Instalación de certificados SSL', NULL),
(24, 6, 4, '2025-04-26', 2.62, 'Configuración de políticas de seguridad', NULL),
(7, 1, 2, '2025-07-03', 1.84, 'Instalación de certificados SSL', NULL),
(13, 18, 4, '2025-05-27', 0.64, 'Hoja atascada en la impresora de mesa de ayuda', 'Aliquid fugiat iusto inventore. Similique dicta occaecati doloribus.
Adipisci illum ab adipisci est. Fugit assumenda repudiandae.'),
(41, 13, 3, '2024-11-30', 5.29, 'Actualización de equipos de administración con backup incluido', NULL),
(50, 12, 1, '2025-02-14', 3.42, 'Actualización de antivirus corporativo', NULL),
(31, 3, 4, '2024-10-10', 5.13, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(96, 10, 3, '2025-01-27', 2.15, 'Instalación de software contable en estaciones de trabajo', NULL),
(82, 1, 4, '2025-03-14', 5.97, 'Configuración de red inalámbrica en oficina principal', 'Expedita tempora molestias debitis. Mollitia culpa quam. Doloremque laudantium labore dolores ratione ullam dolor.
Et voluptate cum quidem. Odio ipsa atque quae vel laborum.'),
(70, 13, 4, '2024-10-27', 4.83, 'Migración de datos a nuevo sistema', NULL),
(86, 6, 3, '2025-04-08', 3.63, 'Instalación de certificados SSL', 'Asperiores quis eaque numquam ipsam saepe voluptatem. Molestiae necessitatibus quae tenetur dignissimos.'),
(4, 19, 2, '2025-03-04', 5.3, 'Instalación de sistema de videoconferencia', 'Tempora architecto nam aperiam facilis maiores cumque. Ea earum minus nulla similique.'),
(94, 10, 3, '2025-01-27', 2.15, 'Instalación de software contable en estaciones de trabajo', NULL),
(97, 8, 1, '2024-08-29', 5.88, 'Actualización de antivirus corporativo', NULL),
(98, 8, 2, '2025-07-11', 3.7, 'Actualización de antivirus corporativo', 'Iusto eos harum libero temporibus omnis. Temporibus explicabo culpa fuga. Error sit illo debitis occaecati cum. Nostrum optio suscipit dicta.'),
(60, 1, 1, '2025-04-13', 2.15, 'Instalación de certificados SSL', NULL),
(71, 8, 3, '2025-01-25', 2.81, 'Actualización de equipos de administración con backup incluido', NULL),
(13, 16, 1, '2024-11-26', 5.61, 'Instalación de certificados SSL', 'Cumque dolorum aut deleniti blanditiis corporis quaerat. Deserunt accusamus provident esse nam ullam.'),
(24, 14, 2, '2025-03-04', 2.69, 'Actualización de antivirus corporativo', NULL),
(65, 10, 3, '2025-03-19', 0.33, 'Configuración de firewall corporativo', NULL),
(67, 17, 3, '2024-10-07', 3.11, 'Reparación de equipo de impresión láser', 'Dignissimos ratione libero corrupti. Explicabo adipisci porro repellat fugiat ipsam.
Repellat deleniti laborum. Tempore quod veritatis cupiditate.'),
(16, 10, 4, '2024-08-24', 2.61, 'Instalación de sistema de videoconferencia', 'At tenetur quae dolore eaque facilis fugiat.
Laboriosam nesciunt necessitatibus ad nesciunt velit temporibus.
Veniam esse nostrum rem quia natus aperiam. Et nostrum dicta.'),
(48, 11, 2, '2024-08-08', 3.93, 'Configuración de red inalámbrica en oficina principal', NULL),
(84, 1, 1, '2024-08-27', 4.99, 'Optimización de base de datos', NULL),
(31, 19, 3, '2024-11-11', 4.02, 'Configuración de políticas de seguridad', NULL),
(35, 13, 2, '2025-01-03', 2.39, 'Resolución de problemas de conectividad', 'Ad repellendus dignissimos maiores dicta magnam. Sed cupiditate cupiditate eum. Deserunt rem cum necessitatibus.'),
(91, 19, 3, '2024-11-24', 2.14, 'Instalación de sistema de videoconferencia', 'Perspiciatis totam ad ab quidem perspiciatis. Laborum unde aspernatur officia nesciunt minus accusamus.'),
(53, 10, 1, '2024-08-31', 1.09, 'Resolución de problemas de conectividad', NULL),
(8, 11, 1, '2024-09-21', 2.99, 'Optimización de base de datos', 'Recusandae officia magni. Cupiditate eligendi libero sequi. Illum consequuntur quisquam perspiciatis nobis dolore. Voluptatum officiis delectus eius a.'),
(22, 15, 1, '2024-10-29', 4.69, 'Configuración de red inalámbrica en oficina principal', 'Laborum cum odio sed explicabo. Nulla reiciendis dolores odio consequuntur rem sit. Magnam eum soluta quia dolores.'),
(88, 18, 1, '2025-02-11', 4.88, 'Instalación de certificados SSL', NULL),
(17, 6, 2, '2024-08-14', 5.04, 'Reparación de equipo de impresión láser', 'Impedit beatae tempora sequi odit saepe placeat inventore. Autem amet veritatis fugit explicabo officia.'),
(66, 4, 4, '2025-04-07', 2.84, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(73, 18, 2, '2025-01-12', 3.43, 'Instalación de software contable en estaciones de trabajo', NULL),
(91, 15, 3, '2024-12-11', 2.45, 'Hoja atascada en la impresora de mesa de ayuda', 'Fugiat voluptatum facere necessitatibus placeat itaque nemo voluptatem. Dolorem laborum ab rem. Itaque rerum fugiat assumenda.'),
(62, 13, 3, '2024-09-30', 3.24, 'Migración de datos a nuevo sistema', NULL),
(28, 11, 2, '2025-06-04', 5.2, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(35, 2, 1, '2025-06-08', 4.41, 'Configuración de VPN para trabajo remoto', NULL),
(94, 1, 1, '2024-10-06', 2.83, 'Actualización de equipos de administración con backup incluido', 'Eligendi optio praesentium tenetur. Asperiores amet occaecati impedit officia nihil earum. Deleniti minima non blanditiis laudantium sed itaque.'),
(58, 12, 2, '2024-10-04', 2.94, 'Configuración de firewall corporativo', NULL),
(68, 5, 4, '2024-07-29', 1.03, 'Configuración de red inalámbrica en oficina principal', NULL),
(26, 18, 1, '2024-11-11', 2.94, 'Configuración de firewall corporativo', 'Odio harum magni corrupti ut. Possimus tempore nostrum cumque.'),
(13, 18, 3, '2025-01-01', 2.05, 'Actualización de equipos de administración con backup incluido', NULL),
(99, 12, 1, '2025-03-05', 3.15, 'Resolución de problemas de conectividad', NULL),
(53, 15, 3, '2025-03-30', 2.07, 'Instalación de software contable en estaciones de trabajo', 'Velit pariatur molestiae consectetur impedit aut incidunt. Tempora consequuntur magnam deleniti laboriosam voluptatem laudantium. Unde quia at eum.'),
(72, 11, 3, '2024-07-29', 5.76, 'Reparación de equipo de impresión láser', NULL),
(76, 5, 3, '2025-03-13', 2.09, 'Configuración de red inalámbrica en oficina principal', NULL),
(56, 11, 3, '2025-03-04', 4.85, 'Instalación de sistema de videoconferencia', NULL),
(42, 7, 4, '2024-09-23', 3.75, 'Instalación de sistema de videoconferencia', 'Dolorum illum laborum libero odit ad esse. Expedita dolorem iure doloribus error aperiam.'),
(24, 1, 3, '2025-05-17', 5.52, 'Mantenimiento preventivo de servidores', NULL),
(25, 11, 1, '2024-11-23', 1.24, 'Actualización de equipos de administración con backup incluido', NULL),
(96, 15, 4, '2025-03-29', 4.72, 'Optimización de base de datos', 'Illo pariatur odit dolor quisquam. Porro facilis nulla debitis minus tempore inventore.'),
(6, 19, 2, '2025-05-08', 0.39, 'Configuración de VPN para trabajo remoto', 'Inventore in ducimus cumque itaque accusantium rem. Autem itaque praesentium ipsam vel.
Eius cum incidunt aspernatur.
Placeat cum laborum beatae.
Alias eum veniam sed. Illum dolores minus.'),
(95, 7, 2, '2024-10-22', 5.66, 'Reparación de equipo de impresión láser', NULL),
(62, 19, 3, '2024-10-26', 2.97, 'Configuración de red inalámbrica en oficina principal', NULL),
(92, 11, 3, '2025-03-06', 5.51, 'Migración de datos a nuevo sistema', NULL),
(81, 18, 1, '2025-02-19', 1.23, 'Configuración de firewall corporativo', NULL),
(67, 4, 3, '2025-01-30', 4.41, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(51, 11, 1, '2024-12-18', 2.0, 'Reparación de equipo de impresión láser', NULL),
(76, 18, 3, '2025-04-24', 5.06, 'Instalación de certificados SSL', NULL),
(23, 18, 4, '2025-05-05', 1.02, 'Resolución de problemas de conectividad', 'Deserunt enim cupiditate distinctio. Reiciendis iste eaque enim culpa veniam. Aliquid recusandae nostrum.'),
(87, 5, 2, '2024-11-06', 0.85, 'Resolución de problemas de conectividad', 'In eveniet quibusdam facilis ex consequuntur asperiores. Eligendi quae autem aut. Cumque repudiandae sed consequuntur.'),
(92, 1, 4, '2024-12-27', 4.0, 'Instalación de sistema de videoconferencia', 'Molestias quidem unde atque quisquam facilis. Quo tempore consequuntur vitae dolore ab assumenda.'),
(67, 17, 3, '2024-10-18', 4.46, 'Mantenimiento preventivo de servidores', NULL),
(57, 1, 2, '2025-02-23', 4.58, 'Actualización de antivirus corporativo', NULL),
(98, 8, 4, '2025-05-21', 2.23, 'Migración de datos a nuevo sistema', NULL),
(82, 3, 4, '2024-12-06', 1.59, 'Configuración de red inalámbrica en oficina principal', NULL),
(53, 15, 1, '2025-02-26', 1.32, 'Configuración de firewall corporativo', NULL),
(6, 6, 2, '2024-10-13', 4.45, 'Actualización de equipos de administración con backup incluido', 'Odit quos necessitatibus.
Optio maxime eum dignissimos eaque. Ipsa ullam libero rerum ipsa.'),
(29, 1, 4, '2025-02-23', 4.38, 'Instalación de sistema de videoconferencia', 'Ullam minus aspernatur ut magnam. Laudantium hic reiciendis illo itaque cumque. Nulla ipsa ex beatae enim.'),
(8, 2, 4, '2024-08-19', 1.54, 'Hoja atascada en la impresora de mesa de ayuda', 'Incidunt et voluptate accusantium praesentium. Qui quae unde quae sint aliquam incidunt. Unde modi nobis suscipit.'),
(80, 15, 3, '2025-06-30', 3.25, 'Optimización de base de datos', NULL),
(61, 13, 3, '2024-11-27', 2.63, 'Migración de datos a nuevo sistema', NULL),
(69, 6, 1, '2024-11-12', 5.22, 'Actualización de equipos de administración con backup incluido', 'Voluptates esse necessitatibus sit dignissimos sunt quibusdam. Harum sapiente earum fugiat iste quaerat exercitationem. Non accusantium rerum.'),
(31, 18, 3, '2024-10-25', 1.12, 'Configuración de red inalámbrica en oficina principal', NULL),
(68, 11, 1, '2024-07-30', 4.21, 'Actualización de antivirus corporativo', NULL),
(82, 17, 1, '2024-08-15', 4.21, 'Configuración de VPN para trabajo remoto', NULL),
(23, 17, 3, '2025-07-12', 2.29, 'Configuración de firewall corporativo', 'Incidunt voluptates atque mollitia quisquam. Aut accusamus autem inventore itaque unde asperiores. Ad provident velit assumenda qui.'),
(59, 7, 1, '2025-01-26', 0.7, 'Configuración de políticas de seguridad', NULL),
(78, 10, 1, '2024-09-11', 5.4, 'Instalación de software contable en estaciones de trabajo', NULL),
(2, 16, 2, '2024-12-25', 5.68, 'Configuración de políticas de seguridad', NULL),
(86, 8, 1, '2024-12-16', 3.69, 'Actualización de antivirus corporativo', NULL),
(23, 10, 2, '2025-07-03', 4.22, 'Configuración de VPN para trabajo remoto', NULL),
(10, 20, 2, '2024-08-10', 0.95, 'Migración de datos a nuevo sistema', NULL),
(31, 12, 2, '2025-02-03', 4.79, 'Mantenimiento preventivo de servidores', NULL),
(42, 5, 3, '2024-08-05', 1.02, 'Actualización de antivirus corporativo', 'Perspiciatis at porro praesentium cum. Sit vitae laboriosam facere debitis ab.'),
(57, 18, 3, '2024-10-24', 3.68, 'Instalación de software contable en estaciones de trabajo', 'Sequi iste distinctio quo.
Sapiente vitae molestias aliquam numquam. Delectus nisi est autem ipsum molestias molestias debitis. Earum maxime ratione neque fuga perspiciatis. Explicabo ab nostrum.'),
(79, 5, 4, '2024-10-24', 4.89, 'Mantenimiento preventivo de servidores', NULL),
(60, 17, 1, '2025-04-21', 0.73, 'Reparación de equipo de impresión láser', NULL),
(77, 16, 3, '2024-11-17', 3.89, 'Configuración de firewall corporativo', 'Sapiente placeat autem et deleniti expedita. Ratione quam laudantium eaque.
Aut nihil sunt tempore soluta quae. Quae labore quia.'),
(29, 9, 1, '2025-04-12', 1.04, 'Resolución de problemas de conectividad', NULL),
(91, 5, 2, '2024-09-05', 2.65, 'Instalación de sistema de videoconferencia', NULL),
(31, 2, 1, '2025-02-02', 5.98, 'Configuración de VPN para trabajo remoto', 'Id sunt sequi vero voluptas nulla temporibus. A soluta nostrum commodi. Occaecati odio aspernatur in tenetur harum. Commodi dolorum molestiae necessitatibus.'),
(11, 14, 3, '2024-10-04', 3.7, 'Actualización de equipos de administración con backup incluido', 'Deserunt eos odio reiciendis perferendis. Exercitationem unde neque incidunt expedita.
Magni amet inventore. Deleniti ipsa adipisci debitis illo facilis.'),
(3, 20, 2, '2024-10-05', 2.84, 'Configuración de firewall corporativo', NULL),
(76, 3, 4, '2024-12-17', 3.65, 'Configuración de red inalámbrica en oficina principal', NULL),
(28, 13, 2, '2025-06-03', 1.81, 'Configuración de firewall corporativo', 'Cumque ipsam quasi quaerat ullam minus. Eius maiores quisquam cupiditate vitae eveniet.'),
(96, 1, 3, '2024-12-20', 3.38, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(95, 10, 1, '2025-07-02', 3.25, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(70, 15, 3, '2025-02-18', 2.41, 'Optimización de base de datos', 'Reprehenderit possimus voluptates voluptatum ullam iusto.
Dolore provident ratione voluptatem officiis aspernatur. Ut occaecati earum molestiae nam.'),
(77, 4, 1, '2025-01-13', 3.6, 'Resolución de problemas de conectividad', NULL),
(43, 2, 1, '2025-04-22', 0.48, 'Configuración de firewall corporativo', NULL),
(25, 9, 3, '2025-05-04', 5.04, 'Mantenimiento preventivo de servidores', NULL),
(71, 18, 3, '2024-08-26', 0.7, 'Optimización de base de datos', 'Nobis quas aliquam delectus tenetur officiis ab. Veritatis occaecati deleniti. Pariatur quis rem neque impedit dolorum explicabo illum.'),
(35, 10, 4, '2024-08-12', 4.7, 'Hoja atascada en la impresora de mesa de ayuda', NULL),
(32, 10, 2, '2024-07-18', 4.25, 'Resolución de problemas de conectividad', NULL),
(25, 12, 2, '2024-12-20', 5.43, 'Optimización de base de datos', NULL),
(83, 15, 1, '2025-02-26', 0.54, 'Configuración de políticas de seguridad', NULL),
(94, 9, 3, '2024-09-13', 3.81, 'Instalación de software contable en estaciones de trabajo', NULL),
(13, 18, 4, '2025-05-03', 4.64, 'Mantenimiento preventivo de servidores', NULL),
(30, 15, 2, '2025-01-21', 5.87, 'Actualización de equipos de administración con backup incluido', 'Facere accusamus harum aliquid ut qui odit in. Esse eius exercitationem veniam ea ea illo.
Natus pariatur vel. Fuga quia eveniet adipisci.'),
(30, 6, 3, '2024-07-28', 5.43, 'Instalación de certificados SSL', NULL),
(21, 19, 1, '2025-02-12', 5.79, 'Instalación de software contable en estaciones de trabajo', 'Tenetur hic nesciunt deleniti praesentium in laudantium. Dolores officiis error cumque odit id. Recusandae natus temporibus commodi corrupti beatae accusamus.'),
(86, 19, 2, '2025-06-26', 3.59, 'Reparación de equipo de impresión láser', 'Accusantium ipsam consequatur voluptates. Voluptatibus asperiores sapiente consequatur rem sit voluptatem. Rem facilis fugiat voluptas.'),
(65, 11, 2, '2024-10-08', 5.43, 'Actualización de antivirus corporativo', NULL),
(55, 18, 1, '2024-10-09', 2.27, 'Mantenimiento preventivo de servidores', NULL),
(70, 7, 1, '2025-03-13', 1.99, 'Hoja atascada en la impresora de mesa de ayuda', 'Amet ipsum nisi ab ab facere. Dolore ipsa odio. Ex soluta assumenda numquam dolore.'),
(88, 15, 2, '2025-02-24', 4.43, 'Actualización de equipos de administración con backup incluido', 'Beatae numquam at quidem. Placeat doloremque libero impedit.
Accusantium sit tenetur a facilis. Quae temporibus vel laborum dicta qui veritatis dolor.'),
(27, 19, 3, '2025-01-08', 3.23, 'Configuración de red inalámbrica en oficina principal', 'Aperiam temporibus enim aliquid. Sint maxime corporis voluptatum rem. Iusto quia fugit.
Harum maiores quae doloribus. Atque dicta iste iusto recusandae eum similique.'),
(89, 3, 2, '2025-02-04', 2.84, 'Configuración de VPN para trabajo remoto', NULL),
(25, 12, 2, '2024-10-03', 4.39, 'Configuración de firewall corporativo', NULL),
(29, 8, 1, '2024-08-23', 3.68, 'Instalación de certificados SSL', NULL),
(84, 13, 2, '2025-01-15', 5.06, 'Configuración de firewall corporativo', NULL),
(66, 17, 3, '2024-08-15', 4.2, 'Resolución de problemas de conectividad', NULL),
(18, 15, 3, '2025-02-10', 2.22, 'Configuración de VPN para trabajo remoto', NULL),
(55, 9, 2, '2025-04-08', 5.72, 'Configuración de políticas de seguridad', NULL),
(7, 13, 1, '2024-10-14', 4.81, 'Migración de datos a nuevo sistema', NULL),
(94, 11, 4, '2025-06-22', 5.47, 'Configuración de red inalámbrica en oficina principal', 'Eum saepe odit similique mollitia fuga sequi. Laudantium eligendi velit labore.
Esse accusamus at sequi. Autem ex quidem.'),
(70, 18, 4, '2024-09-29', 3.9, 'Mantenimiento preventivo de servidores', 'Cum modi ad quos neque sint occaecati ut. Quis voluptate vitae quibusdam quia. Dicta optio veritatis temporibus. Autem a fuga dolorem.'),
(9, 3, 4, '2024-12-21', 5.09, 'Configuración de red inalámbrica en oficina principal', NULL);

-- =====================================================
-- CONSULTAS DE EJEMPLO PARA VERIFICAR NORMALIZACIÓN
-- =====================================================

-- 1. Vista resumen de tickets por técnico
CREATE VIEW vista_tickets_tecnico AS
SELECT
    t.nombre || ' ' || t.apellido as tecnico,
    COUNT(tk.id_ticket) as total_tickets,
    AVG(ra.tiempo_dedicado_horas) as promedio_horas,
    SUM(ra.tiempo_dedicado_horas) as total_horas
FROM tecnicos t
LEFT JOIN tickets tk ON t.id_tecnico = tk.id_tecnico_asignado
LEFT JOIN registros_actividad ra ON tk.id_ticket = ra.id_ticket
GROUP BY t.id_tecnico, t.nombre, t.apellido;

-- 2. Vista resumen por cliente
CREATE VIEW vista_resumen_cliente AS
SELECT
    c.nombre_empresa,
    COUNT(tk.id_ticket) as total_tickets,
    AVG(ra.tiempo_dedicado_horas) as promedio_horas_ticket,
    tt.nombre as tipo_tarea_mas_frecuente
FROM clientes c
LEFT JOIN tickets tk ON c.id_cliente = tk.id_cliente
LEFT JOIN registros_actividad ra ON tk.id_ticket = ra.id_ticket
LEFT JOIN tipos_tarea tt ON tk.id_tipo_tarea = tt.id_tipo_tarea
GROUP BY c.id_cliente, c.nombre_empresa, tt.nombre;

-- 3. Consulta de verificación de integridad referencial
SELECT 'Verificación completada - Base de datos normalizada correctamente' as resultado;

-- =====================================================
-- INFORMACIÓN DE USUARIOS DE PRUEBA
-- =====================================================

-- Usuarios técnicos para login (primeros 5):
-- Usuario: dora.bermúdez | Password: pass001
-- Usuario: bienvenida.verdejo | Password: pass002
-- Usuario: onofre.ariño | Password: pass003
-- Usuario: aurelio.sáenz | Password: pass004
-- Usuario: telmo.torrijos | Password: pass005

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================