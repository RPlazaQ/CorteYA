-- "Bloquear hora": hasta ahora barber_time_off solo podía bloquear el día
-- completo (vacaciones, feriados). Se agregan start_time/end_time opcionales
-- para poder bloquear solo un tramo del día (un trámite, una hora puntual).
--
-- Las dos son NULL -> bloqueo de día completo (comportamiento actual, las
-- filas existentes no cambian: ya tienen ambas columnas en NULL por
-- default). Las dos con valor -> bloqueo solo de ese tramo, ese día (o ese
-- rango de días si start_date <> end_date — el mismo tramo se bloquea
-- todos los días del rango).
--
-- Los descansos recurrentes (ej. almuerzo todos los días de 13 a 14) NO
-- se modelan acá a propósito — eso es parte del horario semanal de cada
-- barbero (barber_working_hours), no un time off puntual. Si más adelante
-- se quiere ese caso, lo más directo sería agregar una segunda ventana
-- (ej. morning_end/afternoon_start) a barber_working_hours en vez de crear
-- N filas de time_off recurrentes — lo dejo comentado acá para cuando lo
-- retomemos, pero no toco esa tabla ahora.
--
-- Cómo probar antes de producción:
--   1. Corre este archivo completo en un proyecto/branch de prueba.
--   2. Verifica que los time_off existentes siguen bloqueando el día
--      entero (no cambiaron, start_time/end_time quedan NULL):
--        select * from get_available_slots('<barber_id con un día libre ya cargado>', '<esa fecha>', 30);
--        → debe seguir devolviendo 0 filas, igual que antes de esta migración.
--   3. Inserta un bloqueo parcial de prueba:
--        insert into barber_time_off (barber_id, start_date, end_date, start_time, end_time)
--        values ('<barber_id>', '<fecha futura>', '<misma fecha>', '13:00', '14:00');
--      → debe insertarse sin error.
--   4. select * from get_available_slots('<barber_id>', '<esa fecha>', 30);
--      → no deben aparecer horas que se solapen con 13:00-14:00, pero sí
--      el resto del día (antes de las 13:00 y después de las 14:00).
--   5. Prueba el constraint: intenta insertar con solo start_time (sin
--      end_time) -> debe fallar por el CHECK. Intenta con start_time >
--      end_time -> debe fallar también.
--   6. Prueba el caso límite de un servicio que empieza antes del bloqueo
--      pero termina adentro (ej. servicio de 45 min a las 12:30 con bloqueo
--      13:00-14:00): no debe ofrecerse ese slot, porque se solapa.
--
-- Reversible:
--   drop function if exists get_available_slots(uuid, date, int, int);
--   -- (y volver a crear la versión anterior desde supabase-schema.sql si hace falta)
--   alter table barber_time_off drop constraint if exists time_off_tramo_valido;
--   alter table barber_time_off drop column if exists start_time;
--   alter table barber_time_off drop column if exists end_time;

alter table barber_time_off
  add column if not exists start_time time,
  add column if not exists end_time time;

alter table barber_time_off
  add constraint time_off_tramo_valido check (
    (start_time is null and end_time is null)
    or (start_time is not null and end_time is not null and start_time < end_time)
  );

create or replace function get_available_slots(
  p_barber_id uuid,
  p_date date,
  p_service_duration_minutes int,
  p_slot_interval_minutes int default 30
)
returns table(slot_start time)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_weekday int := extract(dow from p_date);
  v_start   time;
  v_end     time;
  v_now     timestamp := now() at time zone 'America/Santiago';
begin
  select start_time, end_time into v_start, v_end
  from barber_working_hours
  where barber_id = p_barber_id and weekday = v_weekday;

  if v_start is null then
    return;
  end if;

  -- bloqueo de día completo: ambas columnas en NULL para ese rango de fechas
  if exists (
    select 1 from barber_time_off
    where barber_id = p_barber_id
      and p_date between start_date and end_date
      and start_time is null
  ) then
    return;
  end if;

  return query
  select gs::time
  from generate_series(
    (p_date + v_start)::timestamp,
    (p_date + v_end - make_interval(mins => p_service_duration_minutes))::timestamp,
    make_interval(mins => p_slot_interval_minutes)
  ) as gs
  -- si la fecha consultada es hoy, no ofrecer horas que ya pasaron
  where (p_date > v_now::date or gs::time >= v_now::time)
    and not exists (
      select 1 from bookings b
      where b.barber_id = p_barber_id
        and b.status not in ('cancelled','no_show')
        and b.time_range && tsrange(
              p_date + gs::time,
              p_date + gs::time + make_interval(mins => p_service_duration_minutes),
              '[)'
            )
    )
    -- bloqueo de un tramo del día (ej. un trámite puntual)
    and not exists (
      select 1 from barber_time_off t
      where t.barber_id = p_barber_id
        and p_date between t.start_date and t.end_date
        and t.start_time is not null
        and tsrange(
              p_date + gs::time,
              p_date + gs::time + make_interval(mins => p_service_duration_minutes),
              '[)'
            ) && tsrange(p_date + t.start_time, p_date + t.end_time, '[)')
    );
end;
$$;
