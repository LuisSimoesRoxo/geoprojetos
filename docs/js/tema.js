// ============================================================================
// Tema claro/escuro — guardado por login (tabela preferencias_utilizador),
// não no navegador. Por defeito: claro.
// ============================================================================

async function aplicarTemaInicial() {
  let tema = "claro";
  const { data } = await supabase.auth.getSession();
  if (data.session) {
    const { data: pref } = await supabase
      .from("preferencias_utilizador")
      .select("tema")
      .eq("auth_user_id", data.session.user.id)
      .maybeSingle();
    if (pref?.tema) tema = pref.tema;
  }
  document.documentElement.setAttribute("data-tema", tema);
  atualizarIconeTema(tema);
}

async function alternarTema() {
  const atual = document.documentElement.getAttribute("data-tema") || "claro";
  const novo = atual === "claro" ? "escuro" : "claro";
  document.documentElement.setAttribute("data-tema", novo);
  atualizarIconeTema(novo);

  const { data } = await supabase.auth.getSession();
  if (data.session) {
    await supabase.from("preferencias_utilizador").upsert({
      auth_user_id: data.session.user.id,
      tema: novo,
      data_atualizacao: new Date().toISOString(),
    });
  }
}

function atualizarIconeTema(tema) {
  const btn = document.getElementById("btn-tema");
  if (btn) btn.textContent = tema === "claro" ? "🌙" : "☀️";
}

document.addEventListener("DOMContentLoaded", aplicarTemaInicial);
