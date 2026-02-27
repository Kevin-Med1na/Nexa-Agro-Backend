-- ============================================================
-- NEXA AGRO DATABASE v3 - PostgreSQL
-- Esquema completo y alineado al modelo de negocio
-- ============================================================
--
-- CAMBIOS v2 → v3:
--   + pago_suscripcion       Control de mensualidades y estado de cuenta
--   + permiso_suscripcion    Restricciones formales por plan
--   + snapshot_mapa          Vista consolidada para el mapa en tiempo real
--   + notificacion           Alertas de matching y eventos de plataforma
--   + calificacion           Sistema de reputación entre usuarios
--   + actividad_mapeador     Control de reportes y beneficio del mapeador
--
-- TABLAS HEREDADAS DE v2 (sin cambios):
--   tipo_usuario, suscripcion, ubicacion, usuario,
--   perfil_transportista, vehiculo_transportista,
--   producto, necesidad, necesidad_oferta,
--   rutas, ubicacion_tiempo_real, transaccion,
--   publicidad, publicidad_producto, publicidad_ubicacion
--
-- ORDEN DE CREACIÓN:
--    1. tipo_usuario
--    2. suscripcion
--    3. permiso_suscripcion        [NUEVO v3]
--    4. ubicacion
--    5. usuario
--    6. pago_suscripcion           [NUEVO v3]
--    7. perfil_transportista
--    8. vehiculo_transportista
--    9. actividad_mapeador         [NUEVO v3]
--   10. producto
--   11. necesidad
--   12. necesidad_oferta
--   13. notificacion               [NUEVO v3]
--   14. rutas
--   15. ubicacion_tiempo_real
--   16. snapshot_mapa              [NUEVO v3]
--   17. transaccion
--   18. calificacion               [NUEVO v3]
--   19. publicidad
--   20. publicidad_producto
--   21. publicidad_ubicacion
-- ============================================================


-- ============================================================
-- BLOQUE 1: TABLAS BASE
-- ============================================================

CREATE TABLE tipo_usuario (
    id_tipo_usuario SERIAL      PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL UNIQUE,
    descripcion     TEXT
);

-- Planes de suscripción con sus parámetros económicos
CREATE TABLE suscripcion (
    id_suscripcion         SERIAL        PRIMARY KEY,
    nombre                 VARCHAR(20)   NOT NULL UNIQUE
                               CHECK (nombre IN ('basico', 'premium', 'vip')),
    alcance                VARCHAR(20)   NOT NULL
                               CHECK (alcance IN ('ciudad', 'region', 'nacional')),
    mensualidad            DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    comision               DECIMAL(5,2)  NOT NULL,
    incluye_publicidad     BOOLEAN       NOT NULL DEFAULT FALSE,
    incluye_filtros        BOOLEAN       NOT NULL DEFAULT FALSE,
    incluye_oferta_demanda BOOLEAN       NOT NULL DEFAULT FALSE
);

-- ============================================================
-- BLOQUE 2: PERMISOS POR PLAN  [NUEVO v3]
--
-- Problema: el modelo de negocio define restricciones claras
-- por plan (básico = solo ciudad, premium = región, vip = país)
-- pero esto no tenía representación formal en la BD.
-- Esta tabla formaliza qué acciones están permitidas por plan,
-- de modo que la aplicación pueda consultarla sin hardcodear
-- reglas de negocio en el código.
-- ============================================================

CREATE TABLE permiso_suscripcion (
    id_permiso      SERIAL      PRIMARY KEY,
    id_suscripcion  INT         NOT NULL REFERENCES suscripcion(id_suscripcion),
    codigo_permiso  VARCHAR(60) NOT NULL,
    -- Ejemplos de códigos:
    --   'filtro_productos', 'filtro_ubicacion', 'filtro_necesidades',
    --   'ver_oferta_demanda', 'publicar_publicidad', 'acceso_transporte',
    --   'ver_mapa_ciudad', 'ver_mapa_region', 'ver_mapa_nacional'
    descripcion     TEXT,
    UNIQUE (id_suscripcion, codigo_permiso)
);


-- ============================================================
-- BLOQUE 3: UBICACIÓN ESTÁTICA
-- ============================================================

CREATE TABLE ubicacion (
    id_ubicacion SERIAL       PRIMARY KEY,
    pais         VARCHAR(100) NOT NULL DEFAULT 'Colombia',
    departamento VARCHAR(100),
    ciudad       VARCHAR(100),
    municipio    VARCHAR(100),
    latitud      DECIMAL(10,6),
    longitud     DECIMAL(10,6)
);


-- ============================================================
-- BLOQUE 4: USUARIO
-- ============================================================

CREATE TABLE usuario (
    id_usuario       SERIAL       PRIMARY KEY,
    id_tipo_usuario  INT          NOT NULL REFERENCES tipo_usuario(id_tipo_usuario),
    id_ubicacion     INT          REFERENCES ubicacion(id_ubicacion),
    id_suscripcion   INT          REFERENCES suscripcion(id_suscripcion),
    nombre           VARCHAR(100) NOT NULL,
    email            VARCHAR(100) NOT NULL UNIQUE,
    contrasena       VARCHAR(255) NOT NULL,
    telefono         VARCHAR(20),
    direccion        VARCHAR(150),
    fecha_registro   TIMESTAMP    NOT NULL DEFAULT NOW(),
    suscripcion_activa BOOLEAN    NOT NULL DEFAULT FALSE,
    -- FALSE cuando el usuario no ha pagado su mensualidad y pierde acceso
    estado           VARCHAR(20)  NOT NULL DEFAULT 'activo'
                         CHECK (estado IN ('activo', 'inactivo', 'suspendido'))
);


-- ============================================================
-- BLOQUE 5: PAGOS DE SUSCRIPCIÓN  [NUEVO v3]
--
-- Problema: no había forma de saber si un usuario había pagado
-- su mensualidad ni de restringirle el acceso si no lo hizo.
-- Esta tabla registra cada pago (o intento de pago) y permite
-- determinar si la suscripción del usuario está vigente.
-- ============================================================

CREATE TABLE pago_suscripcion (
    id_pago         SERIAL        PRIMARY KEY,
    id_usuario      INT           NOT NULL REFERENCES usuario(id_usuario),
    id_suscripcion  INT           NOT NULL REFERENCES suscripcion(id_suscripcion),
    monto           DECIMAL(10,2) NOT NULL,
    fecha_pago      TIMESTAMP     NOT NULL DEFAULT NOW(),
    fecha_inicio    DATE          NOT NULL,   -- inicio del período cubierto
    fecha_fin       DATE          NOT NULL,   -- fin del período cubierto
    metodo_pago     VARCHAR(50),              -- PSE, tarjeta, efectivo, etc.
    referencia      VARCHAR(100)  UNIQUE,     -- referencia del procesador de pagos
    estado          VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente', 'aprobado', 'rechazado', 'reembolsado')),
    CONSTRAINT chk_periodo CHECK (fecha_fin > fecha_inicio)
);


-- ============================================================
-- BLOQUE 6: PERFIL Y VEHÍCULOS DE TRANSPORTISTA
-- ============================================================

CREATE TABLE perfil_transportista (
    id_perfil          SERIAL      PRIMARY KEY,
    id_usuario         INT         NOT NULL UNIQUE REFERENCES usuario(id_usuario),
    rol                VARCHAR(20) NOT NULL
                           CHECK (rol IN ('transportista', 'mapeador')),
    tipo               VARCHAR(30) NOT NULL
                           CHECK (tipo IN ('empresa_reconocida', 'independiente_verificado')),
    empresa_nombre     VARCHAR(100),
    verificado         BOOLEAN     NOT NULL DEFAULT FALSE,
    fecha_verificacion TIMESTAMP,
    cobertura_desc     VARCHAR(200),
    activo             BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE TABLE vehiculo_transportista (
    id_vehiculo   SERIAL        PRIMARY KEY,
    id_perfil     INT           NOT NULL REFERENCES perfil_transportista(id_perfil),
    tipo_vehiculo VARCHAR(50)   NOT NULL,
    placa         VARCHAR(20)   UNIQUE,
    capacidad_kg  INT,
    tarifa_km     DECIMAL(10,2),
    disponible    BOOLEAN       NOT NULL DEFAULT TRUE
);


-- ============================================================
-- BLOQUE 7: ACTIVIDAD DEL MAPEADOR  [NUEVO v3]
--
-- Problema: el mapeador no paga comisión A CAMBIO de aportar
-- datos de rutas, pero no había forma de verificar si un
-- mapeador sigue activo ni cuántos reportes ha hecho.
-- Esta tabla registra la actividad mensual del mapeador para
-- validar que mantiene el beneficio de exención de comisión.
-- ============================================================

CREATE TABLE actividad_mapeador (
    id_actividad        SERIAL    PRIMARY KEY,
    id_perfil           INT       NOT NULL REFERENCES perfil_transportista(id_perfil),
    periodo             DATE      NOT NULL,     -- primer día del mes, ej: 2025-03-01
    total_reportes      INT       NOT NULL DEFAULT 0,
    reportes_vigentes   INT       NOT NULL DEFAULT 0,   -- reportes no obsoletos al cierre del mes
    beneficio_activo    BOOLEAN   NOT NULL DEFAULT TRUE, -- FALSE si no cumple mínimo de actividad
    fecha_evaluacion    TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_perfil, periodo)
);


-- ============================================================
-- BLOQUE 8: PRODUCTOS Y NECESIDADES
-- ============================================================

CREATE TABLE producto (
    id_producto       SERIAL        PRIMARY KEY,
    id_usuario        INT           NOT NULL REFERENCES usuario(id_usuario),
    id_ubicacion      INT           REFERENCES ubicacion(id_ubicacion),
    nombre            VARCHAR(100)  NOT NULL,
    tipo              VARCHAR(50)   NOT NULL
                          CHECK (tipo IN ('agricola', 'pecuario', 'procesado', 'insumo', 'otro')),
    descripcion       TEXT,
    precio            DECIMAL(12,2) NOT NULL,
    unidad_medida     VARCHAR(50),
    stock             INT           NOT NULL DEFAULT 0,
    fecha_publicacion TIMESTAMP     NOT NULL DEFAULT NOW(),
    disponible        BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE TABLE necesidad (
    id_necesidad   SERIAL        PRIMARY KEY,
    id_usuario     INT           NOT NULL REFERENCES usuario(id_usuario),
    descripcion    TEXT          NOT NULL,
    tipo           VARCHAR(100),
    cantidad       INT,
    unidad_medida  VARCHAR(50),
    precio_max     DECIMAL(12,2),
    fecha_registro TIMESTAMP     NOT NULL DEFAULT NOW(),
    fecha_limite   TIMESTAMP,
    estado         VARCHAR(20)   NOT NULL DEFAULT 'abierta'
                       CHECK (estado IN ('abierta', 'cerrada', 'en_proceso'))
);

-- Matching entre necesidades y productos
CREATE TABLE necesidad_oferta (
    id_necesidad_oferta SERIAL        PRIMARY KEY,
    id_necesidad        INT           NOT NULL REFERENCES necesidad(id_necesidad),
    id_producto         INT           NOT NULL REFERENCES producto(id_producto),
    cantidad_ofertada   INT           NOT NULL,
    precio_ofertado     DECIMAL(12,2) NOT NULL,
    mensaje             TEXT,
    estado              VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                            CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'expirada')),
    fecha_oferta        TIMESTAMP     NOT NULL DEFAULT NOW(),
    fecha_respuesta     TIMESTAMP,
    UNIQUE (id_necesidad, id_producto)
);


-- ============================================================
-- BLOQUE 9: NOTIFICACIONES  [NUEVO v3]
--
-- Problema: el matching de necesidad_oferta era pasivo (hay que
-- ir a buscar). La plataforma necesita alertar a los usuarios
-- cuando hay un match, una oferta, una transacción, etc.
-- ============================================================

CREATE TABLE notificacion (
    id_notificacion  SERIAL      PRIMARY KEY,
    id_usuario       INT         NOT NULL REFERENCES usuario(id_usuario),
    tipo             VARCHAR(40) NOT NULL
                         CHECK (tipo IN (
                             'match_necesidad',       -- se encontró un producto para tu necesidad
                             'nueva_oferta',          -- alguien ofertó sobre tu necesidad
                             'oferta_aceptada',       -- tu oferta fue aceptada
                             'oferta_rechazada',      -- tu oferta fue rechazada
                             'transaccion_nueva',     -- nueva transacción generada
                             'transaccion_completada',
                             'pago_confirmado',
                             'pago_fallido',
                             'suscripcion_vencida',   -- mensualidad por vencer o vencida
                             'verificacion_aprobada', -- transportista verificado
                             'alerta_ruta'            -- mapeador reportó condición en tu ruta
                         )),
    titulo           VARCHAR(150) NOT NULL,
    mensaje          TEXT,
    -- referencia opcional a la entidad que originó la notificación
    id_referencia    INT,         -- ID de la transaccion, oferta, etc.
    tabla_referencia VARCHAR(50), -- nombre de la tabla: 'transaccion', 'necesidad_oferta', etc.
    leida            BOOLEAN      NOT NULL DEFAULT FALSE,
    fecha_creacion   TIMESTAMP    NOT NULL DEFAULT NOW(),
    fecha_lectura    TIMESTAMP
);


-- ============================================================
-- BLOQUE 10: RUTAS Y UBICACIÓN EN TIEMPO REAL
-- ============================================================

CREATE TABLE rutas (
    id_ruta             SERIAL        PRIMARY KEY,
    id_mapeador         INT           NOT NULL REFERENCES perfil_transportista(id_perfil),
    origen_desc         VARCHAR(200),
    destino_desc        VARCHAR(200),
    origen_latitud      DECIMAL(10,6),
    origen_longitud     DECIMAL(10,6),
    destino_latitud     DECIMAL(10,6),
    destino_longitud    DECIMAL(10,6),
    calidad_carretera   VARCHAR(20)   NOT NULL
                            CHECK (calidad_carretera IN ('buena', 'regular', 'mala', 'intransitable')),
    obstaculos          TEXT,
    tiempo_estimado_min INT,
    distancia_km        DECIMAL(8,2),
    fecha_reporte       TIMESTAMP     NOT NULL DEFAULT NOW(),
    vigente             BOOLEAN       NOT NULL DEFAULT TRUE
);

-- Posiciones dinámicas para el mapa en tiempo real
CREATE TABLE ubicacion_tiempo_real (
    id_utr        SERIAL        PRIMARY KEY,
    id_usuario    INT           REFERENCES usuario(id_usuario),
    id_vehiculo   INT           REFERENCES vehiculo_transportista(id_vehiculo),
    id_producto   INT           REFERENCES producto(id_producto),
    latitud       DECIMAL(10,6) NOT NULL,
    longitud      DECIMAL(10,6) NOT NULL,
    precision_m   INT,
    fecha_captura TIMESTAMP     NOT NULL DEFAULT NOW(),
    fuente        VARCHAR(30)   DEFAULT 'app'
                      CHECK (fuente IN ('app', 'gps_vehiculo', 'manual')),
    CONSTRAINT chk_una_entidad CHECK (
        (id_usuario  IS NOT NULL)::INT +
        (id_vehiculo IS NOT NULL)::INT +
        (id_producto IS NOT NULL)::INT = 1
    )
);


-- ============================================================
-- BLOQUE 11: SNAPSHOT DEL MAPA  [NUEVO v3]
--
-- Problema: el mapa en tiempo real es la funcionalidad estrella
-- del producto pero renderizarlo requería joins costosos entre
-- usuario, producto, ubicacion, suscripcion y ubicacion_tiempo_real.
--
-- Solución: una tabla desnormalizada que consolida todo lo que
-- el mapa necesita mostrar por punto. Se refresca periódicamente
-- (ej. cada 5 minutos vía pg_cron o un worker).
-- Permite filtrar por región/departamento/ciudad según el plan
-- del usuario que consulta.
-- ============================================================

CREATE TABLE snapshot_mapa (
    id_snapshot     SERIAL        PRIMARY KEY,
    -- entidad representada en el punto del mapa
    tipo_entidad    VARCHAR(20)   NOT NULL
                        CHECK (tipo_entidad IN ('productor', 'empresa', 'transportista', 'producto')),
    id_usuario      INT           REFERENCES usuario(id_usuario),
    id_producto     INT           REFERENCES producto(id_producto),
    -- datos de visualización
    nombre_display  VARCHAR(150)  NOT NULL,   -- nombre que aparece en el pin del mapa
    descripcion     TEXT,
    precio          DECIMAL(12,2),            -- precio del producto (si aplica)
    stock           INT,
    unidad_medida   VARCHAR(50),
    tipo_producto   VARCHAR(50),
    disponible      BOOLEAN,
    -- geolocalización consolidada
    latitud         DECIMAL(10,6) NOT NULL,
    longitud        DECIMAL(10,6) NOT NULL,
    -- datos geográficos para filtrado por plan
    pais            VARCHAR(100),
    departamento    VARCHAR(100),
    ciudad          VARCHAR(100),
    municipio       VARCHAR(100),
    -- metadata del snapshot
    fecha_snapshot  TIMESTAMP     NOT NULL DEFAULT NOW(),
    activo          BOOLEAN       NOT NULL DEFAULT TRUE
);


-- ============================================================
-- BLOQUE 12: TRANSACCIONES
-- ============================================================

CREATE TABLE transaccion (
    id_transaccion         SERIAL        PRIMARY KEY,
    id_comprador           INT           NOT NULL REFERENCES usuario(id_usuario),
    id_vendedor            INT           NOT NULL REFERENCES usuario(id_usuario),
    id_producto            INT           NOT NULL REFERENCES producto(id_producto),
    id_necesidad_oferta    INT           REFERENCES necesidad_oferta(id_necesidad_oferta),
    id_vehiculo            INT           REFERENCES vehiculo_transportista(id_vehiculo),
    cantidad               INT           NOT NULL,
    precio_unitario        DECIMAL(12,2) NOT NULL,
    subtotal               DECIMAL(12,2) NOT NULL,
    costo_transporte       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total                  DECIMAL(12,2) NOT NULL,
    comision_vendedor      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    comision_transportista DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    comision_total         DECIMAL(10,2) GENERATED ALWAYS AS
                               (comision_vendedor + comision_transportista) STORED,
    fecha_transaccion      TIMESTAMP     NOT NULL DEFAULT NOW(),
    estado                 VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                               CHECK (estado IN ('pendiente', 'en_camino', 'completada', 'cancelada')),
    notas                  TEXT
);


-- ============================================================
-- BLOQUE 13: CALIFICACIONES  [NUEVO v3]
--
-- Problema: la plataforma conecta desconocidos para transacciones
-- de dinero. Sin reputación no hay confianza. El campo 'verificado'
-- del transportista no es suficiente.
--
-- Diseño: cualquier usuario puede calificar a otro tras una
-- transacción completada. Se califica tanto al vendedor/comprador
-- como al transportista si hubo uno.
-- ============================================================

CREATE TABLE calificacion (
    id_calificacion   SERIAL     PRIMARY KEY,
    id_transaccion    INT        NOT NULL REFERENCES transaccion(id_transaccion),
    id_calificador    INT        NOT NULL REFERENCES usuario(id_usuario),  -- quien califica
    id_calificado     INT        NOT NULL REFERENCES usuario(id_usuario),  -- quien recibe la calificación
    rol_calificado    VARCHAR(20) NOT NULL
                          CHECK (rol_calificado IN ('vendedor', 'comprador', 'transportista')),
    puntaje           SMALLINT   NOT NULL CHECK (puntaje BETWEEN 1 AND 5),
    comentario        TEXT,
    fecha_calificacion TIMESTAMP NOT NULL DEFAULT NOW(),
    -- un usuario solo puede calificar a otro una vez por transacción
    UNIQUE (id_transaccion, id_calificador, id_calificado)
);


-- ============================================================
-- BLOQUE 14: PUBLICIDAD
-- ============================================================

CREATE TABLE publicidad (
    id_publicidad  SERIAL        PRIMARY KEY,
    id_usuario     INT           NOT NULL REFERENCES usuario(id_usuario),
    id_suscripcion INT           NOT NULL REFERENCES suscripcion(id_suscripcion),
    titulo         VARCHAR(100)  NOT NULL,
    descripcion    TEXT,
    imagen_url     VARCHAR(300),
    url_destino    VARCHAR(300),
    fecha_inicio   DATE          NOT NULL,
    fecha_fin      DATE          NOT NULL,
    costo          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    impresiones    INT           NOT NULL DEFAULT 0,
    clics          INT           NOT NULL DEFAULT 0,
    estado         VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                       CHECK (estado IN ('activa', 'inactiva', 'pendiente', 'vencida')),
    CONSTRAINT chk_fechas CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE publicidad_producto (
    id_publicidad INT NOT NULL REFERENCES publicidad(id_publicidad) ON DELETE CASCADE,
    id_producto   INT NOT NULL REFERENCES producto(id_producto)     ON DELETE CASCADE,
    PRIMARY KEY (id_publicidad, id_producto)
);

CREATE TABLE publicidad_ubicacion (
    id_pub_ubicacion SERIAL PRIMARY KEY,
    id_publicidad    INT    NOT NULL REFERENCES publicidad(id_publicidad) ON DELETE CASCADE,
    id_ubicacion     INT    NOT NULL REFERENCES ubicacion(id_ubicacion),
    UNIQUE (id_publicidad, id_ubicacion)
);


-- ============================================================
-- DATOS BASE (seed data)
-- ============================================================

INSERT INTO tipo_usuario (nombre, descripcion) VALUES
    ('productor',     'Agricultor o productor agrícola que vende sus cosechas'),
    ('empresa',       'Empresa agroindustrial compradora o proveedora de insumos'),
    ('transportista', 'Transportista o mapeador de rutas agrícolas');

INSERT INTO suscripcion
    (nombre, alcance, mensualidad, comision, incluye_publicidad, incluye_filtros, incluye_oferta_demanda)
VALUES
    ('basico',  'ciudad',   0.00,     10.00, TRUE, FALSE, FALSE),
    ('premium', 'region',   15000.00, 10.00, TRUE, TRUE,  FALSE),
    ('vip',     'nacional', 30000.00,  5.00, TRUE, TRUE,  TRUE);

-- Permisos por plan
INSERT INTO permiso_suscripcion (id_suscripcion, codigo_permiso, descripcion) VALUES
    -- BÁSICO
    (1, 'filtro_productos',    'Filtrar productos por tipo'),
    (1, 'acceso_transporte',   'Ver y contratar transportistas'),
    (1, 'publicar_publicidad', 'Publicar anuncios pagos'),
    (1, 'ver_mapa_ciudad',     'Ver mapa limitado a su ciudad'),
    -- PREMIUM (incluye todo lo de básico + más)
    (2, 'filtro_productos',    'Filtrar productos por tipo'),
    (2, 'filtro_ubicacion',    'Filtrar por ubicación geográfica'),
    (2, 'filtro_necesidades',  'Filtrar necesidades del mercado'),
    (2, 'acceso_transporte',   'Ver y contratar transportistas'),
    (2, 'publicar_publicidad', 'Publicar anuncios pagos'),
    (2, 'ver_mapa_ciudad',     'Ver mapa de su ciudad'),
    (2, 'ver_mapa_region',     'Ver mapa de su región'),
    -- VIP (todos los permisos)
    (3, 'filtro_productos',    'Filtrar productos por tipo'),
    (3, 'filtro_ubicacion',    'Filtrar por ubicación geográfica'),
    (3, 'filtro_necesidades',  'Filtrar necesidades del mercado'),
    (3, 'ver_oferta_demanda',  'Ver análisis de oferta y demanda nacional'),
    (3, 'acceso_transporte',   'Ver y contratar transportistas'),
    (3, 'publicar_publicidad', 'Publicar anuncios pagos'),
    (3, 'ver_mapa_ciudad',     'Ver mapa de su ciudad'),
    (3, 'ver_mapa_region',     'Ver mapa de su región'),
    (3, 'ver_mapa_nacional',   'Ver mapa de todo el país');


-- ============================================================
-- ÍNDICES
-- ============================================================

-- usuario
CREATE INDEX idx_usuario_tipo           ON usuario(id_tipo_usuario);
CREATE INDEX idx_usuario_suscripcion    ON usuario(id_suscripcion);
CREATE INDEX idx_usuario_ubicacion      ON usuario(id_ubicacion);
CREATE INDEX idx_usuario_estado         ON usuario(estado);
CREATE INDEX idx_usuario_sus_activa     ON usuario(suscripcion_activa);

-- pago_suscripcion
CREATE INDEX idx_pago_usuario           ON pago_suscripcion(id_usuario);
CREATE INDEX idx_pago_estado            ON pago_suscripcion(estado);
CREATE INDEX idx_pago_periodo           ON pago_suscripcion(fecha_inicio, fecha_fin);

-- permiso_suscripcion
CREATE INDEX idx_permiso_sus            ON permiso_suscripcion(id_suscripcion);
CREATE INDEX idx_permiso_codigo         ON permiso_suscripcion(codigo_permiso);

-- perfil_transportista
CREATE INDEX idx_perfil_usuario         ON perfil_transportista(id_usuario);
CREATE INDEX idx_perfil_rol             ON perfil_transportista(rol);
CREATE INDEX idx_perfil_verificado      ON perfil_transportista(verificado);

-- vehiculo_transportista
CREATE INDEX idx_vehiculo_perfil        ON vehiculo_transportista(id_perfil);
CREATE INDEX idx_vehiculo_disponible    ON vehiculo_transportista(disponible);

-- actividad_mapeador
CREATE INDEX idx_actividad_perfil       ON actividad_mapeador(id_perfil);
CREATE INDEX idx_actividad_periodo      ON actividad_mapeador(periodo DESC);
CREATE INDEX idx_actividad_beneficio    ON actividad_mapeador(beneficio_activo);

-- producto
CREATE INDEX idx_producto_usuario       ON producto(id_usuario);
CREATE INDEX idx_producto_tipo          ON producto(tipo);
CREATE INDEX idx_producto_disponible    ON producto(disponible);
CREATE INDEX idx_producto_ubicacion     ON producto(id_ubicacion);

-- necesidad
CREATE INDEX idx_necesidad_usuario      ON necesidad(id_usuario);
CREATE INDEX idx_necesidad_estado       ON necesidad(estado);
CREATE INDEX idx_necesidad_limite       ON necesidad(fecha_limite);

-- necesidad_oferta
CREATE INDEX idx_noferta_necesidad      ON necesidad_oferta(id_necesidad);
CREATE INDEX idx_noferta_producto       ON necesidad_oferta(id_producto);
CREATE INDEX idx_noferta_estado         ON necesidad_oferta(estado);

-- notificacion
CREATE INDEX idx_notif_usuario          ON notificacion(id_usuario);
CREATE INDEX idx_notif_leida            ON notificacion(leida);
CREATE INDEX idx_notif_tipo             ON notificacion(tipo);
CREATE INDEX idx_notif_fecha            ON notificacion(fecha_creacion DESC);

-- rutas
CREATE INDEX idx_rutas_mapeador         ON rutas(id_mapeador);
CREATE INDEX idx_rutas_calidad          ON rutas(calidad_carretera);
CREATE INDEX idx_rutas_vigente          ON rutas(vigente);
CREATE INDEX idx_rutas_fecha            ON rutas(fecha_reporte DESC);

-- ubicacion_tiempo_real
CREATE INDEX idx_utr_usuario            ON ubicacion_tiempo_real(id_usuario);
CREATE INDEX idx_utr_vehiculo           ON ubicacion_tiempo_real(id_vehiculo);
CREATE INDEX idx_utr_producto           ON ubicacion_tiempo_real(id_producto);
CREATE INDEX idx_utr_fecha              ON ubicacion_tiempo_real(fecha_captura DESC);
CREATE INDEX idx_utr_coords             ON ubicacion_tiempo_real(latitud, longitud);

-- snapshot_mapa
CREATE INDEX idx_snap_tipo              ON snapshot_mapa(tipo_entidad);
CREATE INDEX idx_snap_coords            ON snapshot_mapa(latitud, longitud);
CREATE INDEX idx_snap_departamento      ON snapshot_mapa(departamento);
CREATE INDEX idx_snap_ciudad            ON snapshot_mapa(ciudad);
CREATE INDEX idx_snap_activo            ON snapshot_mapa(activo);
CREATE INDEX idx_snap_fecha             ON snapshot_mapa(fecha_snapshot DESC);

-- transaccion
CREATE INDEX idx_trans_comprador        ON transaccion(id_comprador);
CREATE INDEX idx_trans_vendedor         ON transaccion(id_vendedor);
CREATE INDEX idx_trans_producto         ON transaccion(id_producto);
CREATE INDEX idx_trans_vehiculo         ON transaccion(id_vehiculo);
CREATE INDEX idx_trans_estado           ON transaccion(estado);
CREATE INDEX idx_trans_fecha            ON transaccion(fecha_transaccion DESC);

-- calificacion
CREATE INDEX idx_calif_transaccion      ON calificacion(id_transaccion);
CREATE INDEX idx_calif_calificado       ON calificacion(id_calificado);
CREATE INDEX idx_calif_puntaje          ON calificacion(puntaje);

-- publicidad
CREATE INDEX idx_pub_usuario            ON publicidad(id_usuario);
CREATE INDEX idx_pub_suscripcion        ON publicidad(id_suscripcion);
CREATE INDEX idx_pub_estado             ON publicidad(estado);
CREATE INDEX idx_pub_fechas             ON publicidad(fecha_inicio, fecha_fin);
