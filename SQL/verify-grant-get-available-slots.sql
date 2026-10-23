-- El proyecto es el correcto y corriste el GRANT dos veces con éxito, pero
-- la página sigue con "permission denied". Esto revisa el estado REAL del
-- permiso directo en el catálogo de Postgres, y si hay más de una versión
-- de la función (lo que haría que el GRANT le pegara a la que no es).

-- 1) ¿cuántas versiones de get_available_slots existen, y qué permisos
--    (proacl) tiene cada una? Si aparece más de una fila, ahí está el
--    problema: el GRANT puede estar aplicado a la que no usa la app.
select p.oid, pg_get_function_identity_arguments(p.oid) as argumentos, p.proacl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname = 'get_available_slots' and n.nspname = 'public';

-- 2) lo mismo pero más legible: quién tiene permiso de ejecutar
select grantee, privilege_type
from information_schema.routine_privileges
where routine_name = 'get_available_slots';

-- 3) por si acaso: forzar a que PostgREST (la capa que expone la base de
--    datos como API) recargue su caché de esquema/permisos. Esto es
--    inofensivo y a veces hace falta después de cambiar un grant.
notify pgrst, 'reload schema';
