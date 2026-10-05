-- Atiende 2 de las 4 alertas del Security Advisor de Supabase (2026-09-14):
--
-- - "Public Bucket Allows Listing": el bucket barbershop-logos ya es
--   público a nivel de bucket (storage.buckets.public = true), así que
--   las imágenes se siguen sirviendo igual por su URL pública sin esta
--   política. La política de SELECT solo agregaba la posibilidad extra
--   de LISTAR todos los archivos del bucket vía la API — eso es lo que
--   se saca.
-- - "Function Search Path Mutable": a update_barbershop_rating se le
--   había quedado sin fijar el search_path, a diferencia de las demás
--   funciones del schema.
--
-- Las otras 2 alertas del Advisor no van acá:
-- - "Leaked Password Protection Disabled" se activa en el dashboard
--   (Authentication → Policies), no es un cambio de SQL.
-- - "Public Can Execute get_available_slots" es intencional (la llama la
--   app del cliente sin login para calcular horas disponibles) — no hay
--   nada que corregir.

drop policy if exists "public read barbershop logos" on storage.objects;

alter function update_barbershop_rating() set search_path = public;
