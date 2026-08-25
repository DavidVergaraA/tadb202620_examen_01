-- A.¿en qué condiciones de temperatura debe conservarse cada medicamento?

select
    medicamento_nombre,
    forma_farmaceutica,
    temperatura_min_c,
    temperatura_max_c
from medicamento
order by medicamento_nombre;

-- B.¿qué lotes existen de cada medicamento y cuándo vencen?

select
    m.medicamento_nombre,
    l.lote_codigo,
    l.fecha_fabricacion,
    l.fecha_vencimiento
from medicamento m
join lote l
    on m.medicamento_id = l.medicamento_id
order by m.medicamento_nombre;

-- C. ¿en qué almacenes hay unidades disponibles de cada lote y cuántas?

select
    a.almacen_nombre,
    a.almacen_ciudad,
    a.almacen_tipo,
    ex.lote_codigo,
    m.medicamento_nombre,
    ex.cantidad_disponible
from existencia_inventario ex
join almacen a
    on ex.almacen_id = a.almacen_id
join lote l
    on ex.lote_codigo = l.lote_codigo
join medicamento m
    on l.medicamento_id = m.medicamento_id
where ex.cantidad_disponible > 0
order by a.almacen_nombre, m.medicamento_nombre;

