-- =========================================================
-- carga de datos y normalizacion
-- proyecto: distri-cold
-- motor: postgresql 18
-- =========================================================


-- =========================================================
-- 1. configuracion del esquema
-- =========================================================

set search_path to distri_cold;


-- =========================================================
-- 2. creacion de tabla staging
-- =========================================================
-- esta tabla recibe la estructura original del csv.
-- la importacion del csv se realiza desde dbeaver.
-- =========================================================

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


-- =========================================================
-- 3. IMPORTACION DEL CSV
-- =========================================================
-- este paso se realiza mediante la herramienta
-- "import data" de dbeaver.
--
-- archivo:
-- datos_cadena_frio.csv
--
-- formato: csv
-- separador: ;
-- cabecera: si
-- codificacion: utf-8
--
-- el csv contiene 1000 registros.
-- =========================================================


-- =========================================================
-- 4. VALIDACION DEL STAGING
-- =========================================================

-- cantidad total de registros

select count(*) as total_registros
from staging_frio;


-- valores nulos

select
    count(*) filter (where fabricante_nombre is null) as fabricante_nulo,
    count(*) filter (where medicamento_nombre is null) as medicamento_nulo,
    count(*) filter (where forma_farmaceutica is null) as forma_farmaceutica_nula,
    count(*) filter (where temperatura_min_c is null) as temperatura_min_nula,
    count(*) filter (where temperatura_max_c is null) as temperatura_max_nula,
    count(*) filter (where lote_codigo is null) as lote_nulo,
    count(*) filter (where lote_fecha_fabricacion is null) as fecha_fabricacion_nula,
    count(*) filter (where lote_fecha_vencimiento is null) as fecha_vencimiento_nula,
    count(*) filter (where almacen_nombre is null) as almacen_nulo,
    count(*) filter (where almacen_ciudad is null) as ciudad_nula,
    count(*) filter (where almacen_tipo is null) as tipo_almacen_nulo,
    count(*) filter (where existencia_cantidad_disponible is null) as cantidad_nula,
    count(*) filter (where lectura_fecha_hora is null) as fecha_lectura_nula,
    count(*) filter (where lectura_temperatura_c is null) as temperatura_lectura_nula
from staging_frio;


-- =========================================================
-- 5. VALIDACION DE DEPENDENCIAS FUNCIONALES
-- =========================================================

-- medicamento -> fabricante

select
    medicamento_nombre,
    count(distinct fabricante_nombre) as fabricantes_distintos
from staging_frio
group by medicamento_nombre
having count(distinct fabricante_nombre) > 1;


-- medicamento -> forma farmaceutica

select
    medicamento_nombre,
    count(distinct forma_farmaceutica) as formas_distintas
from staging_frio
group by medicamento_nombre
having count(distinct forma_farmaceutica) > 1;


-- medicamento -> temperaturas

select
    medicamento_nombre,
    count(distinct temperatura_min_c) as temperaturas_min_distintas,
    count(distinct temperatura_max_c) as temperaturas_max_distintas
from staging_frio
group by medicamento_nombre
having count(distinct temperatura_min_c) > 1
    or count(distinct temperatura_max_c) > 1;


-- lote -> medicamento

select
    lote_codigo,
    count(distinct medicamento_nombre) as medicamentos_distintos
from staging_frio
group by lote_codigo
having count(distinct medicamento_nombre) > 1;


-- lote -> fechas

select
    lote_codigo,
    count(distinct lote_fecha_fabricacion) as fabricaciones_distintas,
    count(distinct lote_fecha_vencimiento) as vencimientos_distintos
from staging_frio
group by lote_codigo
having count(distinct lote_fecha_fabricacion) > 1
    or count(distinct lote_fecha_vencimiento) > 1;


-- almacen -> ciudad y tipo

select
    almacen_nombre,
    count(distinct almacen_ciudad) as ciudades_distintas,
    count(distinct almacen_tipo) as tipos_distintos
from staging_frio
group by almacen_nombre
having count(distinct almacen_ciudad) > 1
    or count(distinct almacen_tipo) > 1;


-- =========================================================
-- 6. VALIDACION DE REGLAS DE NEGOCIO
-- =========================================================

-- temperatura minima debe ser menor que temperatura maxima

select *
from staging_frio
where cast(temperatura_min_c as int)
    >= cast(temperatura_max_c as int);


-- cantidad disponible no puede ser negativa

select *
from staging_frio
where cast(existencia_cantidad_disponible as int) < 0;


-- =========================================================
-- 7. VALIDACION DE DUPLICADOS
-- =========================================================

-- duplicados exactos

select
    fabricante_nombre,
    medicamento_nombre,
    forma_farmaceutica,
    temperatura_min_c,
    temperatura_max_c,
    lote_codigo,
    lote_fecha_fabricacion,
    lote_fecha_vencimiento,
    almacen_nombre,
    almacen_ciudad,
    almacen_tipo,
    existencia_cantidad_disponible,
    lectura_fecha_hora,
    lectura_temperatura_c,
    count(*) as cantidad
from staging_frio
group by
    fabricante_nombre,
    medicamento_nombre,
    forma_farmaceutica,
    temperatura_min_c,
    temperatura_max_c,
    lote_codigo,
    lote_fecha_fabricacion,
    lote_fecha_vencimiento,
    almacen_nombre,
    almacen_ciudad,
    almacen_tipo,
    existencia_cantidad_disponible,
    lectura_fecha_hora,
    lectura_temperatura_c
having count(*) > 1;


-- existencia duplicada

select
    lote_codigo,
    almacen_nombre,
    count(*) as cantidad
from staging_frio
group by lote_codigo, almacen_nombre
having count(*) > 1;


-- lectura duplicada

select
    almacen_nombre,
    lectura_fecha_hora,
    count(*) as cantidad
from staging_frio
group by almacen_nombre, lectura_fecha_hora
having count(*) > 1;


-- =========================================================
-- 8. TRANSFORMACION Y CARGA
-- =========================================================

begin;


-- ---------------------------------------------------------
-- 8.1 fabricante
-- ---------------------------------------------------------

insert into fabricante (
    fabricante_nombre
)
select distinct
    trim(fabricante_nombre)
from staging_frio
on conflict (fabricante_nombre) do nothing;


-- ---------------------------------------------------------
-- 8.2 medicamento
-- ---------------------------------------------------------

insert into medicamento (
    fabricante_id,
    medicamento_nombre,
    forma_farmaceutica,
    temperatura_min_c,
    temperatura_max_c
)
select distinct
    f.fabricante_id,
    trim(s.medicamento_nombre),
    trim(s.forma_farmaceutica),
    cast(s.temperatura_min_c as int),
    cast(s.temperatura_max_c as int)
from staging_frio s
join fabricante f
    on trim(s.fabricante_nombre) = f.fabricante_nombre
on conflict (medicamento_nombre) do nothing;


-- ---------------------------------------------------------
-- 8.3 almacen
-- ---------------------------------------------------------

insert into almacen (
    almacen_nombre,
    almacen_ciudad,
    almacen_tipo
)
select distinct
    trim(almacen_nombre),
    trim(almacen_ciudad),
    trim(almacen_tipo)
from staging_frio
on conflict (almacen_nombre) do nothing;


-- ---------------------------------------------------------
-- 8.4 lote
-- ---------------------------------------------------------

insert into lote (
    lote_codigo,
    medicamento_id,
    fecha_fabricacion,
    fecha_vencimiento
)
select distinct
    trim(s.lote_codigo),
    m.medicamento_id,
    to_date(
        s.lote_fecha_fabricacion,
        'dd/mm/yyyy'
    ),
    to_date(
        s.lote_fecha_vencimiento,
        'dd/mm/yyyy'
    )
from staging_frio s
join medicamento m
    on trim(s.medicamento_nombre) = m.medicamento_nombre
on conflict (lote_codigo) do nothing;


-- ---------------------------------------------------------
-- 8.5 existencia_inventario
-- ---------------------------------------------------------

insert into existencia_inventario (
    lote_codigo,
    almacen_id,
    cantidad_disponible
)
select distinct
    trim(s.lote_codigo),
    a.almacen_id,
    cast(s.existencia_cantidad_disponible as int)
from staging_frio s
join almacen a
    on trim(s.almacen_nombre) = a.almacen_nombre
on conflict on constraint pk_existencia_inventario do nothing;


-- ---------------------------------------------------------
-- 8.6 lectura_temperatura
-- ---------------------------------------------------------

insert into lectura_temperatura (
    almacen_id,
    lectura_fecha_hora,
    lectura_temperatura_c
)
select distinct
    a.almacen_id,
    to_timestamp(
        s.lectura_fecha_hora,
        'dd/mm/yyyy hh24:mi'
    ),
    cast(
        replace(s.lectura_temperatura_c, ',', '.')
        as decimal(5,2)
    )
from staging_frio s
join almacen a
    on trim(s.almacen_nombre) = a.almacen_nombre
on conflict on constraint uq_lectura_almacen_fecha do nothing;


-- =========================================================
-- 9. CONFIRMAR TRANSACCION
-- =========================================================

commit;


-- =========================================================
-- 10. VALIDACION FINAL DE REGISTROS
-- =========================================================

select
    'fabricante' as tabla,
    count(*) as cantidad_registros
from fabricante

union all

select
    'medicamento',
    count(*)
from medicamento

union all

select
    'almacen',
    count(*)
from almacen

union all

select
    'lote',
    count(*)
from lote

union all

select
    'existencia_inventario',
    count(*)
from existencia_inventario

union all

select
    'lectura_temperatura',
    count(*)
from lectura_temperatura;


-- =========================================================
-- 11. VALIDACION DE INTEGRIDAD REFERENCIAL
-- =========================================================

select count(*) as lotes_sin_medicamento
from lote l
left join medicamento m
    on m.medicamento_id = l.medicamento_id
where m.medicamento_id is null;


select count(*) as existencias_sin_lote
from existencia_inventario ei
left join lote l
    on l.lote_codigo = ei.lote_codigo
where l.lote_codigo is null;


select count(*) as existencias_sin_almacen
from existencia_inventario ei
left join almacen a
    on a.almacen_id = ei.almacen_id
where a.almacen_id is null;


select count(*) as lecturas_sin_almacen
from lectura_temperatura lt
left join almacen a
    on a.almacen_id = lt.almacen_id
where a.almacen_id is null;


-- =========================================================
-- 12. VALIDACION DE REGLAS DE NEGOCIO
-- =========================================================

select count(*) as temperaturas_invalidas
from medicamento
where temperatura_min_c >= temperatura_max_c;


select count(*) as fechas_lote_invalidas
from lote
where fecha_fabricacion >= fecha_vencimiento;


select count(*) as existencias_negativas
from existencia_inventario
where cantidad_disponible < 0;


select
    almacen_id,
    lectura_fecha_hora,
    count(*) as cantidad
from lectura_temperatura
group by almacen_id, lectura_fecha_hora
having count(*) > 1;

