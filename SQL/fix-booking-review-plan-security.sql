-- Corrige 3 huecos encontrados en la revisión de seguridad del 2026-10-05:
--
-- 1. (Alto) Nada validaba que barber_id/service_id de una reserva realmente
--    pertenecieran a barbershop_id, ni que end_time calzara con la duración
--    real del servicio. Cualquiera con la key pública podía insertar una
--    reserva con end_time inventado (ej. 23:59) y bloquear la agenda de un
--    barbero todo el día, incluso plantándola bajo el barbershop_id de OTRA
--    barbería (invisible en el dashboard del dueño real afectado).
--
-- 2. (Medio) Las reseñas de invitado (sin login, intencional — ver comentario
--    original en reviews) no tenían ningún límite de velocidad, permitiendo
--    bombardear el rating de cualquier barbería en segundos.
--
-- 3. (Medio) Un dueño podía auto-subirse el plan de su propia barbería con
--    una sola llamada UPDATE, porque el límite de planes solo se revisaba en
--    el JS del dashboard, no en la base de datos.

-- 1. Consistencia de reservas: barbero y servicio deben pertenecer a la
--    barbería indicada, y la duración debe calzar con la del servicio.
create or replace function validate_booking_consistency()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  svc_duration int;
begin
  select duration_minutes into svc_duration
  from services
  where id = new.service_id and barbershop_id = new.barbershop_id;

  if svc_duration is null then
    raise exception 'El servicio no pertenece a esta barbería';
  end if;

  if not exists (
    select 1 from barbers
    where id = new.barber_id and barbershop_id = new.barbershop_id
  ) then
    raise exception 'El barbero no pertenece a esta barbería';
  end if;

  if new.end_time <> new.start_time + (svc_duration || ' minutes')::interval then
    raise exception 'La duración de la reserva no coincide con el servicio';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_booking_consistency on bookings;
create trigger trg_validate_booking_consistency
  before insert on bookings
  for each row execute function validate_booking_consistency();

-- 2. Límite de reseñas por barbería: máximo 5 cada 10 minutos. Suficiente
--    para uso real (ningún local de un piloto recibe más que eso de golpe),
--    pero corta un bombardeo automatizado. No requiere login porque las
--    reseñas de invitado sin reserva previa siguen siendo intencionales.
create or replace function limit_review_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count int;
begin
  select count(*) into recent_count
  from reviews
  where barbershop_id = new.barbershop_id
    and created_at > now() - interval '10 minutes';

  if recent_count >= 5 then
    raise exception 'Se alcanzó el límite de reseñas por el momento, intenta en unos minutos';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_limit_review_rate on reviews;
create trigger trg_limit_review_rate
  before insert on reviews
  for each row execute function limit_review_rate();

-- 3. El plan de una barbería solo lo puede cambiar el service_role (tú,
--    desde el panel de Supabase), nunca el propio dueño vía RLS normal.
create or replace function prevent_plan_self_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.plan is distinct from old.plan and auth.role() <> 'service_role' then
    raise exception 'El plan de la barbería no se puede cambiar desde aquí';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_plan_self_change on barbershops;
create trigger trg_prevent_plan_self_change
  before update on barbershops
  for each row execute function prevent_plan_self_change();
