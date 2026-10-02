import 'item_venda.dart';
import 'pagamento_item.dart';

class VendaPdv {
  final String id; // UUID local da venda
  final int numeroCupom;
  final DateTime dataHora;
  final int caixaNumero;
  final int operadorId;
  final String operadorNome;
  final String? cpfCnpjCliente;
  final String? nomeCliente;
  final List<ItemVenda> itens;
  final List<PagamentoItem> pagamentos;
  final double descontoGeral;
  final double troco;
  final String status; // 'EM_ANDAMENTO', 'FINALIZADA', 'CANCELADA'
  final String? chaveAcessoNfce;
  final String? protocoloNfce;
  final String? qrCodeNfce;
  final bool contingencia;
  final String? motivoCancelamento;
  final String? gerenteCancelamento;

  VendaPdv({
    required this.id,
    required this.numeroCupom,
    required this.dataHora,
    required this.caixaNumero,
    required this.operadorId,
    required this.operadorNome,
    this.cpfCnpjCliente,
    this.nomeCliente,
    required this.itens,
    required this.pagamentos,
    this.descontoGeral = 0.0,
    this.troco = 0.0,
    this.status = 'EM_ANDAMENTO',
    this.chaveAcessoNfce,
    this.protocoloNfce,
    this.qrCodeNfce,
    this.contingencia = false,
    this.motivoCancelamento,
    this.gerenteCancelamento,
  });

  List<ItemVenda> get itensAtivos => itens.where((i) => !i.cancelado).toList();

  double get subtotal =>
      itensAtivos.fold(0.0, (acc, item) => acc + item.valorTotal);

  double get totalLiquido => (subtotal - descontoGeral);

  double get totalPago =>
      pagamentos.fold(0.0, (acc, pag) => acc + pag.valor);

  double get saldoRestante =>
      (totalLiquido - totalPago) > 0 ? (totalLiquido - totalPago) : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numeroCupom': numeroCupom,
      'dataHora': dataHora.toIso8601String(),
      'caixaNumero': caixaNumero,
      'operadorId': operadorId,
      'operadorNome': operadorNome,
      'cpfCnpjCliente': cpfCnpjCliente,
      'nomeCliente': nomeCliente,
      'itens': itens.map((i) => i.toJson()).toList(),
      'pagamentos': pagamentos.map((p) => p.toJson()).toList(),
      'descontoGeral': descontoGeral,
      'troco': troco,
      'status': status,
      'chaveAcessoNfce': chaveAcessoNfce,
      'protocoloNfce': protocoloNfce,
      'qrCodeNfce': qrCodeNfce,
      'contingencia': contingencia,
      'motivoCancelamento': motivoCancelamento,
      'gerenteCancelamento': gerenteCancelamento,
    };
  }
}
