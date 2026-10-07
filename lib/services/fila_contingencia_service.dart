import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Venda concluída no caixa que ainda NÃO foi emitida no backend.
///
/// Guarda os payloads já montados para que a sincronização reenvie exatamente
/// o que o operador vendeu. Nunca contém chave de acesso, protocolo ou QR code:
/// esses dados só existem depois que o backend autoriza a NFC-e.
class PendenciaNfce {
  static const String statusPendente = 'PENDENTE_ENVIO';
  static const String statusRevisar = 'REJEITADA_REVISAR';

  final String localId;
  final DateTime criadaEm;
  final Map<String, dynamic> corpoVenda;
  final Map<String, dynamic> corpoNfce;
  final int? parceiroId;

  /// Id da venda no backend quando a etapa POST /api/vendas já foi concluída
  /// (evita criar a venda em duplicidade ao reenviar só a emissão).
  int? vendaId;
  int tentativas;
  String? ultimoErro;
  String status;

  PendenciaNfce({
    required this.localId,
    required this.criadaEm,
    required this.corpoVenda,
    required this.corpoNfce,
    this.parceiroId,
    this.vendaId,
    this.tentativas = 0,
    this.ultimoErro,
    this.status = statusPendente,
  });

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'criadaEm': criadaEm.toIso8601String(),
        'corpoVenda': corpoVenda,
        'corpoNfce': corpoNfce,
        'parceiroId': parceiroId,
        'vendaId': vendaId,
        'tentativas': tentativas,
        'ultimoErro': ultimoErro,
        'status': status,
      };

  factory PendenciaNfce.fromJson(Map<String, dynamic> json) => PendenciaNfce(
        localId: json['localId'] as String,
        criadaEm: DateTime.parse(json['criadaEm'] as String),
        corpoVenda: Map<String, dynamic>.from(json['corpoVenda'] as Map),
        corpoNfce: Map<String, dynamic>.from(json['corpoNfce'] as Map),
        parceiroId: json['parceiroId'] as int?,
        vendaId: json['vendaId'] as int?,
        tentativas: (json['tentativas'] as int?) ?? 0,
        ultimoErro: json['ultimoErro'] as String?,
        status: (json['status'] as String?) ?? statusPendente,
      );
}

/// Fila persistente (SharedPreferences = arquivo JSON no diretório de dados do
/// app) das vendas aguardando emissão no backend.
class FilaContingenciaService {
  static const String _chave = 'fila_nfce_pendente';

  Future<List<PendenciaNfce>> listar() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_chave);
    if (bruto == null || bruto.isEmpty) return [];
    try {
      final lista = jsonDecode(bruto) as List;
      return lista
          .map((e) => PendenciaNfce.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Fila corrompida: não descartar silenciosamente, preservar a cópia bruta.
      await prefs.setString('${_chave}_corrompida', bruto);
      await prefs.remove(_chave);
      return [];
    }
  }

  Future<int> contar() async => (await listar()).length;

  Future<void> adicionar(PendenciaNfce pendencia) async {
    final lista = await listar();
    lista.add(pendencia);
    await _gravar(lista);
  }

  Future<void> atualizar(PendenciaNfce pendencia) async {
    final lista = await listar();
    final i = lista.indexWhere((p) => p.localId == pendencia.localId);
    if (i == -1) return;
    lista[i] = pendencia;
    await _gravar(lista);
  }

  Future<void> remover(String localId) async {
    final lista = await listar();
    lista.removeWhere((p) => p.localId == localId);
    await _gravar(lista);
  }

  Future<void> _gravar(List<PendenciaNfce> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _chave, jsonEncode(lista.map((p) => p.toJson()).toList()));
  }
}
