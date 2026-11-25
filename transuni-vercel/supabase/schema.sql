-- TransUni UCATECI: autenticación, perfiles, estado compartido y políticas RLS.
-- Ejecuta TODO este archivo en Supabase > SQL Editor > New query.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  matricula text not null,
  universidad text not null default 'UCATECI',
  telefono text not null default '',
  rol text not null default 'estudiante' check (rol in ('estudiante','chofer','admin')),
  activo boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_matricula_lower_uidx on public.profiles (lower(matricula));

alter table public.profiles enable row level security;
drop policy if exists "profiles_read_authenticated" on public.profiles;
create policy "profiles_read_authenticated" on public.profiles
  for select to authenticated using (true);
-- Los usuarios no pueden cambiar su propio rol. El alta de perfil la hace el trigger.
drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin" on public.profiles
  for update to authenticated
  using (exists (select 1 from public.profiles me where me.id = auth.uid() and me.rol = 'admin'))
  with check (exists (select 1 from public.profiles me where me.id = auth.uid() and me.rol = 'admin'));

create or replace function public.transuni_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nombre text;
  v_matricula text;
begin
  v_nombre := coalesce(new.raw_user_meta_data->>'nombre', 'Estudiante');
  v_matricula := trim(coalesce(new.raw_user_meta_data->>'matricula', split_part(new.email, '@', 1)));
  insert into public.profiles (id, nombre, matricula, universidad, telefono, rol, activo)
  values (new.id, v_nombre, v_matricula, coalesce(new.raw_user_meta_data->>'universidad','UCATECI'), coalesce(new.raw_user_meta_data->>'telefono',''), 'estudiante', true);
  return new;
end;
$$;

drop trigger if exists transuni_auth_user_created on auth.users;
create trigger transuni_auth_user_created
  after insert on auth.users
  for each row execute procedure public.transuni_handle_new_user();

create table if not exists public.transuni_app_state (
  id integer primary key check (id = 1),
  payload jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.transuni_app_state enable row level security;
drop policy if exists "transuni_state_read_authenticated" on public.transuni_app_state;
create policy "transuni_state_read_authenticated" on public.transuni_app_state
  for select to authenticated using (true);
drop policy if exists "transuni_state_update_authenticated" on public.transuni_app_state;
create policy "transuni_state_update_authenticated" on public.transuni_app_state
  for update to authenticated using (true) with check (true);

-- La fila inicial contiene horarios limpios, sin reservas ni votos de prueba.
insert into public.transuni_app_state (id, payload)
values (1, $json$
{
  "config": {"nombreComunidad":"TransUni UCATECI","subtitulo":"Ruta Bonao → Campus UCATECI (La Vega)","origen":"Bonao (Monseñor Nouel)","destino":"Campus UCATECI (La Vega)","capacidadTope":100,"horaEnvioEncuesta":"10:00 PM","encuestaActivaDemo":true,"dayOffset":0,"permitirListaEspera":false},
  "puntosEspera": [
    {"id":"stop-1","etiqueta":"Semáforo de las Delicias","corto":"Semáforo de las Delicias","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-2","etiqueta":"Parquesito","corto":"Parquesito","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-3","etiqueta":"J Peinado","corto":"J Peinado","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-4","etiqueta":"Helados Bon","corto":"Helados Bon","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-5","etiqueta":"Esquina del Sándwich","corto":"Esquina del Sándwich","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-6","etiqueta":"Gobernación, Correo","corto":"Gobernación / Correo","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-7","etiqueta":"Hospital Viejo","corto":"Hospital Viejo","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-8","etiqueta":"Duarte, Helados Bon el 90","corto":"Duarte (Helados Bon el 90)","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-9","etiqueta":"Monumento, Aniana Vargas","corto":"Monumento / Aniana Vargas","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-10","etiqueta":"Avenida Libertad","corto":"Av. Libertad","desc":"Punto de abordaje en Bonao"},
    {"id":"stop-11","etiqueta":"Típico, salida ya hacia La Vega","corto":"Típico (salida hacia La Vega)","desc":"Última parada antes de salir hacia La Vega"}
  ],
  "usuarios": [],
  "choferes": [
    {"id":"driver-1","nombre":"Dilone","telefono":"809-555-0201","nota":"Ruta Bonao → UCATECI"},
    {"id":"driver-2","nombre":"Jorge","telefono":"809-555-0202","nota":"Ruta Bonao → UCATECI"}
  ],
  "horarios": [
    {"id":"bon-1","horaSalida":"06:00 AM","horaClases":"07:00 AM","chofer":"Dilone","tanda":"manana","capacidad":100,"activo":true},
    {"id":"bon-2","horaSalida":"06:50 AM","horaClases":"08:00 AM","chofer":"Jorge","tanda":"manana","capacidad":100,"activo":true},
    {"id":"bon-3","horaSalida":"07:50 AM","horaClases":"09:00 AM","chofer":"Dilone","tanda":"manana","capacidad":100,"activo":true},
    {"id":"bon-4","horaSalida":"08:50 AM","horaClases":"10:00 AM","chofer":"Jorge","tanda":"manana","capacidad":100,"activo":true},
    {"id":"bon-5","horaSalida":"10:50 AM","horaClases":"12:00 PM","chofer":"Dilone","tanda":"manana","capacidad":100,"activo":true},
    {"id":"bon-6","horaSalida":"12:50 PM","horaClases":"02:00 PM","chofer":"Jorge","tanda":"tarde","capacidad":100,"activo":true},
    {"id":"bon-7","horaSalida":"02:50 PM","horaClases":"04:00 PM","chofer":"Dilone","tanda":"tarde","capacidad":100,"activo":true},
    {"id":"bon-8","horaSalida":"03:50 PM","horaClases":"05:00 PM","chofer":"Jorge","tanda":"tarde","capacidad":100,"activo":true},
    {"id":"bon-9","horaSalida":"04:50 PM","horaClases":"06:00 PM","chofer":"Dilone","tanda":"tarde","capacidad":100,"activo":true},
    {"id":"bon-10","horaSalida":"05:55 PM","horaClases":"07:00 PM","chofer":"Jorge","tanda":"tarde","capacidad":100,"activo":true},
    {"id":"bon-11","horaSalida":"06:55 PM","horaClases":"08:00 PM","chofer":"Dilone","tanda":"tarde","capacidad":100,"activo":true}
  ],
  "reservas": [],
  "avisos": [
    {"id":"av-1","titulo":"Encuesta diaria automática a las 10:00 PM","contenido":"Todos los días a las 10:00 PM se abre esta encuesta para confirmar los pasajeros de mañana desde Bonao hacia UCATECI (tope 100 por horario).","fecha":"Hoy • 10:00 PM"},
    {"id":"av-2","titulo":"Orden de abordaje y reporte para choferes Dilone y Jorge","contenido":"El primer estudiante en votar queda al final de la lista (#1 abajo). Los choferes consultan el total exacto antes de salir.","fecha":"Información Oficial"}
  ],
  "retorno": {"fecha":"2026-11-25","votos":[],"forzar":{}}
}
$json$::jsonb)
on conflict (id) do nothing;

-- Protege la fila compartida: estudiantes solo pueden modificar sus propios votos/reservas.
-- Administradores y choferes pueden editar horarios, choferes y configuración.
create or replace function public.transuni_guard_app_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  old_other_reservas jsonb;
  new_other_reservas jsonb;
  old_other_votes jsonb;
  new_other_votes jsonb;
begin
  select rol into v_role from public.profiles where id = auth.uid() and activo = true;
  if v_role = 'admin' then return new; end if;
  if v_role = 'chofer' then
    if (old.payload - 'horarios' - 'choferes') <> (new.payload - 'horarios' - 'choferes') then
      raise exception 'Los choferes solo pueden actualizar horarios y datos de choferes.';
    end if;
    return new;
  end if;
  if v_role is distinct from 'estudiante' then
    raise exception 'No tienes permiso para modificar TransUni.';
  end if;

  if (old.payload - 'reservas' - 'retorno' - 'config') <> (new.payload - 'reservas' - 'retorno' - 'config') then
    raise exception 'Los estudiantes solo pueden registrar o quitar sus propios votos.';
  end if;

  if (coalesce(old.payload->'config','{}'::jsonb) - 'dayOffset') <> (coalesce(new.payload->'config','{}'::jsonb) - 'dayOffset') then
    raise exception 'No puedes modificar la configuración del sistema.';
  end if;
  if coalesce(new.payload->'config'->>'dayOffset','0') not in (coalesce(old.payload->'config'->>'dayOffset','0'), '0') then
    raise exception 'El ajuste de fecha no es válido.';
  end if;
  if (coalesce(old.payload->'retorno','{}'::jsonb) - 'votos' - 'fecha') <> (coalesce(new.payload->'retorno','{}'::jsonb) - 'votos' - 'fecha') then
    raise exception 'No puedes modificar la configuración de las encuestas.';
  end if;
  if coalesce(new.payload->'retorno'->>'fecha','') <> to_char((now() at time zone 'America/Santo_Domingo')::date, 'YYYY-MM-DD') then
    raise exception 'La fecha de la encuesta no es válida.';
  end if;

  select coalesce(jsonb_agg(x - 'orderNum' order by x->>'id'),'[]'::jsonb) into old_other_reservas
    from jsonb_array_elements(coalesce(old.payload->'reservas','[]'::jsonb)) x
    where x->>'usuarioId' <> auth.uid()::text;
  select coalesce(jsonb_agg(x - 'orderNum' order by x->>'id'),'[]'::jsonb) into new_other_reservas
    from jsonb_array_elements(coalesce(new.payload->'reservas','[]'::jsonb)) x
    where x->>'usuarioId' <> auth.uid()::text;
  if old_other_reservas <> new_other_reservas then
    raise exception 'No puedes cambiar las reservas de otros estudiantes.';
  end if;

  select coalesce(jsonb_agg(x order by x->>'pollId', x->>'usuarioId'),'[]'::jsonb) into old_other_votes
    from jsonb_array_elements(coalesce(old.payload->'retorno'->'votos','[]'::jsonb)) x
    where x->>'usuarioId' <> auth.uid()::text;
  select coalesce(jsonb_agg(x order by x->>'pollId', x->>'usuarioId'),'[]'::jsonb) into new_other_votes
    from jsonb_array_elements(coalesce(new.payload->'retorno'->'votos','[]'::jsonb)) x
    where x->>'usuarioId' <> auth.uid()::text;
  if old_other_votes <> new_other_votes then
    raise exception 'No puedes cambiar los votos de retorno de otros estudiantes.';
  end if;

  return new;
end;
$$;

drop trigger if exists transuni_guard_state_update on public.transuni_app_state;
create trigger transuni_guard_state_update
  before update on public.transuni_app_state
  for each row execute procedure public.transuni_guard_app_state();

-- Habilita las notificaciones realtime de cambios compartidos y perfiles.
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='transuni_app_state') then
    alter publication supabase_realtime add table public.transuni_app_state;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='profiles') then
    alter publication supabase_realtime add table public.profiles;
  end if;
end $$;

-- Después de que cada persona cree su cuenta, promociona únicamente a quienes corresponda:
-- update public.profiles set rol='admin' where lower(matricula)=lower('MATRICULA_ADMIN');
-- update public.profiles set rol='chofer' where lower(matricula)=lower('MATRICULA_CHOFER');
