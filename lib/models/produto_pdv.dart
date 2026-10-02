class ProdutoPdv {
  final int id;
  final String codigoBarras; // EAN-13, EAN-8, etc.
  final String codigoInterno;
  final String nome;
  final double precoVenda;
  final String unidade; // UN, KG, LT, CX
  final String ncm;
  final String cfop;
  final String? fotoUrl;
  final bool pesadoBalanca;

  ProdutoPdv({
    required this.id,
    required this.codigoBarras,
    required this.codigoInterno,
    required this.nome,
    required this.precoVenda,
    this.unidade = 'UN',
    required this.ncm,
    this.cfop = '5102',
    this.fotoUrl,
    this.pesadoBalanca = false,
  });

  factory ProdutoPdv.fromJson(Map<String, dynamic> json) {
    return ProdutoPdv(
      id: json['id'] ?? json['codproduto'] ?? 0,
      codigoBarras: json['codigoBarras'] ?? json['gtin'] ?? json['ean'] ?? '',
      codigoInterno: json['codigoInterno'] ?? json['id']?.toString() ?? '',
      nome: json['nome'] ?? json['descricao'] ?? '',
      precoVenda: (json['precoVenda'] ?? json['valor'] ?? json['preco'] as num?)?.toDouble() ?? 0.0,
      unidade: json['unidade'] ?? 'UN',
      ncm: json['ncm'] ?? '00000000',
      cfop: json['cfop'] ?? '5102',
      fotoUrl: json['fotoUrl'] ?? json['imagemUrl'],
      pesadoBalanca: json['pesadoBalanca'] ?? (json['unidade'] == 'KG'),
    );
  }
}
