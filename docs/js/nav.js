function renderNavAdmin(ativo) {
  const itens = [
    ["dashboard.html", "Dashboard"],
    ["projetos.html", "Projetos"],
    ["clientes.html", "Clientes"],
    ["pfs.html", "PFs"],
    ["mapa.html", "Mapa"],
    ["historico.html", "Histórico"],
    ["configuracoes.html", "Configurações"],
  ];
  document.getElementById("topo").innerHTML = `
    <div><strong>GeoTrack</strong> · Administração</div>
    <nav>${itens.map(([href, nome]) =>
      `<a href="${href}" class="${href === ativo ? 'ativo' : ''}">${nome}</a>`
    ).join('')}</nav>
    <div>
      <button id="btn-tema" onclick="alternarTema()">🌙</button>
      <button onclick="terminarSessao()" style="margin-left:8px;">Sair</button>
    </div>
  `;
}

function renderNavCliente() {
  document.getElementById("topo").innerHTML = `
    <div><strong>GeoTrack</strong> · Portal do Cliente</div>
    <div>
      <button id="btn-tema" onclick="alternarTema()">🌙</button>
      <button onclick="terminarSessao()" style="margin-left:8px;">Sair</button>
    </div>
  `;
}
