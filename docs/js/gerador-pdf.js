// ============================================================================
// Motor de geração de documentos — lê relatorio_blocos + projetos + clientes +
// configuracoes, substitui os placeholders {{tabela.campo}}, gera PDF com
// pdfmake, e funde vários PDFs com pdf-lib para o "Dossier Completo".
//
// Requer no HTML, antes deste ficheiro:
//   <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.9/pdfmake.min.js"></script>
//   <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.9/vfs_fonts.js"></script>
//   <script src="https://unpkg.com/pdf-lib@1.17.1/dist/pdf-lib.min.js"></script>
// ============================================================================

async function obterContextoProjeto(projetoId) {
  const { data: projeto } = await supabase.from('projetos').select('*, clientes(*)').eq('id', projetoId).single();
  const { data: configRows } = await supabase.from('configuracoes').select('chave, valor');
  const config = {};
  (configRows || []).forEach(c => config[c.chave] = c.valor);
  const { count: totalPfs } = await supabase.from('pfs').select('*', { count: 'exact', head: true }).eq('projeto_id', projetoId);
  const { data: primeiroPf } = await supabase.from('pfs').select('data_observacao').eq('projeto_id', projetoId).order('data_observacao').limit(1).maybeSingle();

  return {
    projetos: { ...projeto, cliente_nome: projeto.clientes?.cliente_nome, DATA_PF: primeiroPf?.data_observacao, TOTAL_PFS: totalPfs },
    clientes: projeto.clientes || {},
    config,
  };
}

function substituirPlaceholders(texto, contexto) {
  if (!texto) return '';
  return texto.replace(/\{\{(\w+)\.(\w+)\}\}/g, (tudo, tabela, campo) => {
    const valor = contexto[tabela]?.[campo];
    if (Array.isArray(valor)) return valor.join(', ');
    return (valor === null || valor === undefined) ? '' : String(valor);
  });
}

function condicaoCumprida(condicao, projeto) {
  if (!condicao) return true;
  const temCorrecao = !!(projeto.num_proc_dgt && projeto.dgt_data_correcao);
  if (condicao === 'com_correcao') return temCorrecao;
  if (condicao === 'sem_correcao') return !temCorrecao;
  return true;
}

async function gerarPdfDesdeBlocos(documento, projetoId, tituloDocumento) {
  const contexto = await obterContextoProjeto(projetoId);
  const { data: blocos } = await supabase.from('relatorio_blocos').select('*').eq('documento', documento).eq('ativo', true).order('ordem');

  const conteudo = [
    { text: tituloDocumento || documento, style: 'titulo' },
    { text: contexto.config.empresa_nome || '', margin: [0, 0, 0, 20] },
  ];

  (blocos || []).filter(b => condicaoCumprida(b.condicao, contexto.projetos)).forEach(b => {
    if (b.seccao_titulo) conteudo.push({ text: `${b.seccao_numero || ''} ${b.seccao_titulo}`, style: b.nivel === 1 ? 'titulo2' : 'titulo3' });
    if (b.tipo_bloco === 'texto') {
      conteudo.push({ text: substituirPlaceholders(b.conteudo?.texto, contexto), margin: [0, 2, 0, 10] });
    } else if (b.tipo_bloco === 'tabela' && b.conteudo?.linhas) {
      conteudo.push({
        table: { body: b.conteudo.linhas.map(linha => linha.map(cel => substituirPlaceholders(cel, contexto))) },
        margin: [0, 4, 0, 10],
      });
    }
  });

  const docDefinition = {
    content: conteudo,
    styles: {
      titulo: { fontSize: 16, bold: true, margin: [0, 0, 0, 10] },
      titulo2: { fontSize: 13, bold: true, margin: [0, 10, 0, 4] },
      titulo3: { fontSize: 11, bold: true, margin: [0, 8, 0, 2] },
    },
    footer: (pagina, total) => ({
      text: `${contexto.config.empresa_nome || ''} · ${contexto.config.empresa_morada || ''}   —   Folha ${pagina} de ${total}`,
      fontSize: 8, margin: [40, 0, 40, 0],
    }),
  };

  return await new Promise(resolve => pdfMake.createPdf(docDefinition).getBuffer(resolve));
}

async function gerarPdfFormularioDGT(projetoId) {
  const contexto = await obterContextoProjeto(projetoId);
  const p = contexto.projetos, c = contexto.clientes;
  const linhas = [
    ['CONCELHOS', (p.proj_concelho || []).join(', ')],
    ['TIPO CARTOGRAFIA', p.tipo_cartografia || ''],
    ['TIPO PRODUTO', p.tipo_produto || ''],
    ['TEMAS ESPECIFICOS', p.temas_especificos ? 'Sim' : 'Não'],
    ['FINALIDADE', p.finalidade_produto || ''],
    ['Nº PROCESSO ANTERIOR', p.num_proc_dgt || ''],
    ['TIPO DE LEVANTAMENTO', p.tipo_levantamento || ''],
    ['SISTEMA COORDENADAS', p.sis_coordenadas || ''],
    ['FORMATO DOS DADOS', p.formato_dados || ''],
    ['ESPECIFICAÇÕES TÉCNICAS', p.especificacoes_tecnicas || ''],
    ['VERSÃO DAS ESPECIFICAÇÕES', p.versao_especificacoes || ''],
    ['DATA AQUISIÇÃO DE IMAGENS', p.voo_data || ''],
    ['DATA CONCLUSÃO TRABALHOS DE CAMPO', p.data_trabalhos_campo || ''],
    ['TÉCNICO RESPONSÁVEL', contexto.config.tecnico_dgt_nome || ''],
    ['ORDEM PROFISSIONAL', contexto.config.tecnico_dgt_ordem || ''],
    ['CÉDULA PROFISSIONAL', contexto.config.tecnico_dgt_numero_inscricao || ''],
    ['PRODUTOR', contexto.config.empresa_nome || ''],
    ['NOME ENTIDADE PROPRIETÁRIA', c.cliente_nome || ''],
    ['EMAIL ENT. PROPRIETÁRIA', c.cliente_email || ''],
    ['TELEFONE ENT. PROPRIETÁRIA', c.cliente_telefone || ''],
    ['NIF ENT. PROPRIETÁRIA', c.cliente_nif || ''],
    ['MORADA ENT. PROPRIETÁRIA', c.cliente_morada || ''],
    ['LOCALIDADE / COD POSTAL', c.cliente_cod_postal || ''],
  ];
  const docDefinition = {
    content: [
      { text: 'DADOS PARA FORMULARIO DGT', style: 'titulo' },
      { text: p.titulo, margin: [0, 0, 0, 14] },
      { table: { widths: ['50%', '50%'], body: linhas }, layout: 'lightHorizontalLines' },
    ],
    styles: { titulo: { fontSize: 14, bold: true } },
  };
  return await new Promise(resolve => pdfMake.createPdf(docDefinition).getBuffer(resolve));
}

async function gerarPdfRelatorioPFs(projetoId) {
  const contexto = await obterContextoProjeto(projetoId);
  const { data: pfs } = await supabase.from('pfs').select('*').eq('projeto_id', projetoId).order('pf_num');
  const p = contexto.projetos;
  const hoje = new Date().toISOString().slice(0, 10);

  const conteudo = [];
  (pfs || []).forEach((pf, i) => {
    if (i > 0) conteudo.push({ text: '', pageBreak: 'before' });
    conteudo.push(
      { text: 'APOIO FOTOGRAMÉTRICO', style: 'titulo' },
      { columns: [
          { text: `CLIENTE: ${p.cliente_nome || ''}\nPROJETO: ${p.cod_geolayer || ''} ${p.titulo}\nTÉCNICO RESPONSÁVEL: ${contexto.config.tecnico_campo_nome || ''}\nDATA DE EMISSÃO: ${hoje}` },
      ], margin: [0, 0, 0, 10] },
      { text: `APOIO FOTOGRAMÉTRICO Nº ${pf.pf_num}`, style: 'titulo2' },
      { text: 'LOCALIZAÇÃO:', style: 'titulo3' },
      { text: `Distrito: ${pf.distrito || ''}    Concelho: ${pf.concelho || ''}    Freguesia: ${pf.freguesia || ''}` },
      { text: 'CARACTERÍSTICAS:', style: 'titulo3' },
      { text: `Data da Observação: ${pf.data_observacao || ''}   Hora de Início: ${pf.hora_inicio || ''}   Hora de Fim: ${pf.hora_fim || ''}` },
      { text: `Altura da Antena (m): ${pf.altura_antena ?? ''}   Nº de Épocas: ${pf.n_epocas ?? ''}   Taxa de Observação (s): ${pf.taxa_observacao ?? ''}   Máscara (º): ${pf.mascara ?? ''}` },
      { text: 'SISTEMA DE COORDENADAS:', style: 'titulo3' },
      { text: `${pf.sist_coordenadas || ''}` },
      { text: `M= ${pf.coord_m ?? ''}   P= ${pf.coord_p ?? ''}   Z (PF)= ${pf.coord_z_pf ?? ''}   Z (PF solo)= ${pf.coord_z_pfsolo ?? ''}`, margin: [0, 4, 0, 8] },
      { text: 'OBSERVAÇÕES:', style: 'titulo3' },
      { text: pf.observacoes || '' },
      { text: `PF - ${pf.pf_num}`, alignment: 'center', margin: [0, 20, 0, 0] },
      { text: `FONTE: ${contexto.config.empresa_fonte_pf || ''}`, fontSize: 8, margin: [0, 20, 0, 0] },
    );
  });

  const docDefinition = {
    content: conteudo,
    styles: {
      titulo: { fontSize: 14, bold: true, alignment: 'center' },
      titulo2: { fontSize: 12, bold: true, alignment: 'right', margin: [0, 6, 0, 10] },
      titulo3: { fontSize: 10, bold: true, margin: [0, 8, 0, 2] },
    },
    footer: (pagina, total) => ({
      text: `${contexto.config.empresa_nome || ''}\n${contexto.config.empresa_morada || ''}                                                       FOLHA ${pagina} de ${total}`,
      fontSize: 8, margin: [40, 0, 40, 0],
    }),
  };
  return await new Promise(resolve => pdfMake.createPdf(docDefinition).getBuffer(resolve));
}

function gerarXmlMetadados(contexto) {
  const p = contexto.projetos, c = contexto.clientes;
  const epsgPorSistema = { 'EPSG:3763': '3763', 'EPSG:5011': '5011', 'EPSG:5016': '5016' };
  const codigoEpsg = epsgPorSistema[p.sis_coordenadas] || '3763';
  const hoje = new Date().toISOString().slice(0, 10);
  const resumo = `Cartografia para o ${p.titulo}. Levantamento efectuado em ${p.data_trabalhos_campo || ''}.`;
  return `<?xml version="1.0" encoding="UTF-8"?>
<gmd:MD_Metadata xmlns:gmd="http://www.isotc211.org/2005/gmd" xmlns:gco="http://www.isotc211.org/2005/gco">
  <gmd:fileIdentifier><gco:CharacterString>${crypto.randomUUID()}</gco:CharacterString></gmd:fileIdentifier>
  <gmd:dateStamp><gco:Date>${hoje}</gco:Date></gmd:dateStamp>
  <gmd:referenceSystemInfo><gmd:code>http://www.opengis.net/def/crs/EPSG/0/${codigoEpsg}</gmd:code></gmd:referenceSystemInfo>
  <gmd:identificationInfo>
    <gmd:title><gco:CharacterString>${p.titulo}</gco:CharacterString></gmd:title>
    <gmd:abstract><gco:CharacterString>${resumo}</gco:CharacterString></gmd:abstract>
    <gmd:pointOfContact>
      <gmd:organisationName><gco:CharacterString>${c.cliente_nome || ''}</gco:CharacterString></gmd:organisationName>
      <gmd:electronicMailAddress><gco:CharacterString>${c.cliente_email || ''}</gco:CharacterString></gmd:electronicMailAddress>
    </gmd:pointOfContact>
  </gmd:identificationInfo>
</gmd:MD_Metadata>`;
  // NOTA: bounding box WGS84 fica para ajuste fino — precisa de
  // st_asgeojson(st_envelope(st_transform(geom,4326))) via RPC, à semelhança
  // das outras conversões de geometria desta app.
}

async function gerarPdfDocumento(tipo, projetoId) {
  if (tipo === 'RProducao') return gerarPdfDesdeBlocos('RProducao', projetoId, 'Relatório de Produção');
  if (tipo === 'TCompromisso') return gerarPdfDesdeBlocos('TCompromisso_CEncargos', projetoId, 'Termo de Compromisso');
  if (tipo === 'CEncargos') return gerarPdfDesdeBlocos('TCompromisso_CEncargos', projetoId, 'Caderno de Encargos');
  if (tipo === 'FormularioDGT') return gerarPdfFormularioDGT(projetoId);
  if (tipo === 'RelatorioPFs') return gerarPdfRelatorioPFs(projetoId);
  if (tipo === 'MetadadosXML') {
    const contexto = await obterContextoProjeto(projetoId);
    return new TextEncoder().encode(gerarXmlMetadados(contexto));
  }
  throw new Error('Tipo de documento desconhecido: ' + tipo);
}

function descarregarPdf(bytes, nomeFicheiro) {
  const tipoMime = nomeFicheiro.endsWith('.xml') ? 'application/xml' : 'application/pdf';
  const blob = new Blob([bytes], { type: tipoMime });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = nomeFicheiro;
  a.click();
}

async function gerarDossierCompletoPdf(projetoId) {
  const { PDFDocument } = PDFLib;
  const dossierFinal = await PDFDocument.create();

  const tiposPdf = ['RProducao', 'RelatorioPFs', 'TCompromisso', 'FormularioDGT'];
  for (const tipo of tiposPdf) {
    const bytes = await gerarPdfDocumento(tipo, projetoId);
    const pdfOrigem = await PDFDocument.load(bytes);
    const paginas = await dossierFinal.copyPages(pdfOrigem, pdfOrigem.getPageIndices());
    paginas.forEach(pg => dossierFinal.addPage(pg));
  }

  // Anexos 2 e 3 (upload manual) e o XML de metadados não são PDFs de página —
  // o XML sai sempre como ficheiro próprio; os anexos 2/3, se forem PDF,
  // podem ser fundidos aqui também lendo o ficheiro do Supabase Storage
  // (projetos.anexo2_ficheiro / anexo3_ficheiro) — ajuste fino na ronda de testes.

  return await dossierFinal.save();
}
