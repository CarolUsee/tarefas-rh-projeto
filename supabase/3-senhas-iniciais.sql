-- Senha inicial gerada pelo RH, para o administrador ver e copiar quando quiser.
-- Só o servidor (Vercel, com a chave secreta) lê e grava esta tabela.
-- Quando a pessoa troca a própria senha, o registro é apagado: a senha pessoal nunca fica guardada.
-- Rode este arquivo uma vez no SQL Editor do Supabase.

create table if not exists public.senhas_iniciais (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  senha     text not null,
  gerada_em timestamptz not null default now()
);

alter table public.senhas_iniciais enable row level security;

-- Pelo navegador, cada pessoa só enxerga e apaga o próprio registro (necessário para apagar ao trocar a senha).
-- Ninguém vê a senha de outra pessoa; o administrador vê pela tela de usuários, via servidor.
drop policy if exists senhas_ver_propria on public.senhas_iniciais;
create policy senhas_ver_propria on public.senhas_iniciais for select to authenticated
  using (user_id = auth.uid());
drop policy if exists senhas_apagar_propria on public.senhas_iniciais;
create policy senhas_apagar_propria on public.senhas_iniciais for delete to authenticated
  using (user_id = auth.uid());
