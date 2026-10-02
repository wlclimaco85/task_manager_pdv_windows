class FormaPagamentoSefaz {
  static const String dinheiro = '01';
  static const String cheque = '02';
  static const String cartaoCredito = '03';
  static const String cartaoDebito = '04';
  static const String creditoLoja = '05';
  static const String valeAlimentacao = '10';
  static const String valeRefeicao = '11';
  static const String valePresente = '12';
  static const String valeCombustivel = '13';
  static const String duplicataMercantil = '14';
  static const String boletoBancario = '15';
  static const String depositoBancario = '16';
  static const String pix = '17';
  static const String transferencia = '18';
  static const String programaFidelidade = '19';
  static const String semPagamento = '90';
  static const String outros = '99';

  static String getDescricao(String codigo) {
    switch (codigo) {
      case dinheiro:
        return 'Dinheiro';
      case cheque:
        return 'Cheque';
      case cartaoCredito:
        return 'Cartão de Crédito';
      case cartaoDebito:
        return 'Cartão de Débito';
      case creditoLoja:
        return 'Crédito Loja';
      case valeAlimentacao:
        return 'Vale Alimentação';
      case valeRefeicao:
        return 'Vale Refeição';
      case pix:
        return 'PIX';
      case outros:
      default:
        return 'Outros';
    }
  }
}

enum StatusCaixa {
  fechado,
  aberto,
  ocupado,
  bloqueado,
}

enum StatusSefaz {
  online,
  contingencia,
  offline,
}
