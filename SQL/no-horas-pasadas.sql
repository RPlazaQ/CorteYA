-- No permitir reservar horas que ya pasaron el día de hoy.
-- Antes, get_available_slots devolvía todo el horario del día completo sin
-- fijarse en la hora actual, así que se podía "reservar" para las 10am
-- aunque ya fueran las 6pm. Esto corrige dos capas: la función que calcula
-- horarios disponibles (lo que ve el cliente) y la política de la base de
-- datos (para que tampoco se pueda forzar por fuera de la app).

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

  if exists (
    select 1 from barber_time_off
    where barber_id = p_barber_id and p_date between start_date and end_date
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
  where (p_date > v_now::date or gs::time >= v_now::time)
    and not exists (
      select 1 from bookings b
      where b.barber_id = p_barber_id
        and b.status = 'confirmed'
        and b.time_range && tsrange(
              p_date + gs::time,
              p_date + gs::time + make_interval(mins => p_service_duration_minutes),
              '[)'
            )
    );
end;
$$;

alter policy "guest can create a booking" on bookings
  with check (
    status = 'confirmed'
    and booking_date >= (now() at time zone 'America/Santiago')::date
    and booking_date <  (now() at time zone 'America/Santiago')::date + 30
    and (
      booking_date > (now() at time zone 'America/Santiago')::date
      or start_time >= (now() at time zone 'America/Santiago')::time
    )
  );
