-- Rating individual por barbero, calculado desde la misma tabla `reviews`
-- que ya alimenta el rating de la barbería (ver add-reviews.sql). Se agrega
-- un `barber_id` opcional a la reseña ("¿Quién te atendió?") y un trigger
-- gemelo al de `update_barbershop_rating()` que mantiene `rating` y
-- `review_count` en `barbers` al día.

alter table reviews add column if not exists barber_id uuid references barbers(id) on delete set null;

alter table barbers add column if not exists rating numeric(2,1) not null default 0;
alter table barbers add column if not exists review_count int not null default 0;

create or replace function update_barber_rating() returns trigger
language plpgsql as $$
declare
  v_barber_id uuid := coalesce(new.barber_id, old.barber_id);
begin
  if v_barber_id is null then
    return null;
  end if;

  update barbers
  set rating = coalesce((select round(avg(rating)::numeric, 1) from reviews where barber_id = v_barber_id), 0),
      review_count = (select count(*) from reviews where barber_id = v_barber_id)
  where id = v_barber_id;

  return null;
end;
$$;

create trigger reviews_update_barber_rating
after insert or update or delete on reviews
for each row execute function update_barber_rating();
