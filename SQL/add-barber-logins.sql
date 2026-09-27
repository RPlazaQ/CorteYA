-- Login individual para barberos, separado del login único del dueño.
-- `barbers.user_id` vincula (opcionalmente) un barbero a una cuenta de
-- auth.users — se crea desde el panel del dueño (Barberos → Crear acceso)
-- usando un cliente de Supabase separado (auth.signUp), sin necesitar la
-- service_role key. Un barbero sin user_id sigue funcionando exactamente
-- igual que hoy (el dueño administra todo por él).

alter table barbers add column if not exists user_id uuid references auth.users(id) on delete set null;

-- un mismo usuario no puede estar vinculado a más de un barbero
create unique index if not exists barbers_user_id_key on barbers(user_id) where user_id is not null;

-- bookings: el barbero ve y actualiza (estado de la cita) solo las suyas.
-- Estas políticas se SUMAN a las del dueño (RLS OR-ea policies del mismo
-- comando), no las reemplazan — el dueño sigue viendo/editando todo.
create policy "barbero reads own bookings" on bookings
  for select using (barber_id in (select id from barbers where user_id = auth.uid()));

create policy "barbero updates own bookings" on bookings
  for update using (barber_id in (select id from barbers where user_id = auth.uid()))
  with check (barber_id in (select id from barbers where user_id = auth.uid()));

-- barber_working_hours: el barbero necesita leer su propio horario para que
-- el Calendario le arme la grilla del día (hoy solo el dueño podía leerlos).
create policy "barbero reads own working hours" on barber_working_hours
  for select using (barber_id in (select id from barbers where user_id = auth.uid()));
