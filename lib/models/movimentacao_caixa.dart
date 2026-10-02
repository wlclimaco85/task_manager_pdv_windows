enum TipoMovimentacaoCaixa {
  sangria,
  suprimento,
}

class MovimentacaoCaixa {
  final String id;
  final TipoMovimentacaoCaixa tipo;
  final double valor;
  final String motivo;
  final DateTime dataHora;
  final String operadorNome;
  final String? gerenteAutorizador;

  MovimentacaoCaixa({
    required this.id,
    required this.tipo,
    required this.valor,
    required this.motivo,
    required this.dataHora,
    required this.operadorNome,
    this.gerenteAutorizador,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo == TipoMovimentacaoCaixa.sangria ? 'SANGRIA' : 'SUPRIMENTO',
      'valor': valor,
      'motivo': motivo,
      'dataHora': dataHora.toIso8601String(),
      'operadorNome': operadorNome,
      'gerenteAutorizador': gerenteAutorizador,
    };
  }

  factory MovimentacaoCaixa.fromJson(Map<String, dynamic> json) {
    return MovimentacaoCaixa(
      id: json['id'] ?? '',
      tipo: json['tipo'] == 'SANGRIA'
          ? TipoMovimentacaoCaixa.sangria
          : TipoMovimentacaoCaixa.suprimento,
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo'] ?? '',
      dataHora: json['dataHora'] != null
          ? DateTime.parse(json['dataHora'])
          : DateTime.now(),
      operadorNome: json['operadorNome'] ?? '',
      gerenteAutorizador: json['gerenteAutorizador'],
    );
  }
}
