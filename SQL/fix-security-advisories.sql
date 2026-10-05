-- Corrige 3 de los 4 avisos de seguridad del Security Advisor de Supabase.
-- El cuarto (Leaked Password Protection) se activa desde el dashboard,
-- no con SQL: Authentication -> Attack Protection -> Leaked password protection.

-- El dashboard del dueño no llama a get_available_slots (consulta las
-- tablas directo bajo sus propias políticas RLS). Solo los invitados
-- (anon) la necesitan para ver horarios disponibles antes de agendar,
-- así que le sacamos el permiso a authenticated por mínimo privilegio.
revoke execute on function public.get_available_slots(uuid, date, int, int) from authenticated;

-- Mueve btree_gist fuera de public a un schema dedicado (recomendación
-- estándar de Supabase para evitar colisiones de nombres en public).
create schema if not exists extensions;
alter extension btree_gist set schema extensions;
