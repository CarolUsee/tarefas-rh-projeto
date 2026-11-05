-- Responsáveis por tarefa.
-- O administrador vê e gerencia todas as tarefas e escolhe os responsáveis de cada uma.
-- Os demais usuários só veem as tarefas em que são responsáveis (e da empresa liberada para eles).
-- Quem acabou de receber acesso começa sem nenhuma tarefa.
-- Rode este arquivo uma vez no SQL Editor do Supabase.

alter table public.tarefas add column if not exists responsaveis uuid[] not null default '{}';
create index if not exists tarefas_responsaveis_idx on public.tarefas using gin (responsaveis);

-- A coluna é sempre preenchida a partir de dados.resp (lista de ids), e só o administrador muda os responsáveis.
create or replace function public.controlar_responsaveis() returns trigger
language plpgsql security definer set search_path = public as $$
declare novos uuid[];
begin
  select coalesce(array_agg(x::uuid), '{}') into novos
    from jsonb_array_elements_text(coalesce(new.dados->'resp', '[]'::jsonb)) as x;
  new.responsaveis := novos;
  if public.eh_admin() then return new; end if;

  if tg_op = 'INSERT' then
    -- tarefa nova criada por quem não é administrador: a própria pessoa fica responsável
    if not exists (select 1 from tarefas where id = new.id) then
      new.responsaveis := array[auth.uid()];
      new.dados := jsonb_set(new.dados, '{resp}', to_jsonb(array[auth.uid()::text]));
    end if;
  elsif new.responsaveis is distinct from old.responsaveis then
    raise exception 'Só o administrador pode mudar os responsáveis.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists tarefas_responsaveis on public.tarefas;
create trigger tarefas_responsaveis before insert or update on public.tarefas
  for each row execute function public.controlar_responsaveis();

-- Regras de acesso às tarefas
drop policy if exists tarefas_ler on public.tarefas;
drop policy if exists tarefas_inserir on public.tarefas;
drop policy if exists tarefas_alterar on public.tarefas;
drop policy if exists tarefas_excluir on public.tarefas;
create policy tarefas_ler on public.tarefas for select to authenticated
  using (public.eh_admin() or (empresa = any(public.minhas_empresas()) and auth.uid() = any(responsaveis)));
create policy tarefas_inserir on public.tarefas for insert to authenticated
  with check (public.eh_admin() or (empresa = any(public.minhas_empresas()) and auth.uid() = any(responsaveis)));
create policy tarefas_alterar on public.tarefas for update to authenticated
  using (public.eh_admin() or (empresa = any(public.minhas_empresas()) and auth.uid() = any(responsaveis)))
  with check (public.eh_admin() or (empresa = any(public.minhas_empresas()) and auth.uid() = any(responsaveis)));
-- Excluir tarefa: só o administrador
create policy tarefas_excluir on public.tarefas for delete to authenticated
  using (public.eh_admin());

-- Nomes da equipe, para mostrar os responsáveis nos cartões (só nome e e-mail; nada de senha nem empresas)
create or replace function public.equipe() returns table (user_id uuid, email text, nome text)
language sql stable security definer set search_path = public as $$
  select p.user_id, p.email, p.nome from perfis p where auth.uid() is not null order by coalesce(p.nome, p.email)
$$;
revoke all on function public.equipe() from public, anon;
grant execute on function public.equipe() to authenticated;
