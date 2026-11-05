-- Rode DEPOIS de criar o usuário rh@useebrasil.com.br em Authentication > Users.
-- Transforma esse usuário em administrador com acesso a todas as empresas.
insert into public.perfis (user_id, email, nome, is_admin, empresas)
select id, email, 'RH', true, '{usee,rei,kings}'
from auth.users
where email = 'rh@useebrasil.com.br'
on conflict (user_id) do update set is_admin = true, empresas = '{usee,rei,kings}';

-- Conferência: deve aparecer uma linha com is_admin = true
select email, is_admin, empresas from public.perfis;
