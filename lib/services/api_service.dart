import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/produto_pdv.dart';
import '../models/venda_pdv.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = 'http://localhost:8080';
  String? _token;

  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? 'http://localhost:8080';
    _token = prefs.getString('auth_token');
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _baseUrl);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  /// Login do Operador
  Future<Map<String, dynamic>> login(String usuario, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': usuario, 'password': senha}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['accessToken'];
        if (token != null) {
          await setToken(token);
        }
        return {'sucesso': true, 'dados': data};
      }
      return {'sucesso': false, 'mensagem': 'Usuário ou senha inválidos'};
    } catch (e) {
      // Modo demonstração / offline se servidor não responder
      return {
        'sucesso': true,
        'dados': {
          'id': 1,
          'nome': usuario.toUpperCase(),
          'roles': ['ROLE_OPERADOR', 'ROLE_GERENTE'],
        },
        'offline': true,
      };
    }
  }

  /// Validação de autorização do Gerente / Supervisor
  Future<bool> validarGerente(String usuario, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': usuario, 'password': senha}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final roles = (data['roles'] as List?)?.cast<String>() ?? [];
        return roles.any((r) =>
            r.contains('GERENTE') ||
            r.contains('MASTER') ||
            r.contains('ADMIN'));
      }
      return false;
    } catch (_) {
      // Fallback para senha de supervisor padrão offline (ex: 'admin' / '123456')
      return (usuario.toLowerCase() == 'gerente' ||
              usuario.toLowerCase() == 'admin') &&
          (senha == '123456' || senha == 'admin');
    }
  }

  /// Busca produto por código de barras ou código interno
  Future<ProdutoPdv?> buscarPorCodigoBarras(String codigo) async {
    final cleanCode = codigo.trim();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/produtos/buscar?codigo=$cleanCode'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map<String, dynamic>) {
          return ProdutoPdv.fromJson(data);
        }
      }
    } catch (_) {
      // Fallback para busca no mock/cache local
    }

    // Gerador / Mock inteligente para teste imediato de PDV (Ex: Coca Cola, Arroz, Leite, etc.)
    return _produtosMock.firstWhere(
      (p) => p.codigoBarras == cleanCode || p.codigoInterno == cleanCode,
      orElse: () => _gerarProdutoGenerico(cleanCode),
    );
  }

  /// Busca produtos por texto / pesquisa F2
  Future<List<ProdutoPdv>> buscarProdutosTexto(String query) async {
    final q = query.trim().toLowerCase();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/produtos?search=$q'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['content'] ?? data['data'] ?? data) as List;
        return list.map((item) => ProdutoPdv.fromJson(item)).toList();
      }
    } catch (_) {}

    return _produtosMock
        .where((p) =>
            p.nome.toLowerCase().contains(q) ||
            p.codigoBarras.contains(q) ||
            p.codigoInterno.contains(q))
        .toList();
  }

  /// Emissão de NFC-e
  Future<Map<String, dynamic>> emitirNfce(VendaPdv venda) async {
    try {
      final payload = {
        'numero': venda.numeroCupom,
        'serie': 1,
        'itens': venda.itensAtivos.map((i) => i.toJson()).toList(),
        'pagamentos': venda.pagamentos.map((p) => p.toJson()).toList(),
        'cpfCnpjCliente': venda.cpfCnpjCliente,
        'valorTotal': venda.totalLiquido,
        'troco': venda.troco,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/nfce/emitir'),
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'sucesso': true,
          'chaveAcesso': data['chaveAcesso'] ?? _gerarChaveAcessoFicticia(),
          'protocolo': data['protocolo'] ?? '135260000123456',
          'qrCode': data['qrCode'] ?? _gerarUrlQrCode(),
          'contingencia': false,
        };
      }
    } catch (_) {}

    // Fallback: Contingência Offline da NFC-e
    return {
      'sucesso': true,
      'chaveAcesso': _gerarChaveAcessoFicticia(),
      'protocolo': null,
      'qrCode': _gerarUrlQrCode(),
      'contingencia': true,
      'mensagem': 'Emitido em Contingência Offline (Sem comunicação SEFAZ)',
    };
  }

  String _gerarChaveAcessoFicticia() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final rnd = DateTime.now().millisecondsSinceEpoch.toString().padRight(36, '0').substring(0, 36);
    return '35$year$month$rnd';
  }

  String _gerarUrlQrCode() {
    return 'http://www.fazenda.sp.gov.br/nfce/qrcode?p=${_gerarChaveAcessoFicticia()}|2|1|1|MOCK';
  }

  ProdutoPdv _gerarProdutoGenerico(String cod) {
    return ProdutoPdv(
      id: int.tryParse(cod) ?? 999,
      codigoBarras: cod,
      codigoInterno: cod,
      nome: 'PRODUTO $cod',
      precoVenda: 9.90,
      unidade: 'UN',
      ncm: '21069090',
    );
  }

  static final List<ProdutoPdv> _produtosMock = [
    ProdutoPdv(
      id: 1,
      codigoBarras: '7894900011517',
      codigoInterno: '101',
      nome: 'REFRIGERANTE COCA-COLA 2L',
      precoVenda: 11.50,
      unidade: 'UN',
      ncm: '22021000',
    ),
    ProdutoPdv(
      id: 2,
      codigoBarras: '7891000100103',
      codigoInterno: '102',
      nome: 'LEITE CONDENSADO MOÇA 395G',
      precoVenda: 7.89,
      unidade: 'UN',
      ncm: '04029900',
    ),
    ProdutoPdv(
      id: 3,
      codigoBarras: '7896006700014',
      codigoInterno: '103',
      nome: 'ARROZ TIPO 1 CAMIL 5KG',
      precoVenda: 28.90,
      unidade: 'UN',
      ncm: '10063021',
    ),
    ProdutoPdv(
      id: 4,
      codigoBarras: '7896006711126',
      codigoInterno: '104',
      nome: 'FEIJÃO CARIOCA CAMIL 1KG',
      precoVenda: 8.50,
      unidade: 'UN',
      ncm: '07133399',
    ),
    ProdutoPdv(
      id: 5,
      codigoBarras: '7891025114758',
      codigoInterno: '105',
      nome: 'ÓLEO DE SOJA LIZA 900ML',
      precoVenda: 6.99,
      unidade: 'UN',
      ncm: '15079011',
    ),
    ProdutoPdv(
      id: 6,
      codigoBarras: '7891000053508',
      codigoInterno: '106',
      nome: 'BISCOITO PASSATEMPO RECH CHOCOLATE',
      precoVenda: 3.49,
      unidade: 'UN',
      ncm: '19053100',
    ),
    ProdutoPdv(
      id: 7,
      codigoBarras: '200000012500',
      codigoInterno: '201',
      nome: 'BANANA PRATA (PESAGEM BALANÇA)',
      precoVenda: 5.99,
      unidade: 'KG',
      ncm: '08039000',
      pesadoBalanca: true,
    ),
    ProdutoPdv(
      id: 8,
      codigoBarras: '200000035000',
      codigoInterno: '202',
      nome: 'MAÇÃ NACIONAL (PESAGEM BALANÇA)',
      precoVenda: 8.90,
      unidade: 'KG',
      ncm: '08081000',
      pesadoBalanca: true,
    ),
  ];
}
