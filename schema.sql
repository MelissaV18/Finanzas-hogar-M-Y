-- ============================================================
--  CASA — base de datos de finanzas compartidas
--  Pegar completo en Supabase > SQL Editor > Run
-- ============================================================

-- ---------- BOLSAS (categorías + presupuesto mensual) ----------
create table if not exists bolsas (
  nombre       text primary key,
  presupuesto  numeric not null default 0,
  orden        int     not null default 0
);

insert into bolsas (nombre, presupuesto, orden) values
  ('Mercado',     1000000, 1),
  ('Servicios',    200000, 2),
  ('Internet',     150000, 3),
  ('Deuda cama',   212000, 4),
  ('Imprevistos',       0, 5)
on conflict (nombre) do nothing;

-- ---------- CONFIG (valores sueltos) ----------
create table if not exists config (
  clave text primary key,
  valor numeric not null
);

insert into config (clave, valor) values
  ('aporte_quincenal_persona', 391000)
on conflict (clave) do nothing;

-- ---------- PERSONAS ----------
create table if not exists personas (
  nombre text primary key,
  orden  int not null default 0
);

insert into personas (nombre, orden) values
  ('Melissa', 1), ('Yobin', 2)
on conflict (nombre) do nothing;

-- ---------- APORTES ----------
create table if not exists aportes (
  id      bigint generated always as identity primary key,
  fecha   date    not null,
  persona text    not null references personas(nombre),
  monto   numeric not null check (monto > 0),
  notas   text,
  creado  timestamptz not null default now()
);

create index if not exists aportes_fecha_idx on aportes (fecha);

-- ---------- GASTOS (lo que YA se pagó) ----------
create table if not exists gastos (
  id      bigint generated always as identity primary key,
  fecha   date    not null,
  bolsa   text    not null references bolsas(nombre),
  detalle text,
  monto   numeric not null check (monto > 0),
  origen  text    not null default 'Fondo común',
  notas   text,
  creado  timestamptz not null default now()
);

create index if not exists gastos_fecha_idx on gastos (fecha);

-- ---------- PLAN (lo que falta por pagar) ----------
create table if not exists plan (
  id       bigint generated always as identity primary key,
  fecha    date    not null,
  detalle  text,
  bolsa    text    not null references bolsas(nombre),
  monto    numeric not null check (monto > 0),
  estado   text    not null default 'Pendiente'
             check (estado in ('Pendiente','Pagado')),
  gasto_id bigint  references gastos(id) on delete set null,
  notas    text,
  creado   timestamptz not null default now()
);

create index if not exists plan_fecha_idx  on plan (fecha);
create index if not exists plan_estado_idx on plan (estado);

-- ============================================================
--  SEGURIDAD
--  La clave "anon" de Supabase viaja dentro del HTML y es
--  pública. Lo que realmente protege los datos es esto:
--  RLS activo + solo usuarios autenticados pueden leer/escribir.
--  Sin estas líneas, cualquiera con la URL vería sus finanzas.
-- ============================================================

alter table bolsas   enable row level security;
alter table config   enable row level security;
alter table personas enable row level security;
alter table aportes  enable row level security;
alter table gastos   enable row level security;
alter table plan     enable row level security;

do $$
declare t text;
begin
  foreach t in array array['bolsas','config','personas','aportes','gastos','plan']
  loop
    execute format(
      'drop policy if exists solo_autenticados on %I', t);
    execute format(
      'create policy solo_autenticados on %I for all to authenticated
         using (true) with check (true)', t);
  end loop;
end $$;

-- ============================================================
--  DATOS INICIALES  (los de agosto/septiembre 2026)
--  Si prefiere arrancar en blanco, no corra este bloque.
-- ============================================================

insert into aportes (fecha, persona, monto, notas) values
  ('2026-08-31', 'Melissa', 303000, 'Primer aporte'),
  ('2026-08-31', 'Yobin',   303000, 'Primer aporte');

insert into plan (fecha, detalle, bolsa, monto, estado) values
  ('2026-08-31', 'Certificación de gas',       'Imprevistos', 180000, 'Pendiente'),
  ('2026-08-31', 'Compra cajón baño',          'Imprevistos', 300000, 'Pendiente'),
  ('2026-09-15', 'Mercado primera quincena',   'Mercado',     500000, 'Pendiente'),
  ('2026-09-15', 'Internet',                   'Internet',    150000, 'Pendiente'),
  ('2026-09-30', 'Mercado segunda quincena',   'Mercado',     500000, 'Pendiente'),
  ('2026-09-30', 'Servicios (agua, luz, gas)', 'Servicios',   200000, 'Pendiente'),
  ('2026-09-30', 'Cuota cama',                 'Deuda cama',  212000, 'Pendiente');
