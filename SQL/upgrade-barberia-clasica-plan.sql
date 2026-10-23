-- Pasa a Barbería Clásica del plan 'piloto' a un plan de pago, sin cobrar
-- nada — es la cuenta de pruebas para testear las funciones de los planes
-- pagados (acceso individual de barbero, y más adelante foto/descripción).
--
-- El dueño no puede cambiarse el plan a sí mismo desde el dashboard
-- (trg_prevent_plan_self_change), así que esto se corre acá, como
-- service_role, en el SQL Editor de Supabase.

-- 1) confirma que es la fila correcta antes de actualizar
select id, name, slug, plan from barbershops where name ilike '%clásica%' or name ilike '%clasica%';

-- 2) une vez verificado el id de arriba, corre el update (ajusta el plan
--    si prefieres 'barbero_independiente' o 'multisucursal' en vez de
--    'local_independiente' — elegí esta porque tiene varios barberos en
--    un solo local, no varias sucursales ni un barbero solo)
update barbershops set plan = 'local_independiente' where name ilike '%clásica%' or name ilike '%clasica%';
