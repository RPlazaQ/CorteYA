-- Storage para logos de barberías: bucket público (se muestran en la app
-- del cliente), pero solo el dueño de la barbería puede subir/reemplazar
-- el logo de la suya. Convención de ruta: {barbershop_id}/logo.<ext>

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('barbershop-logos', 'barbershop-logos', true, 2097152, array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

create policy "public read barbershop logos" on storage.objects
  for select using (bucket_id = 'barbershop-logos');

create policy "owner uploads own logo" on storage.objects
  for insert with check (
    bucket_id = 'barbershop-logos'
    and (storage.foldername(name))[1] in (select id::text from barbershops where owner_id = auth.uid())
  );

create policy "owner replaces own logo" on storage.objects
  for update using (
    bucket_id = 'barbershop-logos'
    and (storage.foldername(name))[1] in (select id::text from barbershops where owner_id = auth.uid())
  ) with check (
    bucket_id = 'barbershop-logos'
    and (storage.foldername(name))[1] in (select id::text from barbershops where owner_id = auth.uid())
  );

create policy "owner deletes own logo" on storage.objects
  for delete using (
    bucket_id = 'barbershop-logos'
    and (storage.foldername(name))[1] in (select id::text from barbershops where owner_id = auth.uid())
  );
