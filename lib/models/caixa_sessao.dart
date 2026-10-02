import '../core/constants/pdv_constants.dart';
import 'movimentacao_caixa.dart';
import 'venda_pdv.dart';

class CaixaSessao {
  final int caixaNumero;
  final int operadorId;
  final String operadorNome;
  final DateTime dataAbertura;
  DateTime? dataFechamento;
  final double fundoTrocoInicial;
  final List<MovimentacaoCaixa> movimentacoes;
  final List<VendaPdv> vendas;
  StatusCaixa status;

  CaixaSessao({
    required this.caixaNumero,
    required this.operadorId,
    required this.operadorNome,
    required this.dataAbertura,
    this.dataFechamento,
    required this.fundoTrocoInicial,
    List<MovimentacaoCaixa>? movimentacoes,
    List<VendaPdv>? vendas,
    this.status = StatusCaixa.aberto,
  })  : movimentacoes = movimentacoes ?? [],
        vendas = vendas ?? [];

  List<VendaPdv> get vendasFinalizadas =>
      vendas.where((v) => v.status == 'FINALIZADA').toList();

  List<VendaPdv> get vendasCanceladas =>
      vendas.where((v) => v.status == 'CANCELADA').toList();

  double get totalVendasBruto =>
      vendasFinalizadas.fold(0.0, (acc, v) => acc + v.totalLiquido);

  double get totalSangrias => movimentacoes
      .where((m) => m.tipo == TipoMovimentacaoCaixa.sangria)
      .fold(0.0, (acc, m) => acc + m.valor);

  double get totalSuprimentos => movimentacoes
      .where((m) => m.tipo == TipoMovimentacaoCaixa.suprimento)
      .fold(0.0, (acc, m) => acc + m.valor);

  // Totais por forma de pagamento
  double totalPorForma(String codigoSefaz) {
    double total = 0.0;
    for (final venda in vendasFinalizadas) {
      for (final pag in venda.pagamentos) {
        if (pag.codigoSefaz == codigoSefaz) {
          total += pag.valor;
        }
      }
    }
    return total;
  }

  // Dinheiro total em caixa esperado
  double get saldoDinheiroEsperado {
    final dinheiroVendas = totalPorForma(FormaPagamentoSefaz.dinheiro);
    return fundoTrocoInicial + totalSuprimentos + dinheiroVendas - totalSangrias;
  }
}
