-- Quadro de tarefas do RH: tabelas e regras de acesso.
-- Rode este arquivo inteiro no SQL Editor do Supabase (uma vez só).

create table if not exists public.perfis (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  email     text not null,
  nome      text,
  is_admin  boolean not null default false,
  empresas  text[] not null default '{}',
  criado_em timestamptz not null default now()
);

create table if not exists public.tarefas (
  id               text primary key,
  empresa          text not null check (empresa in ('usee','rei','kings')),
  dados            jsonb not null,
  updated_at       timestamptz not null default now(),
  updated_by       uuid references auth.users(id) on delete set null,
  updated_by_email text
);

create table if not exists public.prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pinned  jsonb not null default '{}'
);

alter table public.perfis  enable row level security;
alter table public.tarefas enable row level security;
alter table public.prefs   enable row level security;

-- Visitantes sem login não acessam nada
revoke all on public.perfis, public.tarefas, public.prefs from anon;

create or replace function public.eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from perfis where user_id = auth.uid()), false)
$$;

create or replace function public.minhas_empresas() returns text[]
language sql stable security definer set search_path = public as $$
  select coalesce((select empresas from perfis where user_id = auth.uid()), '{}')
$$;

-- Perfis: cada um lê o próprio; o administrador lê todos. Ninguém altera pelo site
-- (a criação e a edição de acessos passam pela função do Vercel).
drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to authenticated
  using (user_id = auth.uid() or public.eh_admin());

-- Tarefas: só das empresas liberadas para a pessoa (o administrador vê todas)
drop policy if exists tarefas_ler on public.tarefas;
drop policy if exists tarefas_inserir on public.tarefas;
drop policy if exists tarefas_alterar on public.tarefas;
drop policy if exists tarefas_excluir on public.tarefas;
create policy tarefas_ler on public.tarefas for select to authenticated
  using (public.eh_admin() or empresa = any(public.minhas_empresas()));
create policy tarefas_inserir on public.tarefas for insert to authenticated
  with check (public.eh_admin() or empresa = any(public.minhas_empresas()));
create policy tarefas_alterar on public.tarefas for update to authenticated
  using (public.eh_admin() or empresa = any(public.minhas_empresas()))
  with check (public.eh_admin() or empresa = any(public.minhas_empresas()));
create policy tarefas_excluir on public.tarefas for delete to authenticated
  using (public.eh_admin() or empresa = any(public.minhas_empresas()));

-- Preferências (tarefas fixadas): cada um só as suas
drop policy if exists prefs_proprio on public.prefs;
create policy prefs_proprio on public.prefs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Registra quem fez a última alteração (não dá para falsificar pelo site)
create or replace function public.marcar_autor() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_by := auth.uid();
  new.updated_by_email := (select email from perfis where user_id = auth.uid());
  return new;
end $$;
drop trigger if exists tarefas_autor on public.tarefas;
create trigger tarefas_autor before insert or update on public.tarefas
  for each row execute function public.marcar_autor();

-- Atualização em tempo real para quem está com o quadro aberto
do $$ begin
  alter publication supabase_realtime add table public.tarefas;
exception when duplicate_object then null; end $$;
