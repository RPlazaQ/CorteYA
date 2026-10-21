-- Reemplaza el campo "especialidad" (texto libre) por una relación real
-- barbero <-> servicio: qué servicios sabe hacer cada barbero. El dashboard
-- pregunta esto al crear un servicio (qué barberos lo hacen) y al crear un
-- barbero (qué servicios sabe hacer), y la app de reserva usa esta tabla
-- para no ofrecer un barbero que no hace el servicio elegido.
--
-- Un servicio sin ninguna fila acá (p.ej. los que ya existían antes de esta
-- migración) se trata como "lo hacen todos los barberos" — así no se rompe
-- el agendamiento de barberías que todavía no han asignado nada.

create table if not exists barber_services (
  barber_id   uuid not null references barbers(id) on delete cascade,
  service_id  uuid not null references services(id) on delete cascade,
  primary key (barber_id, service_id)
);

alter table barber_services enable row level security;

-- lectura pública: la app de reserva (con la anon key) necesita leer esto
-- para filtrar qué barberos ofrecer por servicio
create policy "public read barber_services" on barber_services
  for select using (true);

create policy "owner manages own barber_services" on barber_services
  for all using (
    barber_id in (select b.id from barbers b join barbershops s on s.id = b.barbershop_id where s.owner_id = auth.uid())
  ) with check (
    barber_id in (select b.id from barbers b join barbershops s on s.id = b.barbershop_id where s.owner_id = auth.uid())
    and service_id in (select sv.id from services sv join barbershops s on s.id = sv.barbershop_id where s.owner_id = auth.uid())
  );
