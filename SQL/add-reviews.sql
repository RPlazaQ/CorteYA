-- Reseñas públicas de clientes sobre una barbería, sin importar si agendaron
-- por CorteYa o no. El promedio y el conteo alimentan directamente el ⭐ que
-- ya se muestra en la lista y el detalle de la barbería (columna `rating`
-- existente en `barbershops`), vía un trigger, para no tener que tocar las
-- queries de lectura que ya existen en la app.

alter table barbershops add column if not exists review_count int not null default 0;

create table reviews (
  id             uuid primary key default gen_random_uuid(),
  barbershop_id  uuid not null references barbershops(id) on delete cascade,
  customer_name  text not null check (char_length(customer_name) between 1 and 60),
  rating         smallint not null check (rating between 1 and 5),
  comment        text not null check (char_length(comment) between 1 and 400),
  created_at     timestamptz not null default now()
);

create or replace function update_barbershop_rating() returns trigger
language plpgsql as $$
declare
  v_barbershop_id uuid := coalesce(new.barbershop_id, old.barbershop_id);
begin
  update barbershops
  set rating = coalesce((select round(avg(rating)::numeric, 1) from reviews where barbershop_id = v_barbershop_id), 0),
      review_count = (select count(*) from reviews where barbershop_id = v_barbershop_id)
  where id = v_barbershop_id;
  return null;
end;
$$;

create trigger reviews_update_barbershop_rating
after insert or update or delete on reviews
for each row execute function update_barbershop_rating();

alter table reviews enable row level security;

-- lectura pública (para mostrarlas en el perfil de la barbería)
create policy "public read reviews" on reviews
  for select using (true);

-- cualquiera puede dejar una reseña, como invitado (igual que las reservas)
create policy "guest can create a review" on reviews
  for insert with check (true);

-- el dueño puede borrar reseñas de su propia barbería (moderación básica)
create policy "owner deletes own reviews" on reviews
  for delete using (barbershop_id in (select id from barbershops where owner_id = auth.uid()));
