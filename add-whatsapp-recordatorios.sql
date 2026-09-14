-- Confirmación y recordatorio automático por WhatsApp.
--
-- Todo el envío corre DENTRO de Supabase (trigger + pg_cron llamando a
-- pg_net), no en el navegador del cliente ni en el dashboard. Así las
-- funciones de Netlify que de verdad hablan con la API de Meta nunca
-- necesitan leer la base de datos — solo reciben un payload ya armado
-- y lo reenvían a WhatsApp. Esto evita tener que exponer ningún tipo de
-- llave de administrador de Supabase hacia afuera.
--
-- IMPORTANTE — antes de correr este archivo, corre por separado (fuera
-- de git, te lo paso por chat) este comando con el secreto real:
--   alter database postgres set app.settings.whatsapp_webhook_secret = '<secreto>';
-- Ese secreto tiene que ser EXACTAMENTE el mismo valor que la variable
-- de entorno WHATSAPP_WEBHOOK_SECRET en Netlify (ya la dejo configurada
-- yo por API). Sirve para que nadie pueda golpear las funciones de
-- Netlify desde afuera y hacernos mandar WhatsApps arbitrarios con nuestro
-- número de negocio.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

alter table bookings add column if not exists confirmation_sent_at timestamptz;
alter table bookings add column if not exists reminder_sent_at timestamptz;

create or replace function notify_whatsapp_confirmacion() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_barbershop_name text;
  v_barber_name text;
  v_service_name text;
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  select s.name, b.name, sv.name
  into v_barbershop_name, v_barber_name, v_service_name
  from barbershops s, barbers b, services sv
  where s.id = new.barbershop_id and b.id = new.barber_id and sv.id = new.service_id;

  perform net.http_post(
    url := 'https://corteya.app/.netlify/functions/whatsapp-confirmacion',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-CorteYa-Secret', current_setting('app.settings.whatsapp_webhook_secret', true)
    ),
    body := jsonb_build_object(
      'booking_id', new.id,
      'customer_name', new.customer_name,
      'customer_phone', new.customer_phone,
      'barbershop_name', v_barbershop_name,
      'barber_name', v_barber_name,
      'service_name', v_service_name,
      'booking_date', new.booking_date,
      'start_time', new.start_time
    )
  );

  update bookings set confirmation_sent_at = now() where id = new.id;
  return new;
end;
$$;

drop trigger if exists trg_whatsapp_confirmacion on bookings;
create trigger trg_whatsapp_confirmacion
after insert on bookings
for each row execute function notify_whatsapp_confirmacion();

-- Recordatorio: cada 15 minutos revisa reservas confirmadas que empiezan
-- entre 60 y 75 minutos desde ahora y que todavía no tengan recordatorio
-- mandado (la ventana de 15 min evita que el mismo booking se procese dos
-- veces entre una corrida y la siguiente).
create or replace function send_whatsapp_recordatorios() returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  r record;
begin
  for r in
    select bk.id, bk.customer_name, bk.customer_phone, bk.booking_date, bk.start_time,
           s.name as barbershop_name, b.name as barber_name, sv.name as service_name
    from bookings bk
    join barbershops s on s.id = bk.barbershop_id
    join barbers b on b.id = bk.barber_id
    join services sv on sv.id = bk.service_id
    where bk.status not in ('cancelled', 'no_show')
      and bk.reminder_sent_at is null
      and (bk.booking_date + bk.start_time) between
          (now() at time zone 'America/Santiago') + interval '60 minutes'
          and (now() at time zone 'America/Santiago') + interval '75 minutes'
  loop
    perform net.http_post(
      url := 'https://corteya.app/.netlify/functions/whatsapp-recordatorio',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-CorteYa-Secret', current_setting('app.settings.whatsapp_webhook_secret', true)
      ),
      body := jsonb_build_object(
        'booking_id', r.id,
        'customer_name', r.customer_name,
        'customer_phone', r.customer_phone,
        'barbershop_name', r.barbershop_name,
        'barber_name', r.barber_name,
        'service_name', r.service_name,
        'booking_date', r.booking_date,
        'start_time', r.start_time
      )
    );
    update bookings set reminder_sent_at = now() where id = r.id;
  end loop;
end;
$$;

select cron.schedule('whatsapp-recordatorios', '*/15 * * * *', 'select send_whatsapp_recordatorios();');
