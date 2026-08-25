-- =========================================================
-- 1. creacion del usuario
-- =========================================================
-- este bloque debe ejecutarse con un usuario administrativo.
-- si el usuario ya existe, no se vuelve a crear.
-- =========================================================

do $$
begin
    if not exists (
        select 1
        from pg_roles
        where rolname = 'distri_cold_user'
    ) then
        create role distri_cold_user
            login
            password 'TU_PASSWORD';
    end if;
end
$$;


-- =========================================================
-- 2. acceso a la base de datos
-- =========================================================

grant connect
on database distri_cold
to distri_cold_user;


-- =========================================================
-- 3. creacion del esquema
-- =========================================================

create schema if not exists distri_cold
    authorization distri_cold_user;

alter schema distri_cold
    owner to distri_cold_user;

set search_path to distri_cold;


-- =========================================================
-- 4. limpieza de objetos existentes
-- =========================================================
-- se eliminan primero los objetos dependientes y luego
-- las tablas principales.
-- =========================================================

drop view if exists vw_inventario_disponible;

drop function if exists fn_detectar_saltos_termicos(varchar, decimal);
drop function if exists fn_registrar_lectura(varchar, timestamp, decimal);

drop procedure if exists actualizar_cantidad_inventario(varchar, int, int);
drop procedure if exists insertar_fabricante(varchar);
drop procedure if exists insertar_almacen(varchar, varchar, varchar);

drop table if exists lectura_temperatura;
drop table if exists existencia_inventario;
drop table if exists lote;
drop table if exists almacen;
drop table if exists medicamento;
drop table if exists fabricante;


-- =========================================================
-- 5. tabla fabricante
-- =========================================================

create table fabricante (
    fabricante_id int generated always as identity primary key,
    fabricante_nombre varchar(150) not null unique
);


-- =========================================================
-- 6. tabla medicamento
-- =========================================================

create table medicamento (
    medicamento_id int generated always as identity primary key,
    fabricante_id int not null,
    medicamento_nombre varchar(150) not null unique,
    forma_farmaceutica varchar(100) not null,
    temperatura_min_c int not null,
    temperatura_max_c int not null,

    constraint fk_medicamento_fabricante
        foreign key (fabricante_id)
        references fabricante(fabricante_id),

    constraint chk_temperaturas
        check (temperatura_min_c < temperatura_max_c)
);


-- =========================================================
-- 7. tabla almacen
-- =========================================================

create table almacen (
    almacen_id int generated always as identity primary key,
    almacen_nombre varchar(100) not null unique,
    almacen_ciudad varchar(100) not null,
    almacen_tipo varchar(100) not null
);


-- =========================================================
-- 8. tabla lote
-- =========================================================

create table lote (
    lote_codigo varchar(50) primary key,
    medicamento_id int not null,
    fecha_fabricacion date not null,
    fecha_vencimiento date not null,

    constraint fk_lote_medicamento
        foreign key (medicamento_id)
        references medicamento(medicamento_id),

    constraint chk_fechas_lote
        check (fecha_fabricacion < fecha_vencimiento)
);


-- =========================================================
-- 9. tabla existencia_inventario
-- =========================================================
-- relacion muchos a muchos entre lote y almacen.
-- =========================================================

create table existencia_inventario (
    lote_codigo varchar(50) not null,
    almacen_id int not null,
    cantidad_disponible int not null,

    constraint pk_existencia_inventario
        primary key (lote_codigo, almacen_id),

    constraint fk_inventario_lote
        foreign key (lote_codigo)
        references lote(lote_codigo),

    constraint fk_inventario_almacen
        foreign key (almacen_id)
        references almacen(almacen_id),

    constraint chk_cantidad_disponible
        check (cantidad_disponible >= 0)
);


-- =========================================================
-- 10. tabla lectura_temperatura
-- =========================================================
-- las lecturas son independientes de los lotes.
-- =========================================================

create table lectura_temperatura (
    lectura_id int generated always as identity primary key,
    almacen_id int not null,
    lectura_fecha_hora timestamp not null,
    lectura_temperatura_c decimal(5,2) not null,

    constraint fk_lectura_almacen
        foreign key (almacen_id)
        references almacen(almacen_id),

    constraint uq_lectura_almacen_fecha
        unique (almacen_id, lectura_fecha_hora)
);


-- =========================================================
-- 11. secuencias
-- =========================================================
-- las columnas identity generan automaticamente las
-- secuencias asociadas en postgresql.
--
-- no es necesario crear secuencias manualmente.
-- =========================================================


-- =========================================================
-- 12. vista de inventario disponible
-- =========================================================
-- permite consultar de forma directa el inventario
-- disponible relacionando almacen, lote y medicamento.
-- =========================================================

create or replace view vw_inventario_disponible as
select
    a.almacen_nombre,
    a.almacen_ciudad,
    a.almacen_tipo,
    ei.lote_codigo,
    m.medicamento_nombre,
    ei.cantidad_disponible
from existencia_inventario ei
join almacen a
    on ei.almacen_id = a.almacen_id
join lote l
    on ei.lote_codigo = l.lote_codigo
join medicamento m
    on l.medicamento_id = m.medicamento_id
where ei.cantidad_disponible > 0;


-- =========================================================
-- 13. procedimiento: insertar fabricante
-- =========================================================

create or replace procedure insertar_fabricante(
    p_fabricante_nombre varchar(150)
)
language plpgsql
as $$
begin
    insert into fabricante (
        fabricante_nombre
    )
    values (
        p_fabricante_nombre
    );
end;
$$;


-- =========================================================
-- 14. procedimiento: insertar almacen
-- =========================================================

create or replace procedure insertar_almacen(
    p_almacen_nombre varchar(100),
    p_almacen_ciudad varchar(100),
    p_almacen_tipo varchar(100)
)
language plpgsql
as $$
begin
    insert into almacen (
        almacen_nombre,
        almacen_ciudad,
        almacen_tipo
    )
    values (
        p_almacen_nombre,
        p_almacen_ciudad,
        p_almacen_tipo
    );
end;
$$;


-- =========================================================
-- 15. procedimiento: actualizar cantidad de inventario
-- =========================================================

create or replace procedure actualizar_cantidad_inventario(
    p_lote_codigo varchar(50),
    p_almacen_id int,
    p_cantidad int
)
language plpgsql
as $$
begin
    update existencia_inventario
    set cantidad_disponible = p_cantidad
    where lote_codigo = p_lote_codigo
      and almacen_id = p_almacen_id;

    if not found then
        raise exception
            'No existe la existencia para el lote % y almacen %',
            p_lote_codigo,
            p_almacen_id;
    end if;
end;
$$;


-- =========================================================
-- 16. funcion: registrar lectura de temperatura
-- =========================================================

create or replace function fn_registrar_lectura(
    p_almacen_id int,
    p_fecha_hora timestamp,
    p_temperatura decimal(5,2)
)
returns void
language plpgsql
as $$
begin
    insert into lectura_temperatura (
        almacen_id,
        lectura_fecha_hora,
        lectura_temperatura_c
    )
    values (
        p_almacen_id,
        p_fecha_hora,
        p_temperatura
    );
end;
$$;



-- =========================================================
-- 17. privilegios sobre el esquema
-- =========================================================

revoke all
on schema distri_cold
from public;

grant usage
on schema distri_cold
to distri_cold_user;


-- =========================================================
-- 18. privilegios sobre las tablas
-- =========================================================

grant select, insert, update, delete
on all tables in schema distri_cold
to distri_cold_user;


-- =========================================================
-- 19. privilegios sobre las secuencias identity
-- =========================================================

grant usage, select
on all sequences in schema distri_cold
to distri_cold_user;


-- =========================================================
-- 20. privilegios sobre las funciones
-- =========================================================

grant execute
on function
    fn_detectar_saltos_termicos(varchar, decimal),
    fn_registrar_lectura(int, timestamp, decimal)
to distri_cold_user;


-- =========================================================
-- 21. privilegios sobre los procedimientos
-- =========================================================

grant execute
on procedure insertar_fabricante(varchar)
to distri_cold_user;

grant execute
on procedure insertar_almacen(varchar, varchar, varchar)
to distri_cold_user;

grant execute
on procedure actualizar_cantidad_inventario(varchar, int, int)
to distri_cold_user;
