// ============================================================================
// Helpers de autenticação / sessão
// ============================================================================

async function obterSessaoAtual() {
  const { data } = await supabase.auth.getSession();
  return data.session;
}

function ehAdmin(sessao) {
  return !!sessao?.user?.email?.endsWith("@geolayer.com");
}

async function obterClienteAtual() {
  const sessao = await obterSessaoAtual();
  if (!sessao || ehAdmin(sessao)) return null;
  const { data, error } = await supabase
    .from("clientes")
    .select("*")
    .eq("auth_user_id", sessao.user.id)
    .single();
  if (error) {
    console.error(error);
    return null;
  }
  return data;
}

// Chama no topo de cada página de administração
async function exigirAdmin() {
  const sessao = await obterSessaoAtual();
  if (!sessao || !ehAdmin(sessao)) {
    window.location.href = "/index.html";
    return null;
  }
  await registarAcesso("acesso", null, null, true);
  return sessao;
}

// Chama no topo de cada página do portal do cliente
async function exigirCliente() {
  const sessao = await obterSessaoAtual();
  if (!sessao) {
    window.location.href = "/index.html";
    return null;
  }
  const cliente = await obterClienteAtual();
  if (!cliente) {
    window.location.href = "/index.html";
    return null;
  }
  await registarAcesso("acesso", null, cliente.id, true);
  return cliente;
}

async function registarAcesso(tipo, projeto_id, cliente_id, sucesso) {
  try {
    const sessao = await obterSessaoAtual();
    await supabase.from("historico").insert({
      tipo,
      origem: "interno",
      projeto_id,
      cliente_id,
      utilizador: sessao?.user?.email ?? "desconhecido",
      sucesso,
    });
  } catch (e) {
    console.warn("Não foi possível registar acesso", e);
  }
}

async function terminarSessao() {
  await supabase.auth.signOut();
  window.location.href = "/index.html";
}

// Login simples (admin e cliente usam o mesmo mecanismo de Auth)
async function iniciarSessao(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    // conta tentativas falhadas por email, nas últimas 24h
    await supabase.from("historico").insert({
      tipo: "acesso",
      origem: "interno",
      utilizador: email,
      sucesso: false,
    });
    const { count } = await supabase
      .from("historico")
      .select("*", { count: "exact", head: true })
      .eq("utilizador", email)
      .eq("sucesso", false)
      .gte("data_criacao", new Date(Date.now() - 24 * 3600 * 1000).toISOString());
    if (count >= 5) {
      await supabase.from("historico").insert({
        tipo: "alerta",
        origem: "interno",
        mensagem: `5 ou mais tentativas de login falhadas para ${email}`,
      });
    }
    throw error;
  }
  return data;
}
