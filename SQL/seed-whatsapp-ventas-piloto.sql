-- Lote piloto: 12 barberías de origen Instagram, estado "Por llamar" en
-- CorteYa_Seguimiento_Barberias.xlsx (hoja Barberías, filas 6+).
--
-- Paso 1 (correr ahora, no depende de la plantilla): registra los leads.
-- Paso 2 (NO correr hasta que "primer_contacto_barberia" esté APPROVED en
-- Meta -- hoy quedó en PENDING, id 2632091617304382): encola el primer
-- contacto de cada uno en whatsapp_outbox: el trigger los manda apenas se
-- insertan, así que insertar TODOS de una sentencia asegura tener el tope
-- de "envío por tandas" respetado (12, no 252).

insert into whatsapp_leads (barberia, comuna, telefono, origen) values
  ('#Barberestudio__💈', 'La Granja', '+56 9 4251 3705', 'Instagram'),
  ('1312 BarberShop', 'Macul', '+56 9 5777 6367', 'Instagram'),
  ('BARBERIA DIOCARES', 'Conchalí', '+56 9 5099 7646', 'Instagram'),
  ('Barberia Entre Barbas', 'Macul', '+56 9 7293 2925', 'Instagram'),
  ('BARBERIA MEN''S SALON', 'Lo Prado', '+56 9 8410 3861', 'Instagram'),
  ('Barberia Neo', 'Santiago', '+56 9 9047 0112', 'Instagram'),
  ('Barberia Samir💈', 'San Ramón', '+56 9 5107 1820', 'Instagram'),
  ('BARBERIA THIAGO BARBER', 'Valle Grande, Lampa', '+56 9 3501 1486', 'Instagram'),
  ('BarberStudioLML', 'Pudahuel', '+56 9 9687 9115', 'Instagram'),
  ('BARBERÍA Barbero Esteban', 'Buin', '+56 9 7854 0485', 'Instagram'),
  ('Barbería Alian', 'Curacavi, Curacaví', '+56 9 2727 8068', 'Instagram'),
  ('Barbería Carlos magaña', 'La Reina', '+56 9 6323 7441', 'Instagram')
on conflict (telefono) do nothing;

-- PASO 2 -- correr solo cuando la plantilla esté APPROVED:
--
-- insert into whatsapp_outbox (telefono, kind, template_name, template_params)
-- select telefono, 'template', 'primer_contacto_barberia', array[barberia]
-- from whatsapp_leads
-- where origen = 'Instagram' and estado = 'Por llamar'
-- and telefono in (
--   '+56 9 4251 3705', '+56 9 5777 6367', '+56 9 5099 7646', '+56 9 7293 2925',
--   '+56 9 8410 3861', '+56 9 9047 0112', '+56 9 5107 1820', '+56 9 3501 1486',
--   '+56 9 9687 9115', '+56 9 7854 0485', '+56 9 2727 8068', '+56 9 6323 7441'
-- );
