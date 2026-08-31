-- CorteYa — schema inicial (piloto 1-2 barberías)
-- Pegar completo en Supabase: Dashboard del proyecto -> SQL Editor -> New query -> Run

create extension if not exists pgcrypto;
create schema if not exists extensions;
create extension if not exists btree_gist with schema extensions;

-- ============ TABLAS ============

create table barbershops (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid references auth.users(id),
  name         text not null,
  slug         text unique not null,
  address      text,
  lat          numeric,
  lng          numeric,
  phone        text,
  rating       numeric default 0,
  image_url    text,
  timezone     text not null default 'America/Santiago',
  created_at   timestamptz not null default now()
);

create table barbers (
  id             uuid primary key default gen_random_uuid(),
  barbershop_id  uuid not null references barbershops(id) on delete cascade,
  name           text not null,
  specialty      text,
  photo_url      text,
  active         boolean not null default true,
  created_at     timestamptz not null default now()
);

create table services (
  id               uuid primary key default gen_random_uuid(),
  barbershop_id    uuid not null references barbershops(id) on delete cascade,
  name             text not null,
  duration_minutes int not null check (duration_minutes > 0),
  price_clp        int not null check (price_clp >= 0),
  active           boolean not null default true,
  created_at       timestamptz not null default now()
);

-- weekday: 0=domingo .. 6=sábado (convención de Postgres extract(dow from date))
create table barber_working_hours (
  id          uuid primary key default gen_random_uuid(),
  barber_id   uuid not null references barbers(id) on delete cascade,
  weekday     int not null check (weekday between 0 and 6),
  start_time  time not null,
  end_time    time not null check (end_time > start_time),
  unique (barber_id, weekday)
);

create table barber_time_off (
  id          uuid primary key default gen_random_uuid(),
  barber_id   uuid not null references barbers(id) on delete cascade,
  start_date  date not null,
  end_date    date not null check (end_date >= start_date)
);

create table bookings (
  id              uuid primary key default gen_random_uuid(),
  barbershop_id   uuid not null references barbershops(id),
  barber_id       uuid not null references barbers(id),
  service_id      uuid not null references services(id),
  customer_name   text not null,
  customer_phone  text not null check (customer_phone ~ '^[+0-9 ()-]{8,15}$'),
  customer_email  text,
  booking_date    date not null,
  start_time      time not null,
  end_time        time not null check (end_time > start_time),
  status          text not null default 'confirmed'
                   check (status in ('confirmed','cancelled','completed','no_show')),
  created_at      timestamptz not null default now(),
  notes           text,
  time_range tsrange generated always as (
    tsrange(booking_date + start_time, booking_date + end_time, '[)')
  ) stored
);

-- Anti-doble-reserva a nivel de base de datos: rechaza cualquier traslape
-- de horario para el mismo barbero, sin importar qué tan rápido lleguen
-- dos reservas casi al mismo tiempo.
alter table bookings
  add constraint no_overlapping_confirmed_bookings
  exclude using gist (
    barber_id with =,
    time_range with &&
  ) where (status = 'confirmed');

-- ============ DISPONIBILIDAD (función) ============

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
  -- si la fecha consultada es hoy, no ofrecer horas que ya pasaron
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

revoke all on function get_available_slots from public;
grant execute on function get_available_slots to anon;

-- ============ SEGURIDAD (RLS) ============

alter table barbershops enable row level security;
alter table barbers enable row level security;
alter table services enable row level security;
alter table barber_working_hours enable row level security;
alter table barber_time_off enable row level security;
alter table bookings enable row level security;

-- barbershops: lectura pública (para buscar/ver barberías), solo el dueño edita la suya
create policy "public read barbershops" on barbershops
  for select using (true);
create policy "owner updates own barbershop" on barbershops
  for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- barbers: lectura pública de los activos, dueño administra los suyos
create policy "public read active barbers" on barbers
  for select using (active = true);
create policy "owner manages own barbers" on barbers
  for all using (barbershop_id in (select id from barbershops where owner_id = auth.uid()))
  with check (barbershop_id in (select id from barbershops where owner_id = auth.uid()));

-- services: mismo patrón que barbers
create policy "public read active services" on services
  for select using (active = true);
create policy "owner manages own services" on services
  for all using (barbershop_id in (select id from barbershops where owner_id = auth.uid()))
  with check (barbershop_id in (select id from barbershops where owner_id = auth.uid()));

-- horarios y ausencias: NO son de lectura pública (solo la función de disponibilidad
-- los usa "por dentro"); el dueño administra los de su propia barbería
create policy "owner manages own working hours" on barber_working_hours
  for all using (barber_id in (
    select b.id from barbers b join barbershops s on s.id = b.barbershop_id
    where s.owner_id = auth.uid()
  )) with check (barber_id in (
    select b.id from barbers b join barbershops s on s.id = b.barbershop_id
    where s.owner_id = auth.uid()
  ));

create policy "owner manages own time off" on barber_time_off
  for all using (barber_id in (
    select b.id from barbers b join barbershops s on s.id = b.barbershop_id
    where s.owner_id = auth.uid()
  )) with check (barber_id in (
    select b.id from barbers b join barbershops s on s.id = b.barbershop_id
    where s.owner_id = auth.uid()
  ));

-- bookings: cualquiera puede CREAR una reserva (como invitado), pero nadie
-- público puede LEER reservas (tienen datos de otros clientes). El dueño
-- lee y actualiza solo las de su propia barbería.
create policy "guest can create a booking" on bookings
  for insert with check (
    status = 'confirmed'
    and booking_date >= (now() at time zone 'America/Santiago')::date
    and booking_date <  (now() at time zone 'America/Santiago')::date + 30
    -- si la reserva es para hoy, la hora no puede ser una que ya pasó
    and (
      booking_date > (now() at time zone 'America/Santiago')::date
      or start_time >= (now() at time zone 'America/Santiago')::time
    )
  );
create policy "owner reads own bookings" on bookings
  for select using (barbershop_id in (select id from barbershops where owner_id = auth.uid()));
create policy "owner updates own bookings" on bookings
  for update using (barbershop_id in (select id from barbershops where owner_id = auth.uid()))
  with check (barbershop_id in (select id from barbershops where owner_id = auth.uid()));
