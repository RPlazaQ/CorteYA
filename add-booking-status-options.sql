-- Amplía los estados posibles de una reserva más allá de
-- confirmed/cancelled/completed/no_show, para que el barbero pueda marcar
-- cómo se pagó una cita o si se reagendó, cada uno con su propio color en
-- el dashboard.
--
-- Los estados "activos" (que siguen ocupando el horario del barbero, y por
-- lo tanto bloquean ese cupo para nuevas reservas) son todos menos
-- 'cancelled' y 'no_show'.

alter table bookings drop constraint if exists bookings_status_check;
alter table bookings add constraint bookings_status_check
  check (status in ('confirmed','rescheduled','paid_cash','paid_transfer','paid_card','completed','cancelled','no_show'));

alter table bookings drop constraint if exists no_overlapping_confirmed_bookings;
alter table bookings add constraint no_overlapping_active_bookings
  exclude using gist (
    barber_id with =,
    time_range with &&
  ) where (status not in ('cancelled','no_show'));

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
        and b.status not in ('cancelled','no_show')
        and b.time_range && tsrange(
              p_date + gs::time,
              p_date + gs::time + make_interval(mins => p_service_duration_minutes),
              '[)'
            )
    );
end;
$$;

revoke all on function get_available_slots from public;
grant execute on function get_available_slots to anon;
