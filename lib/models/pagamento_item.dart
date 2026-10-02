import '../core/constants/pdv_constants.dart';

class PagamentoItem {
  final String codigoSefaz;
  final double valor;
  final String? bandeiraCartao;
  final String? autorizacaoCartao;

  PagamentoItem({
    required this.codigoSefaz,
    required this.valor,
    this.bandeiraCartao,
    this.autorizacaoCartao,
  });

  String get descricao => FormaPagamentoSefaz.getDescricao(codigoSefaz);

  Map<String, dynamic> toJson() {
    return {
      'codigoSefaz': codigoSefaz,
      'valor': valor,
      'bandeiraCartao': bandeiraCartao,
      'autorizacaoCartao': autorizacaoCartao,
    };
  }

  factory PagamentoItem.fromJson(Map<String, dynamic> json) {
    return PagamentoItem(
      codigoSefaz: json['codigoSefaz'] ?? FormaPagamentoSefaz.dinheiro,
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      bandeiraCartao: json['bandeiraCartao'],
      autorizacaoCartao: json['autorizacaoCartao'],
    );
  }
}
