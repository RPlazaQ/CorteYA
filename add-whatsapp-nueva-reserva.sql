-- Aviso por WhatsApp al BARBERO (no al cliente) cada vez que se crea una
-- reserva nueva en su agenda.
--
-- Por qué al barbero y no al cliente: en modo prueba, Meta solo deja
-- mandar mensajes a hasta 5 números aprobados a mano — no sirve para
-- avisarle a clientes reales todavía. El número del barbero sí puede ser
-- uno de esos 5, así que por ahora el valor real es: "avísame apenas
-- alguien me agenda una hora". La confirmación/recordatorio al cliente
-- queda pendiente para cuando pasemos a número real + verificación de
-- negocio de Meta (ver whatsapp-agente.md).
--
-- Igual que antes: todo corre dentro de Supabase (trigger + pg_net), la
-- función de Netlify no lee la base de datos, solo reenvía el payload ya
-- armado a la API de WhatsApp.
--
-- IMPORTANTE — antes de correr este archivo, corre por separado (fuera
-- de git, te lo paso por chat) este comando con el secreto real:
--   alter database postgres set app.settings.whatsapp_webhook_secret = '<secreto>';
-- Ese secreto tiene que ser EXACTAMENTE el mismo valor que la variable de
-- entorno WHATSAPP_WEBHOOK_SECRET en Netlify.

create extension if not exists pg_net with schema extensions;

alter table bookings add column if not exists owner_notified_at timestamptz;

create or replace function notify_whatsapp_nueva_reserva() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_barbershop_phone text;
  v_barber_name text;
  v_service_name text;
begin
  if new.status <> 'confirmed' then
    return new;
  end if;

  select s.phone, b.name, sv.name
  into v_barbershop_phone, v_barber_name, v_service_name
  from barbershops s, barbers b, services sv
  where s.id = new.barbershop_id and b.id = new.barber_id and sv.id = new.service_id;

  if v_barbershop_phone is null then
    return new;
  end if;

  perform net.http_post(
    url := 'https://corteya.app/.netlify/functions/whatsapp-nueva-reserva',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-CorteYa-Secret', current_setting('app.settings.whatsapp_webhook_secret', true)
    ),
    body := jsonb_build_object(
      'booking_id', new.id,
      'barbershop_phone', v_barbershop_phone,
      'barber_name', v_barber_name,
      'service_name', v_service_name,
      'customer_name', new.customer_name,
      'customer_phone', new.customer_phone,
      'booking_date', new.booking_date,
      'start_time', new.start_time
    )
  );

  update bookings set owner_notified_at = now() where id = new.id;
  return new;
end;
$$;

drop trigger if exists trg_whatsapp_confirmacion on bookings;
drop trigger if exists trg_whatsapp_nueva_reserva on bookings;
create trigger trg_whatsapp_nueva_reserva
after insert on bookings
for each row execute function notify_whatsapp_nueva_reserva();
