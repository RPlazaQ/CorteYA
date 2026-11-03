-- BUG encontrado probando el ítem 18 (Fase 4): las reseñas de clientes
-- (invitados, sin login) nunca actualizan barbershops.rating/review_count
-- ni barbers.rating/review_count en producción. No es un problema de la
-- Fase 4 — viene de antes, afecta reseñas reales también.
--
-- Causa: update_barbershop_rating() y update_barber_rating() (definidas en
-- supabase-schema.sql) son funciones normales (SECURITY INVOKER), así que
-- al dispararse desde un insert hecho por un cliente invitado corren con
-- los permisos del rol "anon". barbershops solo tiene policy de UPDATE
-- para el dueño ("owner updates own barbershop", auth.uid() = owner_id) y
-- barbers algo equivalente ("owner manages own barbers") — anon no tiene
-- ninguna. RLS no tira error en este caso: el UPDATE simplemente no
-- encuentra ninguna fila que pueda tocar y actualiza 0 filas, en silencio.
-- Por eso el insert de la reseña "funciona" (devuelve 201) pero el ⭐ de
-- arriba nunca se mueve.
--
-- Fix: marcar ambas funciones como `security definer` + `search_path`
-- fijo (mismo patrón ya usado en get_available_slots y
-- prevent_plan_self_change en este mismo esquema), para que el UPDATE
-- corra con los permisos de quien definió la función y no los del
-- invitado. No se toca ninguna tabla, columna, política ni la lógica de
-- pagos — solo el nivel de permiso con el que corren estos dos triggers.
--
-- Al final se recalculan de una vez rating/review_count de TODAS las
-- barberías y barberos a partir de las reseñas que ya existen (para
-- corregir los que quedaron en 0/desactualizados mientras el bug estuvo
-- activo).
--
-- Cómo probar:
--   1. Corre este archivo completo.
--   2. select id, name, rating, review_count from barbershops; -> debe
--      reflejar el promedio/conteo real de la tabla reviews para cada una.
--   3. Inserta una reseña de prueba con la anon key (como hace la app) y
--      vuelve a mirar esa barbería: rating/review_count deben actualizarse
--      solos, sin error.
--
-- Reversible: para volver atrás, hay que recrear ambas funciones sin
-- `security definer` (texto idéntico a supabase-schema.sql, líneas
-- 225-236 y 244-260).

create or replace function update_barbershop_rating() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_barbershop_id uuid := coalesce(new.barbershop_id, old.barbershop_id);
begin
  update barbershops
  set rating = coalesce((select round(avg(rating)::numeric, 1) from reviews where barbershop_id = v_barbershop_id), 0),
      review_count = (select count(*) from reviews where barbershop_id = v_barbershop_id)
  where id = v_barbershop_id;
  return null;
end;
$$;

create or replace function update_barber_rating() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_barber_id uuid := coalesce(new.barber_id, old.barber_id);
begin
  if v_barber_id is null then
    return null;
  end if;

  update barbers
  set rating = coalesce((select round(avg(rating)::numeric, 1) from reviews where barber_id = v_barber_id), 0),
      review_count = (select count(*) from reviews where barber_id = v_barber_id)
  where id = v_barber_id;

  return null;
end;
$$;

-- backfill: corrige lo que haya quedado mal mientras el bug estuvo activo
update barbershops b
set rating = coalesce((select round(avg(rating)::numeric, 1) from reviews where barbershop_id = b.id), 0),
    review_count = (select count(*) from reviews where barbershop_id = b.id);

update barbers br
set rating = coalesce((select round(avg(rating)::numeric, 1) from reviews where barber_id = br.id), 0),
    review_count = (select count(*) from reviews where barber_id = br.id);
