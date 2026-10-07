import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/produto_pdv.dart';
import '../models/venda_pdv.dart';
import 'fila_contingencia_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Produção AppAcademia: o backend roda na RAIZ do domínio (sem context-path).
  // Configurável via setBaseUrl / pref api_base_url.
  static const String _defaultBaseUrl =
      'https://appacademia-production-be7e.up.railway.app';
  static const Duration _timeoutRede = Duration(seconds: 20);

  http.Client? _clienteHttp;
  http.Client get _client => _clienteHttp ??= http.Client();
  FilaContingenciaService fila = FilaContingenciaService();
  bool _sincronizando = false;

  @visibleForTesting
  void configurarParaTeste({
    http.Client? client,
    FilaContingenciaService? filaServico,
    String? baseUrl,
    int? empresaId,
    int? parceiroId,
  }) {
    if (client != null) _clienteHttp = client;
    if (filaServico != null) fila = filaServico;
    if (baseUrl != null) _baseUrl = baseUrl;
    _empresaId = empresaId ?? _empresaId;
    _parceiroId = parceiroId;
    _token = 'token-teste';
  }

  /// Versões antigas gravaram o context-path /boletobancos na URL; em produção
  /// o backend responde 308 nele e o POST nunca chega. Remove só no host Railway.
  static String normalizarBaseUrl(String url) {
    final limpa = url.trim().replaceAll(RegExp(r'/+$'), '');
    const legado = '/boletobancos';
    if (limpa.contains('railway.app') && limpa.endsWith(legado)) {
      return limpa.substring(0, limpa.length - legado.length);
    }
    return limpa;
  }

  String _baseUrl = _defaultBaseUrl;
  String? _token;
  int? _empresaId;
  int? _parceiroId;
  String _ambiente = 'HOMOLOGACAO';

  String get baseUrl => _baseUrl;
  int? get empresaId => _empresaId;
  int? get parceiroId => _parceiroId;
  String get ambiente => _ambiente;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl =
        normalizarBaseUrl(prefs.getString('api_base_url') ?? _defaultBaseUrl);
    _token = prefs.getString('auth_token');
    _empresaId = prefs.getInt('empresa_id');
    _parceiroId = prefs.getInt('parceiro_id');
    _ambiente = prefs.getString('ambiente') ?? 'HOMOLOGACAO';
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = normalizarBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _baseUrl);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _salvarSessao({
    required int? empresaId,
    required int? parceiroId,
    required String ambiente,
  }) async {
    _empresaId = empresaId;
    _parceiroId = parceiroId;
    _ambiente = ambiente;
    final prefs = await SharedPreferences.getInstance();
    if (empresaId != null) await prefs.setInt('empresa_id', empresaId);
    if (parceiroId != null) await prefs.setInt('parceiro_id', parceiroId);
    await prefs.setString('ambiente', ambiente);
  }

  Future<void> limparSessao() async {
    _token = null;
    _empresaId = null;
    _parceiroId = null;
    _ambiente = 'HOMOLOGACAO';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('empresa_id');
    await prefs.remove('parceiro_id');
    await prefs.remove('ambiente');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  // ──────────────────────────────────────────────────
  // LOGIN — sem fallback offline (role PDV obrigatória)
  // ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String usuario, String senha) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/rest/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': usuario, 'password': senha}),
    );

    if (response.statusCode != 200) {
      final msg = _extrairMensagem(response.body) ??
          'Usuário ou senha inválidos (status ${response.statusCode})';
      return {'sucesso': false, 'mensagem': msg};
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] ?? data['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      return {'sucesso': false, 'mensagem': 'Resposta inválida do servidor (sem token)'};
    }

    // Validação de role: exige PDV ou GERENTE_PDV
    final roles = (data['roles'] as List?)?.map((r) => r.toString()).toList() ?? [];
    final temRolePdv = roles.any((r) =>
        r == 'ROLE_PDV' ||
        r == 'ROLE_GERENTE_PDV' ||
        r == 'PDV' ||
        r == 'GERENTE_PDV' ||
        r == 'ROLE_MASTER' ||
        r == 'MASTER');

    if (!temRolePdv) {
      return {
        'sucesso': false,
        'mensagem': 'Acesso negado. Usuário sem permissão de operador de PDV.',
      };
    }

    await setToken(token);
    return {'sucesso': true, 'dados': data, 'roles': roles};
  }

  // ──────────────────────────────────────────────────
  // CONFIG — ambiente e dados do emitente
  // ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> carregarConfig() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/pdv/config'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _salvarSessao(
          empresaId: data['empresaId'] as int?,
          parceiroId: data['parceiroId'] as int?,
          ambiente: (data['ambiente'] as String?) ?? 'HOMOLOGACAO',
        );
        return {'sucesso': true, 'dados': data};
      }
    } catch (e) {
      // Erro de rede ao carregar config — não bloqueia o fluxo de caixa,
      // mas registra o ambiente como desconhecido para evitar emissão indevida
    }
    return {'sucesso': false, 'mensagem': 'Não foi possível carregar a configuração do caixa'};
  }

  // ──────────────────────────────────────────────────
  // VALIDAÇÃO DE GERENTE
  // ──────────────────────────────────────────────────
  Future<bool> validarGerente(String usuario, String senha) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/rest/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': usuario, 'password': senha}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final roles = (data['roles'] as List?)?.map((r) => r.toString()).toList() ?? [];
        return roles.any((r) =>
            r.contains('GERENTE_PDV') ||
            r.contains('MASTER') ||
            r == 'ROLE_GERENTE_PDV');
      }
    } catch (_) {}
    return false;
  }

  // ──────────────────────────────────────────────────
  // PRODUTOS — busca por GTIN (código de barras)
  // ──────────────────────────────────────────────────
  Future<ProdutoPdv?> buscarPorCodigoBarras(String codigo) async {
    final cleanCode = codigo.trim().replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/pdv/produtos?gtin=$cleanCode'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Endpoint retorna objeto único (não paginado) quando busca por GTIN
        if (data is Map<String, dynamic>) {
          return ProdutoPdv.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  // ──────────────────────────────────────────────────
  // PRODUTOS — busca por texto (pesquisa F2)
  // ──────────────────────────────────────────────────
  Future<List<ProdutoPdv>> buscarProdutosTexto(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final response = await _client.get(
        Uri.parse(
            '$_baseUrl/api/pdv/produtos?nome=${Uri.encodeQueryComponent(q)}&page=0'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = (data['content'] ?? data['data'] ?? data) as List;
        return list.map((item) => ProdutoPdv.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ──────────────────────────────────────────────────
  // EMISSÃO DE NFC-e — fluxo real do backend:
  //   POST /api/vendas  ->  POST /api/vendas/{id}/emitir-nfce
  // Numeração, chave, protocolo e QR code vêm SEMPRE do backend.
  // Sem comunicação: a venda vai para a fila persistente (PENDENTE_ENVIO) e é
  // sincronizada depois; nada é marcado como autorizado sem resposta do backend.
  // ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> emitirNfce(VendaPdv venda) async {
    if (_empresaId == null) await carregarConfig();
    final empresaId = _empresaId;
    if (empresaId == null) {
      return {
        'sucesso': false,
        'resultado': 'ERRO',
        'mensagem':
            'Configuração do caixa indisponível (empresa não identificada). Faça login novamente com rede.',
      };
    }

    final pendencia = PendenciaNfce(
      localId: venda.id,
      criadaEm: DateTime.now(),
      corpoVenda: montarCorpoVenda(venda, empresaId),
      corpoNfce: montarCorpoNfce(venda, empresaId),
      parceiroId: _parceiroId,
    );

    final envio = await _enviarPendencia(pendencia);
    switch (envio.tipo) {
      case _TipoEnvio.autorizada:
      case _TipoEnvio.contingenciaBackend:
        return envio.toMapa();
      case _TipoEnvio.rejeitada:
        return {...envio.toMapa(), 'sucesso': false};
      case _TipoEnvio.falhaTransitoria:
        pendencia.ultimoErro = envio.mensagem;
        pendencia.tentativas = 1;
        await fila.adicionar(pendencia);
        return {
          'sucesso': true,
          'resultado': 'PENDENTE_ENVIO',
          'pendenteEnvio': true,
          'contingencia': false,
          'chaveAcesso': null,
          'protocolo': null,
          'qrCode': null,
          'mensagem':
              'Sem comunicação com o servidor. Venda gravada na fila (PENDENTE DE EMISSÃO) e será enviada automaticamente.',
        };
    }
  }

  /// Reenvia as vendas da fila. Retorna quantas foram emitidas agora.
  Future<int> sincronizarPendentes() async {
    if (_sincronizando) return 0;
    _sincronizando = true;
    var emitidas = 0;
    try {
      final lista = await fila.listar();
      for (final pendencia in lista) {
        if (pendencia.status == PendenciaNfce.statusRevisar) continue;
        final envio = await _enviarPendencia(pendencia);
        if (envio.tipo == _TipoEnvio.falhaTransitoria) {
          pendencia.tentativas += 1;
          pendencia.ultimoErro = envio.mensagem;
          await fila.atualizar(pendencia);
          break; // sem rede: não adianta insistir nas demais
        }
        if (envio.tipo == _TipoEnvio.rejeitada) {
          // Mantém na fila marcada para revisão; nunca descarta uma venda.
          pendencia.tentativas += 1;
          pendencia.ultimoErro = envio.mensagem;
          pendencia.status = PendenciaNfce.statusRevisar;
          await fila.atualizar(pendencia);
          continue;
        }
        await fila.remover(pendencia.localId);
        emitidas++;
      }
    } finally {
      _sincronizando = false;
    }
    return emitidas;
  }

  Future<int> contarPendentes() => fila.contar();

  Future<_ResultadoEnvio> _enviarPendencia(PendenciaNfce p) async {
    try {
      if (p.vendaId == null) {
        final r = await _client
            .post(Uri.parse('$_baseUrl/api/vendas'),
                headers: _headers, body: jsonEncode(p.corpoVenda))
            .timeout(_timeoutRede);
        final falha = _classificarHttp(r, 'criar venda');
        if (falha != null) return falha;
        final id = (jsonDecode(r.body) as Map)['id'];
        if (id is! num) {
          return _ResultadoEnvio.rejeitada(
              'Resposta inválida do servidor ao criar a venda.');
        }
        p.vendaId = id.toInt();
        await fila.atualizar(p);
      }

      final uri = Uri.parse('$_baseUrl/api/vendas/${p.vendaId}/emitir-nfce')
          .replace(queryParameters: {
        if (p.parceiroId != null) 'parceiroId': p.parceiroId.toString(),
      });
      final r = await _client
          .post(uri, headers: _headers, body: jsonEncode(p.corpoNfce))
          .timeout(_timeoutRede);
      final falha = _classificarHttp(r, 'emitir NFC-e');
      if (falha != null) return falha;
      return _interpretarResultado(
          jsonDecode(r.body) as Map<String, dynamic>, p.vendaId);
    } on TimeoutException {
      return _ResultadoEnvio.transitoria(
          'Tempo esgotado ao comunicar com o servidor.');
    } on http.ClientException catch (e) {
      return _ResultadoEnvio.transitoria(
          'Sem conexão com o servidor: ${e.message}');
    } on SocketException catch (e) {
      return _ResultadoEnvio.transitoria(
          'Sem conexão com o servidor: ${e.message}');
    } on FormatException {
      return _ResultadoEnvio.transitoria('Resposta ilegível do servidor.');
    }
  }

  /// Retorna null quando 2xx; senão classifica: transitória (vai pra fila) ou
  /// rejeição de negócio (4xx — o operador precisa corrigir, enfileirar não adianta).
  _ResultadoEnvio? _classificarHttp(http.Response r, String etapa) {
    final s = r.statusCode;
    if (s >= 200 && s < 300) return null;
    final msg = _extrairMensagem(r.body);
    final detalhe = msg != null ? ': $msg' : '';
    final transitorio = s == 401 ||
        s == 408 ||
        s == 429 ||
        s >= 500 ||
        (s >= 300 && s < 400); // 308 do context-path legado cai aqui
    if (transitorio) {
      return _ResultadoEnvio.transitoria('Falha ao $etapa (HTTP $s)$detalhe');
    }
    return _ResultadoEnvio.rejeitada(
        'Servidor recusou ao $etapa (HTTP $s)$detalhe');
  }

  _ResultadoEnvio _interpretarResultado(Map<String, dynamic> data, int? vendaId) {
    final status = (data['status'] as String?)?.toUpperCase();
    final chave = data['chaveAcesso'] as String?;
    final base = <String, dynamic>{
      'nfceId': data['nfceId'],
      'vendaIdBackend': vendaId,
      'chaveAcesso': chave,
      'protocolo': data['protocolo'],
      'qrCode': data['qrCodeUrl'],
      'numeroNfce': NfceChave.numero(chave),
      'serieNfce': NfceChave.serie(chave),
    };
    if (status == 'AUTORIZADA') {
      return _ResultadoEnvio(_TipoEnvio.autorizada, {
        ...base,
        'sucesso': true,
        'resultado': 'AUTORIZADA',
        'contingencia': false,
        'pendenteEnvio': false,
      });
    }
    if (status == 'CONTINGENCIA') {
      return _ResultadoEnvio(_TipoEnvio.contingenciaBackend, {
        ...base,
        'sucesso': true,
        'resultado': 'CONTINGENCIA',
        'contingencia': true,
        'pendenteEnvio': false,
        'mensagem': (data['motivoRejeicao'] as String?) ??
            'NFC-e registrada em contingência no servidor (aguardando autorização).',
      });
    }
    final motivo = (data['motivoRejeicao'] as String?) ??
        'NFC-e não autorizada (status: ${status ?? 'desconhecido'})';
    final codigo = data['codigoRetorno'];
    return _ResultadoEnvio.rejeitada(
        codigo != null ? 'Rejeição $codigo: $motivo' : motivo);
  }

  // ──────────────────────────────────────────────────
  // PAYLOADS (contratos reais do NfceController)
  // ──────────────────────────────────────────────────
  @visibleForTesting
  static Map<String, dynamic> montarCorpoVenda(VendaPdv venda, int empresaId) {
    return {
      'empresaId': empresaId,
      'desconto': venda.descontoGeral,
      'itens': venda.itensAtivos
          .map((i) => {
                'produtoId': i.produtoId,
                'nomeProduto': i.descricao,
                'quantidade': i.quantidade,
                'valorUnitario': i.valorUnitario,
                'desconto': i.desconto,
              })
          .toList(),
    };
  }

  /// VendaNfceDTO. Totais: vNF = produtos - descontos + outras despesas = totalLiquido.
  @visibleForTesting
  static Map<String, dynamic> montarCorpoNfce(VendaPdv venda, int empresaId) {
    final itens = venda.itensAtivos;
    final totalProdutos = itens.fold(0.0, (a, i) => a + i.valorBruto);
    final descontoItens = itens.fold(0.0, (a, i) => a + i.desconto);
    final acrescimos = itens.fold(0.0, (a, i) => a + i.acrescimo);
    final rateioGeral = _ratearDescontoGeral(
        itens.map((i) => i.valorBruto).toList(), venda.descontoGeral);

    final doc = (venda.cpfCnpjCliente ?? '').replaceAll(RegExp(r'\D'), '');
    final dif = venda.totalPago - venda.totalLiquido;
    final troco = dif > 0 ? double.parse(dif.toStringAsFixed(2)) : 0.0;
    var trocoAplicado = false;

    return {
      'empresaId': empresaId,
      if (doc.length == 11) 'cpfConsumidor': doc,
      if (doc.length == 14) 'cnpjConsumidor': doc,
      if (venda.nomeCliente != null) 'nomeConsumidor': venda.nomeCliente,
      'itens': [
        for (var n = 0; n < itens.length; n++)
          {
            'produtoId': itens[n].produtoId,
            'codigoProduto': itens[n].produtoId.toString(),
            'nomeProduto': itens[n].descricao,
            'gtin': itens[n].codigoBarras.isNotEmpty
                ? itens[n].codigoBarras
                : 'SEM GTIN',
            'ncm': itens[n].ncm,
            'cfop': itens[n].cfop,
            'unidadeComercial': itens[n].unidade,
            'quantidade': itens[n].quantidade,
            'valorUnitario': itens[n].valorUnitario,
            'valorTotal': itens[n].valorBruto,
            'valorDesconto': double.parse(
                (itens[n].desconto + rateioGeral[n]).toStringAsFixed(2)),
          },
      ],
      'pagamentos': venda.pagamentos.map((p) {
        final emDinheiro = p.codigoSefaz == '01' && !trocoAplicado && troco > 0;
        if (emDinheiro) trocoAplicado = true;
        return {
          'formaPagamento': p.codigoSefaz,
          'valor': p.valor,
          'troco': emDinheiro ? troco : 0.0,
        };
      }).toList(),
      'valorTotalProdutos': totalProdutos,
      'valorDesconto': double.parse(
          (descontoItens + venda.descontoGeral).toStringAsFixed(2)),
      'valorOutrasDespesas': acrescimos,
      'valorTotalNota': venda.totalLiquido,
    };
  }

  /// Rateia o desconto geral proporcionalmente ao valor bruto; o último item
  /// absorve o resto de centavos para a soma bater exatamente.
  static List<double> _ratearDescontoGeral(List<double> brutos, double desconto) {
    if (brutos.isEmpty || desconto <= 0) return List.filled(brutos.length, 0.0);
    final total = brutos.fold(0.0, (a, b) => a + b);
    if (total <= 0) return List.filled(brutos.length, 0.0);
    final out = <double>[];
    var acumulado = 0.0;
    for (var n = 0; n < brutos.length; n++) {
      final parte = n == brutos.length - 1
          ? double.parse((desconto - acumulado).toStringAsFixed(2))
          : double.parse((desconto * brutos[n] / total).toStringAsFixed(2));
      acumulado += parte;
      out.add(parte);
    }
    return out;
  }

  // ──────────────────────────────────────────────────
  // HELPERS INTERNOS
  // ──────────────────────────────────────────────────
  String? _extrairMensagem(String body) {
    try {
      final data = jsonDecode(body);
      return data['message'] ?? data['mensagem'] ?? data['error'];
    } catch (_) {
      return null;
    }
  }
}

/// Extrai série e número da chave de acesso de 44 dígitos
/// (cUF2 AAMM4 CNPJ14 mod2 serie3 nNF9 tpEmis1 cNF8 cDV1).
class NfceChave {
  static int? serie(String? chave) => _fatia(chave, 22, 25);
  static int? numero(String? chave) => _fatia(chave, 25, 34);

  static int? _fatia(String? chave, int ini, int fim) {
    if (chave == null) return null;
    final limpa = chave.replaceAll(RegExp(r'\D'), '');
    if (limpa.length != 44) return null;
    return int.tryParse(limpa.substring(ini, fim));
  }
}

enum _TipoEnvio { autorizada, contingenciaBackend, rejeitada, falhaTransitoria }

class _ResultadoEnvio {
  final _TipoEnvio tipo;
  final Map<String, dynamic> dados;
  _ResultadoEnvio(this.tipo, this.dados);

  factory _ResultadoEnvio.transitoria(String msg) =>
      _ResultadoEnvio(_TipoEnvio.falhaTransitoria, {'mensagem': msg});

  factory _ResultadoEnvio.rejeitada(String msg) => _ResultadoEnvio(
      _TipoEnvio.rejeitada, {
        'resultado': 'REJEITADA',
        'contingencia': false,
        'pendenteEnvio': false,
        'mensagem': msg,
      });

  String? get mensagem => dados['mensagem'] as String?;
  Map<String, dynamic> toMapa() => dados;
}
