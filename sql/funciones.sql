set search_path to distri_cold;

drop function if exists fn_detectar_saltos_termicos(varchar, decimal);

create or replace function fn_detectar_saltos_termicos(
    p_almacen_nombre varchar,
    p_umbral_grados decimal
) 
returns table (
    almacen varchar,
    fecha_hora_lectura timestamp,
    temperatura_actual decimal(5,2),
    temperatura_anterior decimal(5,2),
    variacion_grados decimal(5,2)
) 
language plpgsql
as $$
begin
    return query
    
    -- Inicio de la Common Table Expression (CTE)
    with lecturas_secuenciales as (
        select 
            a.almacen_nombre,
            lt.lectura_fecha_hora,
            lt.lectura_temperatura_c as temp_actual,
            -- Window Function: Obtiene la temperatura de la lectura cronológicamente anterior.
            -- Se particiona (agrupa) por almacén y se ordena por fecha/hora.
            lag(lt.lectura_temperatura_c) over (
                partition by a.almacen_id 
                order by lt.lectura_fecha_hora asc
            ) as temp_anterior
        from lectura_temperatura lt
        join almacen a on lt.almacen_id = a.almacen_id
        where a.almacen_nombre = p_almacen_nombre
    )
    -- Consulta que consume la CTE
    select 
        ls.almacen_nombre,
        ls.lectura_fecha_hora,
        ls.temp_actual,
        ls.temp_anterior,
        -- Calculamos la diferencia absoluta (no importa si subió o bajó de golpe)
        abs(ls.temp_actual - ls.temp_anterior) as variacion
    from lecturas_secuenciales ls
    -- Filtramos omitiendo el primer registro (que no tiene anterior) 
    -- y mostrando solo los saltos que superan el umbral definido
    where ls.temp_anterior is not null 
      and abs(ls.temp_actual - ls.temp_anterior) >= p_umbral_grados
    order by variacion desc; -- Muestra los incidentes más graves primero
end;
$$;