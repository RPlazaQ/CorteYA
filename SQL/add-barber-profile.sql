-- Foto de perfil y descripción de cada barbero, administradas por el
-- propio barbero desde su acceso (no por el dueño) — feature de los
-- planes de pago (ver PLANES_CON_LOGIN_BARBERO en dashboard-barberia.html).

alter table barbers add column if not exists bio text check (bio is null or char_length(bio) <= 300);

-- el barbero no tiene permiso de UPDATE directo sobre barbers (solo el
-- dueño, vía "owner manages own barbers"), así que esta función security
-- definer le deja tocar SOLO su foto y descripción, nunca active/rating/etc.
create or replace function update_barber_profile(p_photo_url text, p_bio text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update barbers
  set photo_url = p_photo_url,
      bio = p_bio
  where user_id = auth.uid();
end;
$$;

revoke all on function update_barber_profile from public;
grant execute on function update_barber_profile to authenticated;

-- storage para las fotos: bucket público (se muestran en la app del
-- cliente), el barbero solo puede subir/reemplazar la suya propia.
-- Convención de ruta: {barber_id}/photo.<ext>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('barber-photos', 'barber-photos', true, 2097152, array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

create policy "public read barber photos" on storage.objects
  for select using (bucket_id = 'barber-photos');

create policy "barbero uploads own photo" on storage.objects
  for insert with check (
    bucket_id = 'barber-photos'
    and (storage.foldername(name))[1] in (select id::text from barbers where user_id = auth.uid())
  );

create policy "barbero replaces own photo" on storage.objects
  for update using (
    bucket_id = 'barber-photos'
    and (storage.foldername(name))[1] in (select id::text from barbers where user_id = auth.uid())
  ) with check (
    bucket_id = 'barber-photos'
    and (storage.foldername(name))[1] in (select id::text from barbers where user_id = auth.uid())
  );
