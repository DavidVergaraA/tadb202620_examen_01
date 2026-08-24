-- =========================================================
-- configuracion del esquema
-- =========================================================
create schema if not exists distri_cold
    authorization distri_cold_user;

set search_path to distri_cold;

-- ==========================================
-- script de limpieza
-- ==========================================

drop table if exists lectura_temperatura;
drop table if exists existencia_inventario;
drop table if exists lote;
drop table if exists almacen;
drop table if exists medicamento;
drop table if exists fabricante;

-- ==========================================
-- script de creación de tablas
-- ==========================================

-- 1. crear tabla fabricante

create table fabricante (
    fabricante_id int generated always as identity primary key,
    fabricante_nombre varchar(150) unique not null
);


-- 2. crear tabla medicamento

create table medicamento (
    medicamento_id int generated always as identity primary key,
    fabricante_id int not null,
    medicamento_nombre varchar(150) unique not null,
    forma_farmaceutica varchar(100) not null,
    temperatura_min_c int not null,
    temperatura_max_c int not null,

    constraint fk_medicamento_fabricante
        foreign key (fabricante_id)
        references fabricante(fabricante_id),

    constraint chk_temperaturas
        check (temperatura_min_c < temperatura_max_c)
);


-- 3. crear tabla almacen

create table almacen (
    almacen_id int generated always as identity primary key,
    almacen_nombre varchar(100) unique not null,
    almacen_ciudad varchar(100) not null,
    almacen_tipo varchar(100) not null
);


-- 4. crear tabla lote

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


-- 5. crear tabla existencia_inventario
-- relación muchos a muchos entre lote y almacen

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


-- 6. crear tabla lectura_temperatura
-- eventos independientes de los lotes almacenados

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