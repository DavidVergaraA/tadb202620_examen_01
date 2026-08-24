set search_path to distri_cold;

drop table if exists staging_frio;

create table staging_frio (
    fabricante_nombre text,
    medicamento_nombre text,
    forma_farmaceutica text,
    temperatura_min_c text,
    temperatura_max_c text,
    lote_codigo text,
    lote_fecha_fabricacion text,
    lote_fecha_vencimiento text,
    almacen_nombre text,
    almacen_ciudad text,
    almacen_tipo text,
    existencia_cantidad_disponible text,
    lectura_fecha_hora text,
    lectura_temperatura_c text
);