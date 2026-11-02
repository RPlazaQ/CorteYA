-- Barbería de demo para capturas de la guía de onboarding. Todo este
-- archivo es seguro de volver a correr completo las veces que quieras
-- (usa ids fijos + on conflict / delete-antes-de-insertar) y las fechas
-- de las reservas siempre son relativas a current_date / now(), así que
-- "refrescar la demo" es simplemente volver a correr el archivo entero.
--
-- No toca ninguna barbería real: todo vive bajo el barbershop_id fijo
-- 44444444-4444-4444-8444-444444444444, nuevo, que no existía antes.
--
-- El dueño de esta barbería (auth.users) ya se creó desde afuera, vía el
-- endpoint público de signup (no hacía falta service_role para eso):
--   email:    demo.central@corteya.app
--   user_id:  ecb63c59-16dd-4a0f-ba99-c7cbacca036d
-- La contraseña temporal NO va en este archivo (no debe quedar en el
-- historial de git) — te la paso aparte, por chat. Puedes cambiarla
-- después desde Info → Seguridad una vez que entres.
--
-- Cómo correrlo: pega este archivo completo en el SQL Editor de Supabase
-- y ejecútalo. Para refrescar la demo más adelante (otras fechas),
-- vuelve a correr el archivo completo tal cual.
--
-- Reversible por completo:
--   delete from barbershops where id = '44444444-4444-4444-8444-444444444444';
--   (el cascade de las FKs se encarga de barbers/services/bookings/etc.
--   barber_services y barber_working_hours también caen en cascada vía barbers)
--   -- y, si quieres borrar también la cuenta del dueño, eso sí requiere
--   -- el dashboard de Supabase (Authentication -> Users -> eliminar
--   -- demo.central@corteya.app), no se puede desde SQL plano.

-- =========================================================
-- 0. columna para apagar WhatsApp por barbería (hallazgo #5 de la
--    auditoría) — aditiva, default true, no cambia nada para las
--    barberías que ya existen.
-- =========================================================
alter table barbershops add column if not exists whatsapp_enabled boolean not null default true;

create or replace function notify_whatsapp_nueva_reserva() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_barbershop_phone text;
  v_barber_name text;
  v_service_name text;
  v_token text;
  v_phone_number_id text;
  v_to_digits text;
  v_whatsapp_enabled boolean;
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  select phone, whatsapp_enabled into v_barbershop_phone, v_whatsapp_enabled
  from barbershops where id = new.barbershop_id;

  if v_barbershop_phone is null or not v_whatsapp_enabled then
    return new;
  end if;

  select b.name, sv.name into v_barber_name, v_service_name
  from barbers b, services sv
  where b.id = new.barber_id and sv.id = new.service_id;

  select value into v_token from app_secrets where key = 'whatsapp_token';
  select value into v_phone_number_id from app_secrets where key = 'whatsapp_phone_number_id';

  if v_token is null or v_phone_number_id is null then
    return new;
  end if;

  v_to_digits := regexp_replace(v_barbershop_phone, '[^0-9]', '', 'g');

  perform net.http_post(
    url := 'https://graph.facebook.com/v26.0/' || v_phone_number_id || '/messages',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_token
    ),
    body := jsonb_build_object(
      'messaging_product', 'whatsapp',
      'to', v_to_digits,
      'type', 'template',
      'template', jsonb_build_object(
        'name', 'nueva_reserva_barbero',
        'language', jsonb_build_object('code', 'es'),
        'components', jsonb_build_array(
          jsonb_build_object(
            'type', 'body',
            'parameters', jsonb_build_array(
              jsonb_build_object('type', 'text', 'text', v_service_name),
              jsonb_build_object('type', 'text', 'text', to_char(new.booking_date, 'DD/MM/YYYY')),
              jsonb_build_object('type', 'text', 'text', to_char(new.start_time, 'HH24:MI')),
              jsonb_build_object('type', 'text', 'text', v_barber_name),
              jsonb_build_object('type', 'text', 'text', new.customer_name),
              jsonb_build_object('type', 'text', 'text', coalesce(new.customer_phone, 'Sin teléfono'))
            )
          )
        )
      )
    )
  );

  update bookings set owner_notified_at = now() where id = new.id;
  return new;
end;
$$;

create or replace function notify_whatsapp_confirmacion_cliente() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_barbershop_name text;
  v_barber_name text;
  v_service_name text;
  v_token text;
  v_phone_number_id text;
  v_to_digits text;
  v_whatsapp_enabled boolean;
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  if new.customer_phone is null then
    raise log 'Confirmación WhatsApp omitida (sin teléfono): booking %', new.id;
    return new;
  end if;

  select s.name, b.name, sv.name, s.whatsapp_enabled
  into v_barbershop_name, v_barber_name, v_service_name, v_whatsapp_enabled
  from barbershops s, barbers b, services sv
  where s.id = new.barbershop_id and b.id = new.barber_id and sv.id = new.service_id;

  if v_barbershop_name is null or not v_whatsapp_enabled then
    return new;
  end if;

  select value into v_token from app_secrets where key = 'whatsapp_token';
  select value into v_phone_number_id from app_secrets where key = 'whatsapp_phone_number_id';

  if v_token is null or v_phone_number_id is null then
    return new;
  end if;

  v_to_digits := regexp_replace(new.customer_phone, '[^0-9]', '', 'g');

  perform net.http_post(
    url := 'https://graph.facebook.com/v26.0/' || v_phone_number_id || '/messages',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_token
    ),
    body := jsonb_build_object(
      'messaging_product', 'whatsapp',
      'to', v_to_digits,
      'type', 'template',
      'template', jsonb_build_object(
        'name', 'confirmacion_cita_dia_v1',
        'language', jsonb_build_object('code', 'es'),
        'components', jsonb_build_array(
          jsonb_build_object(
            'type', 'body',
            'parameters', jsonb_build_array(
              jsonb_build_object('type', 'text', 'text', new.customer_name),
              jsonb_build_object('type', 'text', 'text', v_barbershop_name),
              jsonb_build_object('type', 'text', 'text', v_service_name),
              jsonb_build_object('type', 'text', 'text', v_barber_name),
              jsonb_build_object('type', 'text', 'text', to_char(new.booking_date, 'DD/MM/YYYY')),
              jsonb_build_object('type', 'text', 'text', to_char(new.start_time, 'HH24:MI'))
            )
          )
        )
      )
    )
  );

  update bookings set client_confirmed_at = now() where id = new.id;
  return new;
end;
$$;

create or replace function send_whatsapp_reminders() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  r record;
  v_token text;
  v_phone_number_id text;
  v_to_digits text;
begin
  select value into v_token from app_secrets where key = 'whatsapp_token';
  select value into v_phone_number_id from app_secrets where key = 'whatsapp_phone_number_id';

  if v_token is null or v_phone_number_id is null then
    return;
  end if;

  for r in
    select bk.id, bk.customer_name, bk.customer_phone, bk.booking_date, bk.start_time,
           s.name as barbershop_name, b.name as barber_name, sv.name as service_name
    from bookings bk
    join barbershops s on s.id = bk.barbershop_id
    join barbers b on b.id = bk.barber_id
    join services sv on sv.id = bk.service_id
    where bk.status = 'confirmed'
      and bk.reminder_sent_at is null
      and bk.customer_phone is not null
      and s.whatsapp_enabled = true
      and bk.booking_date = (now() at time zone 'America/Santiago')::date
      and extract(hour from now() at time zone 'America/Santiago') = 8
  loop
    v_to_digits := regexp_replace(r.customer_phone, '[^0-9]', '', 'g');

    perform net.http_post(
      url := 'https://graph.facebook.com/v26.0/' || v_phone_number_id || '/messages',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_token
      ),
      body := jsonb_build_object(
        'messaging_product', 'whatsapp',
        'to', v_to_digits,
        'type', 'template',
        'template', jsonb_build_object(
          'name', 'recordatorio_cita_cliente_v2',
          'language', jsonb_build_object('code', 'es'),
          'components', jsonb_build_array(
            jsonb_build_object(
              'type', 'body',
              'parameters', jsonb_build_array(
                jsonb_build_object('type', 'text', 'text', r.customer_name),
                jsonb_build_object('type', 'text', 'text', r.barbershop_name),
                jsonb_build_object('type', 'text', 'text', r.service_name),
                jsonb_build_object('type', 'text', 'text', r.barber_name),
                jsonb_build_object('type', 'text', 'text', to_char(r.booking_date, 'DD/MM/YYYY')),
                jsonb_build_object('type', 'text', 'text', to_char(r.start_time, 'HH24:MI'))
              )
            )
          )
        )
      )
    );

    update bookings set reminder_sent_at = now() where id = r.id;
  end loop;
end;
$$;

-- =========================================================
-- 1. la barbería y su dueño (ids fijos, re-corrible con on conflict)
-- =========================================================
insert into barbershops (id, owner_id, name, slug, address, phone, plan, whatsapp_enabled)
values (
  '44444444-4444-4444-8444-444444444444',
  'ecb63c59-16dd-4a0f-ba99-c7cbacca036d',
  'Barbería Central',
  'barberia-central',
  'Av. Providencia 1234, Providencia',
  '+56 9 1234 5678',
  'piloto',
  false
)
on conflict (id) do update set
  name = excluded.name, address = excluded.address, phone = excluded.phone, whatsapp_enabled = false;

-- =========================================================
-- 2. barberos, horarios y servicios (setup estable, también re-corrible)
-- =========================================================
insert into barbers (id, barbershop_id, name, bio, active) values
  ('44444444-4444-4444-8444-444444444441', '44444444-4444-4444-8444-444444444444', 'Nico',   'Especialista en fade', true),
  ('44444444-4444-4444-8444-444444444442', '44444444-4444-4444-8444-444444444444', 'Tomás',  'Corte y barba', true),
  ('44444444-4444-4444-8444-444444444443', '44444444-4444-4444-8444-444444444444', 'Caro',   'Cortes clásicos', true)
on conflict (id) do update set name = excluded.name, bio = excluded.bio, active = true;

delete from barber_working_hours where barber_id in (
  '44444444-4444-4444-8444-444444444441', '44444444-4444-4444-8444-444444444442', '44444444-4444-4444-8444-444444444443'
);
insert into barber_working_hours (barber_id, weekday, start_time, end_time)
select '44444444-4444-4444-8444-444444444441', wd, '10:00', '20:00' from generate_series(1, 6) wd
union all
select '44444444-4444-4444-8444-444444444442', wd, '11:00', '20:00' from generate_series(1, 5) wd
union all
select '44444444-4444-4444-8444-444444444443', wd, '10:00', '19:00' from generate_series(2, 6) wd;

insert into services (id, barbershop_id, name, duration_minutes, price_clp, active) values
  ('44444444-4444-4444-8444-444444444451', '44444444-4444-4444-8444-444444444444', 'Corte clásico',        30,  8000,  true),
  ('44444444-4444-4444-8444-444444444452', '44444444-4444-4444-8444-444444444444', 'Corte + Barba',        45,  12000, true),
  ('44444444-4444-4444-8444-444444444453', '44444444-4444-4444-8444-444444444444', 'Fade',                 45,  10000, true),
  ('44444444-4444-4444-8444-444444444454', '44444444-4444-4444-8444-444444444444', 'Perfilado de barba',   20,  6000,  true),
  ('44444444-4444-4444-8444-444444444455', '44444444-4444-4444-8444-444444444444', 'Corte + Tintura',      60,  45000, true)
on conflict (id) do update set name = excluded.name, duration_minutes = excluded.duration_minutes, price_clp = excluded.price_clp;

delete from barber_services where barber_id in (
  '44444444-4444-4444-8444-444444444441', '44444444-4444-4444-8444-444444444442', '44444444-4444-4444-8444-444444444443'
);
insert into barber_services (barber_id, service_id) values
  ('44444444-4444-4444-8444-444444444441', '44444444-4444-4444-8444-444444444451'), -- Nico: Corte clásico
  ('44444444-4444-4444-8444-444444444441', '44444444-4444-4444-8444-444444444453'), -- Nico: Fade
  ('44444444-4444-4444-8444-444444444441', '44444444-4444-4444-8444-444444444452'), -- Nico: Corte+Barba
  ('44444444-4444-4444-8444-444444444442', '44444444-4444-4444-8444-444444444451'), -- Tomás: Corte clásico
  ('44444444-4444-4444-8444-444444444442', '44444444-4444-4444-8444-444444444452'), -- Tomás: Corte+Barba
  ('44444444-4444-4444-8444-444444444442', '44444444-4444-4444-8444-444444444454'), -- Tomás: Perfilado
  ('44444444-4444-4444-8444-444444444443', '44444444-4444-4444-8444-444444444451'), -- Caro: Corte clásico
  ('44444444-4444-4444-8444-444444444443', '44444444-4444-4444-8444-444444444453'), -- Caro: Fade
  ('44444444-4444-4444-8444-444444444443', '44444444-4444-4444-8444-444444444455'); -- Caro: Corte+Tintura

-- =========================================================
-- 3. reservas y bloqueo — ESTA parte se borra y se regenera cada vez
--    que corras el archivo completo, siempre relativa a current_date/now()
-- =========================================================
delete from bookings where barbershop_id = '44444444-4444-4444-8444-444444444444';
delete from barber_time_off where barber_id in (
  '44444444-4444-4444-8444-444444444441', '44444444-4444-4444-8444-444444444442', '44444444-4444-4444-8444-444444444443'
);

-- bloqueo de ejemplo: Tomás mañana de 13:00 a 14:00
insert into barber_time_off (barber_id, start_date, end_date, start_time, end_time) values
  ('44444444-4444-4444-8444-444444444442', current_date + 1, current_date + 1, '13:00', '14:00');

-- 3a. últimos 14 días (~42 citas históricas): un barbero fijo por fila
-- con su servicio habitual, created_at en el pasado (igual a la fecha de
-- la cita) para no activar el límite de velocidad de reservas recientes.
with barberos as (
  select * from (values
    ('44444444-4444-4444-8444-444444444441'::uuid, 1, '44444444-4444-4444-8444-444444444451'::uuid, 30),  -- Nico / Corte clásico
    ('44444444-4444-4444-8444-444444444442'::uuid, 2, '44444444-4444-4444-8444-444444444452'::uuid, 45),  -- Tomás / Corte+Barba
    ('44444444-4444-4444-8444-444444444443'::uuid, 3, '44444444-4444-4444-8444-444444444455'::uuid, 60)   -- Caro / Corte+Tintura
  ) as t(barber_id, idx, service_id, duracion)
),
clientes as (
  select nombre, '+56 9 0000 0' || lpad(n::text, 3, '0') as telefono, n
  from (values
    ('Matías Rojas',1), ('Camila Soto',2), ('Diego Fuentes',3), ('Valentina Muñoz',4),
    ('Sebastián Reyes',5), ('Javiera Castro',6), ('Benjamín Torres',7), ('Antonia Vidal',8),
    ('Tomás Araya',9), ('Francisca Leiva',10), ('Joaquín Pizarro',11), ('Catalina Flores',12),
    ('Ignacio Bravo',13), ('Fernanda Campos',14), ('Cristóbal Morales',15), ('Isidora Sepúlveda',16)
  ) as t(nombre, n)
),
historicos as (
  select
    b.barber_id, b.service_id, b.duracion, b.idx, d,
    (current_date - d) as fecha,
    ('09:00'::time + (((d + b.idx) % 8) * interval '1 hour')) as hora_inicio
  from generate_series(1, 14) as d
  cross join barberos b
)
insert into bookings (barbershop_id, barber_id, service_id, customer_name, customer_phone, booking_date, start_time, end_time, status, created_at)
select
  '44444444-4444-4444-8444-444444444444',
  h.barber_id, h.service_id, c.nombre, c.telefono,
  h.fecha, h.hora_inicio, h.hora_inicio + (h.duracion || ' minutes')::interval,
  case
    when (h.d + h.idx) % 11 = 0 then 'no_show'
    when (h.d + h.idx) % 3 = 0 then 'paid_transfer'
    when (h.d + h.idx) % 3 = 1 then 'paid_card'
    else 'paid_cash'
  end,
  h.fecha + h.hora_inicio
from historicos h
join clientes c on c.n = ((h.d * 3 + h.idx) % 16) + 1;

-- 3b. hoy (8 citas): las de hora ya pasada quedan marcadas como
-- pagadas (rotando método), las futuras quedan "confirmed" — se
-- recalcula solo según la hora real al momento de correr el script.
with hoy_citas as (
  select * from (values
    ('44444444-4444-4444-8444-444444444441'::uuid, '44444444-4444-4444-8444-444444444451'::uuid, 30, '10:00'::time, 'Matías Rojas',     '+56 9 0000 0101'),
    ('44444444-4444-4444-8444-444444444441'::uuid, '44444444-4444-4444-8444-444444444453'::uuid, 45, '12:00'::time, 'Camila Soto',      '+56 9 0000 0102'),
    ('44444444-4444-4444-8444-444444444441'::uuid, '44444444-4444-4444-8444-444444444452'::uuid, 45, '17:00'::time, 'Diego Fuentes',    '+56 9 0000 0103'),
    ('44444444-4444-4444-8444-444444444442'::uuid, '44444444-4444-4444-8444-444444444451'::uuid, 30, '11:00'::time, 'Valentina Muñoz',  '+56 9 0000 0104'),
    ('44444444-4444-4444-8444-444444444442'::uuid, '44444444-4444-4444-8444-444444444454'::uuid, 20, '14:00'::time, 'Sebastián Reyes',  '+56 9 0000 0105'),
    ('44444444-4444-4444-8444-444444444442'::uuid, '44444444-4444-4444-8444-444444444452'::uuid, 45, '18:00'::time, 'Javiera Castro',   '+56 9 0000 0106'),
    ('44444444-4444-4444-8444-444444444443'::uuid, '44444444-4444-4444-8444-444444444451'::uuid, 30, '10:30'::time, 'Benjamín Torres',  '+56 9 0000 0107'),
    ('44444444-4444-4444-8444-444444444443'::uuid, '44444444-4444-4444-8444-444444444455'::uuid, 60, '16:00'::time, 'Antonia Vidal',    '+56 9 0000 0108')
  ) as t(barber_id, service_id, duracion, hora, nombre, telefono)
)
insert into bookings (barbershop_id, barber_id, service_id, customer_name, customer_phone, booking_date, start_time, end_time, status, created_at)
select
  '44444444-4444-4444-8444-444444444444',
  barber_id, service_id, nombre, telefono,
  current_date, hora, hora + (duracion || ' minutes')::interval,
  case
    when hora < (now() at time zone 'America/Santiago')::time
      then (array['paid_cash', 'paid_transfer', 'paid_card'])[1 + (extract(hour from hora)::int % 3)]
    else 'confirmed'
  end,
  now()
from hoy_citas;

-- 3c. próximos 3 días (10 citas futuras, todas "confirmed")
with proximos as (
  select * from (values
    (1, '44444444-4444-4444-8444-444444444441'::uuid, '44444444-4444-4444-8444-444444444451'::uuid, 30, '10:00'::time, 'Tomás Araya',       '+56 9 0000 0109'),
    (1, '44444444-4444-4444-8444-444444444442'::uuid, '44444444-4444-4444-8444-444444444452'::uuid, 45, '15:00'::time, 'Francisca Leiva',   '+56 9 0000 0110'),
    (1, '44444444-4444-4444-8444-444444444443'::uuid, '44444444-4444-4444-8444-444444444453'::uuid, 45, '11:00'::time, 'Joaquín Pizarro',   '+56 9 0000 0111'),
    (2, '44444444-4444-4444-8444-444444444441'::uuid, '44444444-4444-4444-8444-444444444453'::uuid, 45, '13:00'::time, 'Catalina Flores',   '+56 9 0000 0112'),
    (2, '44444444-4444-4444-8444-444444444442'::uuid, '44444444-4444-4444-8444-444444444451'::uuid, 30, '16:00'::time, 'Ignacio Bravo',     '+56 9 0000 0113'),
    (2, '44444444-4444-4444-8444-444444444443'::uuid, '44444444-4444-4444-8444-444444444455'::uuid, 60, '10:00'::time, 'Fernanda Campos',   '+56 9 0000 0114'),
    (3, '44444444-4444-4444-8444-444444444441'::uuid, '44444444-4444-4444-8444-444444444452'::uuid, 45, '12:00'::time, 'Cristóbal Morales', '+56 9 0000 0115'),
    (3, '44444444-4444-4444-8444-444444444442'::uuid, '44444444-4444-4444-8444-444444444454'::uuid, 20, '11:30'::time, 'Isidora Sepúlveda', '+56 9 0000 0116'),
    (3, '44444444-4444-4444-8444-444444444443'::uuid, '44444444-4444-4444-8444-444444444451'::uuid, 30, '17:00'::time, 'Matías Rojas',      '+56 9 0000 0117'),
    (3, '44444444-4444-4444-8444-444444444441'::uuid, '44444444-4444-4444-8444-444444444451'::uuid, 30, '18:00'::time, 'Camila Soto',       '+56 9 0000 0118')
  ) as t(dia_offset, barber_id, service_id, duracion, hora, nombre, telefono)
)
insert into bookings (barbershop_id, barber_id, service_id, customer_name, customer_phone, booking_date, start_time, end_time, status, created_at)
select
  '44444444-4444-4444-8444-444444444444',
  barber_id, service_id, nombre, telefono,
  current_date + dia_offset, hora, hora + (duracion || ' minutes')::interval,
  'confirmed', now()
from proximos;

-- =========================================================
-- Cómo probar:
--   1. select count(*) from bookings where barbershop_id = '44444444-4444-4444-8444-444444444444';
--      -> debería dar ~60 (42 históricas + 8 hoy + 10 próximos).
--   2. Entra con demo.central@corteya.app y la contraseña que te pasé por
--      chat. Hoy debería verse con citas pasadas ya pagadas y futuras
--      pendientes; Reportes debería mostrar números de los últimos 14
--      días; Calendario debería verse con movimiento en los próximos 3 días.
--   3. Revisa que NO haya llegado ningún WhatsApp real a los teléfonos
--      +56 9 0000 0XXX (ni al dueño ni a ningún "cliente").
--   4. Para refrescar la demo más adelante, vuelve a correr este archivo
--      completo tal cual — se borra y regenera todo lo de la sección 3.
-- =========================================================
