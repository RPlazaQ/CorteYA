-- "permission denied for function get_available_slots" (código 42501) en
-- la consola del navegador — el rol anon (la app pública) perdió el
-- permiso para ejecutar esta función. Por eso en el SQL Editor (donde se
-- corre como administrador) sí devolvía horarios, pero la página en vivo
-- no: la llamada ni siquiera llegaba a calcular nada, la rechazaba antes.
--
-- supabase-schema.sql ya tenía este grant, pero get_available_slots se
-- volvió a crear después (no-horas-pasadas.sql) y en algún punto quedó
-- sin el permiso otra vez. Esto lo repone.

grant execute on function get_available_slots to anon;
