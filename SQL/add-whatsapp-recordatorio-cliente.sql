-- Recordatorio automático al cliente 2-3 horas antes de su cita.
--
-- Por qué así: a diferencia del aviso al barbero (que se dispara al
-- crear la reserva, ver fix-whatsapp-direct-meta.sql), este mensaje
-- tiene que salir cerca de la hora de la cita, no al momento de agendar.
-- Postgres no tiene "programar esto para dentro de 3 horas" nativo, así
-- que se resuelve con un cron job (pg_cron) que corre cada 15 minutos y
-- revisa qué reservas caen dentro de la ventana de 2 a 3 horas antes de
-- su horario. Apenas una reserva entra en esa ventana se manda una vez
-- y se marca (reminder_sent_at) para no repetirla en la siguiente
-- pasada del cron. La ventana de 1 hora de ancho + chequeo cada 15 min
-- da margen de sobra aunque el cron se atrase o se salte una pasada.
--
-- Requisitos antes de correr esto:
--   1. Extensión pg_cron habilitada — Supabase: Database -> Extensions
--      -> busca "pg_cron" -> Enable (pg_net ya debería estar habilitada,
--      la usa el trigger del aviso al barbero).
--   2. La plantilla 'recordatorio_cita_cliente_v2' debe existir y estar
--      APPROVED en Meta para que el envío real funcione — este cron se
--      puede crear igual desde ya, simplemente no entregará mensajes
--      hasta que la plantilla esté aprobada (el intento queda registrado
--      vía pg_net pero Meta lo rechaza).
--   3. Mientras la cuenta siga en modo de prueba (hasta que termine la
--      Verificación de Negocio), Meta solo entrega a los 5 números
--      pre-aprobados — el envío a clientes reales fallará silenciosamente
--      (no hay error visible para el barbero/cliente) hasta que eso se
--      resuelva. Para probar el cron en el mientras tanto, usa un
--      customer_phone que sea uno de los 5 números de prueba aprobados.

alter table bookings add column if not exists reminder_sent_at timestamptz;

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
      and (bk.booking_date + bk.start_time) at time zone 'America/Santiago' - now()
          between interval '2 hours' and interval '3 hours'
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

select cron.schedule(
  'whatsapp-recordatorio-cliente',
  '*/15 * * * *',
  $$select send_whatsapp_reminders();$$
);

-- Para revisar que el job quedó registrado:
--   select * from cron.job where jobname = 'whatsapp-recordatorio-cliente';
-- Para desactivarlo si algo sale mal:
--   select cron.unschedule('whatsapp-recordatorio-cliente');
