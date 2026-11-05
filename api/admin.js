// Função do Vercel para a tela "Usuários e acessos".
// Só o administrador consegue usar. A chave secreta fica nas variáveis de ambiente do Vercel.
import { createClient } from '@supabase/supabase-js';
import { randomInt } from 'node:crypto';

const EMPRESAS = ['usee', 'rei', 'kings'];

function gerarSenha() {
  const mai = 'ABCDEFGHJKLMNPQRSTUVWXYZ', min = 'abcdefghjkmnpqrstuvwxyz', num = '23456789';
  const todos = mai + min + num;
  const p = [mai[randomInt(mai.length)], min[randomInt(min.length)], num[randomInt(num.length)]];
  while (p.length < 10) p.push(todos[randomInt(todos.length)]);
  for (let i = p.length - 1; i > 0; i--) { const j = randomInt(i + 1); [p[i], p[j]] = [p[j], p[i]]; }
  return p.join('');
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método não permitido.' });

  const url = process.env.SUPABASE_URL, chave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !chave) return res.status(500).json({ error: 'Faltam as variáveis SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no Vercel.' });
  const sb = createClient(url, chave, { auth: { persistSession: false, autoRefreshToken: false } });

  // Confere quem está pedindo
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: 'Entre de novo no sistema.' });
  const { data: quem, error: e1 } = await sb.auth.getUser(token);
  if (e1 || !quem?.user) return res.status(401).json({ error: 'Sua sessão expirou. Entre de novo.' });
  const { data: eu } = await sb.from('perfis').select('is_admin').eq('user_id', quem.user.id).maybeSingle();
  if (!eu?.is_admin) return res.status(403).json({ error: 'Só o administrador pode gerenciar acessos.' });

  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
  const { action } = body;
  const empresasValidas = l => Array.isArray(l) && l.every(x => EMPRESAS.includes(x));

  async function alvo(id) {
    const { data } = await sb.from('perfis').select('user_id,email,is_admin').eq('user_id', id).maybeSingle();
    return data;
  }

  try {
    if (action === 'list') {
      const { data, error } = await sb.from('perfis').select('user_id,email,nome,is_admin,empresas').order('is_admin', { ascending: false }).order('email');
      if (error) throw error;
      return res.json({ users: data });
    }

    if (action === 'create') {
      const email = String(body.email || '').trim().toLowerCase();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return res.status(400).json({ error: 'E-mail inválido.' });
      if (!empresasValidas(body.empresas) || !body.empresas.length) return res.status(400).json({ error: 'Marque pelo menos uma empresa.' });
      const senha = gerarSenha();
      const { data: novo, error } = await sb.auth.admin.createUser({ email, password: senha, email_confirm: true });
      if (error) {
        if (/already|registered|exists/i.test(error.message)) return res.status(409).json({ error: 'Já existe um acesso com este e-mail. Use Resetar senha na lista.' });
        throw error;
      }
      const { error: e2 } = await sb.from('perfis').insert({ user_id: novo.user.id, email, nome: String(body.nome || '').trim() || null, is_admin: false, empresas: body.empresas });
      if (e2) { await sb.auth.admin.deleteUser(novo.user.id); throw e2; }
      return res.json({ password: senha });
    }

    if (action === 'update') {
      const t = await alvo(body.user_id);
      if (!t) return res.status(404).json({ error: 'Usuário não encontrado.' });
      if (t.is_admin) return res.status(400).json({ error: 'O administrador já vê todas as empresas.' });
      if (!empresasValidas(body.empresas)) return res.status(400).json({ error: 'Empresas inválidas.' });
      const { error } = await sb.from('perfis').update({ empresas: body.empresas }).eq('user_id', t.user_id);
      if (error) throw error;
      return res.json({ ok: true });
    }

    if (action === 'reset') {
      const t = await alvo(body.user_id);
      if (!t) return res.status(404).json({ error: 'Usuário não encontrado.' });
      if (t.is_admin) return res.status(400).json({ error: 'Para a sua senha, use Trocar minha senha.' });
      const senha = gerarSenha();
      const { error } = await sb.auth.admin.updateUserById(t.user_id, { password: senha });
      if (error) throw error;
      return res.json({ password: senha });
    }

    if (action === 'delete') {
      const t = await alvo(body.user_id);
      if (!t) return res.status(404).json({ error: 'Usuário não encontrado.' });
      if (t.is_admin) return res.status(400).json({ error: 'O administrador não pode ser removido por aqui.' });
      const { error } = await sb.auth.admin.deleteUser(t.user_id);
      if (error) throw error;
      return res.json({ ok: true });
    }

    return res.status(400).json({ error: 'Ação desconhecida.' });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Erro no servidor. Tente de novo.' });
  }
}
