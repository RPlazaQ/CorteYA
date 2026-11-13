-- Asistente de ventas por WhatsApp (ver prompt-whatsapp-ventas.md).
--
-- Mirror de la hoja "Barberías" de CorteYa_Seguimiento_Barberias.xlsx:
-- Supabase es la fuente de verdad en tiempo real, la planilla se
-- actualiza desde acá con un comando aparte (todavía no construido).
--
-- Mismo patrón ya probado para WhatsApp (ver fix-whatsapp-direct-meta.sql):
-- todo envío saliente a Meta corre DIRECTO desde Postgres vía pg_net,
-- nunca desde una función de Netlify (ahí es donde Meta bloquea el
-- tráfico). Este archivo reutiliza los secretos que ya existen en
-- app_secrets (whatsapp_token, whatsapp_phone_number_id) — no hace
-- falta agregar nada nuevo ahí.

create table if not exists whatsapp_leads (
  id uuid primary key default gen_random_uuid(),
  barberia text not null,
  comuna text,
  telefono text not null unique check (telefono ~ '^\+56 9 \d{4} \d{4}$'),
  contacto_nombre text,
  hablo_con_dueno boolean,
  n_barberos text check (n_barberos in ('Solo yo', '2-3', '4-6', '7 o más')),
  origen text check (origen in ('Lista de llamadas', 'Instagram', 'Landing', 'Referido', 'Visita en persona', 'Otro', 'Llamada fría')),
  estado text not null default 'Por llamar' check (estado in (
    'Por llamar', 'No contesta', 'Volver a llamar', 'Pidió info',
    'Prueba agendada', 'Prueba activa', 'Cliente', 'Perdido', 'No interesa'
  )),
  fecha_1er_contacto date,
  ultimo_contacto date,
  n_intentos int not null default 0,
  dolor_principal text check (dolor_principal in ('WhatsApp todo el día', 'No-shows', 'Dobles reservas', 'Confirmar a mano', 'Cuaderno / desorden', 'Caja / no sabe cuánto gana', 'Otro')),
  objecion_principal text check (objecion_principal in ('Ninguna', 'No tengo tiempo', 'WhatsApp está bien', 'Ya usa otra agenda', 'Precio', 'Clientes mayores', 'Mándame info', 'Soy solo yo', 'No me interesa', 'Otra')),
  agenda_actual text check (agenda_actual in ('WhatsApp', 'Cuaderno', 'Otra app', 'Nada / por orden de llegada', 'Otro')),
  proximo_paso text,
  fecha_proximo_paso date,
  notas text,
  created_at timestamptz not null default now()
);
revoke all on whatsapp_leads from anon, authenticated;

create table if not exists whatsapp_mensajes (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references whatsapp_leads(id) on delete cascade,
  direction text not null check (direction in ('in', 'out')),
  body text not null,
  meta_message_id text,
  created_at timestamptz not null default now()
);
revoke all on whatsapp_mensajes from anon, authenticated;

create table if not exists whatsapp_llamadas_agendadas (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references whatsapp_leads(id) on delete cascade,
  fecha_hora timestamptz not null,
  motivo text,
  resumen text,
  avisado_at timestamptz,
  created_at timestamptz not null default now()
);
revoke all on whatsapp_llamadas_agendadas from anon, authenticated;

-- cola de salida: el "cerebro" (función de Netlify que llama a Claude) solo
-- escribe filas acá. El trigger de abajo hace el envío real a Meta.
create table if not exists whatsapp_outbox (
  id uuid primary key default gen_random_uuid(),
  telefono text not null,
  kind text not null check (kind in ('template', 'freeform')),
  template_name text,
  template_params text[],
  body text,
  status text not null default 'pending' check (status in ('pending', 'sent', 'error')),
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
revoke all on whatsapp_outbox from anon, authenticated;

create or replace function send_whatsapp_outbox() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_token text;
  v_phone_number_id text;
  v_to_digits text;
  v_components jsonb;
  v_body jsonb;
begin
  select value into v_token from app_secrets where key = 'whatsapp_token';
  select value into v_phone_number_id from app_secrets where key = 'whatsapp_phone_number_id';

  if v_token is null or v_phone_number_id is null then
    update whatsapp_outbox set status = 'error', error = 'faltan credenciales en app_secrets' where id = new.id;
    return new;
  end if;

  v_to_digits := regexp_replace(new.telefono, '[^0-9]', '', 'g');

  if new.kind = 'template' then
    select jsonb_agg(jsonb_build_object('type', 'text', 'text', p))
    into v_components
    from unnest(coalesce(new.template_params, array[]::text[])) p;

    v_body := jsonb_build_object(
      'messaging_product', 'whatsapp',
      'to', v_to_digits,
      'type', 'template',
      'template', jsonb_build_object(
        'name', new.template_name,
        'language', jsonb_build_object('code', 'es'),
        'components', jsonb_build_array(jsonb_build_object('type', 'body', 'parameters', coalesce(v_components, '[]'::jsonb)))
      )
    );
  else
    v_body := jsonb_build_object(
      'messaging_product', 'whatsapp',
      'to', v_to_digits,
      'type', 'text',
      'text', jsonb_build_object('body', new.body)
    );
  end if;

  perform net.http_post(
    url := 'https://graph.facebook.com/v26.0/' || v_phone_number_id || '/messages',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_token),
    body := v_body
  );

  update whatsapp_outbox set status = 'sent', sent_at = now() where id = new.id;
  return new;
end;
$$;

drop trigger if exists trg_send_whatsapp_outbox on whatsapp_outbox;
create trigger trg_send_whatsapp_outbox
  after insert on whatsapp_outbox
  for each row execute function send_whatsapp_outbox();
