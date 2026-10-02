class ItemVenda {
  final int itemNumero;
  final int produtoId;
  final String codigoBarras;
  final String descricao;
  final String ncm;
  final String cfop;
  final String unidade;
  final double quantidade;
  final double valorUnitario;
  final double desconto;
  final double acrescimo;
  final bool cancelado;
  final String? motivoCancelamento;
  final String? gerenteAutorizador;

  ItemVenda({
    required this.itemNumero,
    required this.produtoId,
    required this.codigoBarras,
    required this.descricao,
    required this.ncm,
    this.cfop = '5102',
    this.unidade = 'UN',
    required this.quantidade,
    required this.valorUnitario,
    this.desconto = 0.0,
    this.acrescimo = 0.0,
    this.cancelado = false,
    this.motivoCancelamento,
    this.gerenteAutorizador,
  });

  double get valorBruto => (quantidade * valorUnitario);
  double get valorTotal => (valorBruto - desconto + acrescimo);

  ItemVenda copyWith({
    int? itemNumero,
    int? produtoId,
    String? codigoBarras,
    String? descricao,
    String? ncm,
    String? cfop,
    String? unidade,
    double? quantidade,
    double? valorUnitario,
    double? desconto,
    double? acrescimo,
    bool? cancelado,
    String? motivoCancelamento,
    String? gerenteAutorizador,
  }) {
    return ItemVenda(
      itemNumero: itemNumero ?? this.itemNumero,
      produtoId: produtoId ?? this.produtoId,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      descricao: descricao ?? this.descricao,
      ncm: ncm ?? this.ncm,
      cfop: cfop ?? this.cfop,
      unidade: unidade ?? this.unidade,
      quantidade: quantidade ?? this.quantidade,
      valorUnitario: valorUnitario ?? this.valorUnitario,
      desconto: desconto ?? this.desconto,
      acrescimo: acrescimo ?? this.acrescimo,
      cancelado: cancelado ?? this.cancelado,
      motivoCancelamento: motivoCancelamento ?? this.motivoCancelamento,
      gerenteAutorizador: gerenteAutorizador ?? this.gerenteAutorizador,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemNumero': itemNumero,
      'produtoId': produtoId,
      'codigoBarras': codigoBarras,
      'descricao': descricao,
      'ncm': ncm,
      'cfop': cfop,
      'unidade': unidade,
      'quantidade': quantidade,
      'valorUnitario': valorUnitario,
      'desconto': desconto,
      'acrescimo': acrescimo,
      'valorTotal': valorTotal,
      'cancelado': cancelado,
      'motivoCancelamento': motivoCancelamento,
      'gerenteAutorizador': gerenteAutorizador,
    };
  }

  factory ItemVenda.fromJson(Map<String, dynamic> json) {
    return ItemVenda(
      itemNumero: json['itemNumero'] ?? 1,
      produtoId: json['produtoId'] ?? 0,
      codigoBarras: json['codigoBarras'] ?? '',
      descricao: json['descricao'] ?? '',
      ncm: json['ncm'] ?? '00000000',
      cfop: json['cfop'] ?? '5102',
      unidade: json['unidade'] ?? 'UN',
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 1.0,
      valorUnitario: (json['valorUnitario'] as num?)?.toDouble() ?? 0.0,
      desconto: (json['desconto'] as num?)?.toDouble() ?? 0.0,
      acrescimo: (json['acrescimo'] as num?)?.toDouble() ?? 0.0,
      cancelado: json['cancelado'] ?? false,
      motivoCancelamento: json['motivoCancelamento'],
      gerenteAutorizador: json['gerenteAutorizador'],
    );
  }
}
