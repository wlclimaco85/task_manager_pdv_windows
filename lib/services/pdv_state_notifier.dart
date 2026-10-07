import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/pdv_constants.dart';
import '../models/caixa_sessao.dart';
import '../models/item_venda.dart';
import '../models/movimentacao_caixa.dart';
import '../models/pagamento_item.dart';
import '../models/produto_pdv.dart';
import '../models/venda_pdv.dart';
import 'api_service.dart';
import 'impressao_service.dart';

class PdvStateNotifier extends ChangeNotifier {
  final ApiService _api = ApiService();

  CaixaSessao? _caixa;
  VendaPdv? _vendaAtual;
  ProdutoPdv? _ultimoProdutoBipado;
  double _quantidadeMultiplicador = 1.0;
  bool _processando = false;
  String? _mensagemStatus;
  StatusSefaz _statusSefaz = StatusSefaz.online;
  int _contadorCupom = 1001;
  int _pendentesEnvio = 0;
  Timer? _timerSincronizacao;
  String? _ultimoAvisoFila;
  static const Duration _intervaloSincronizacao = Duration(seconds: 60);

  CaixaSessao? get caixa => _caixa;
  VendaPdv? get vendaAtual => _vendaAtual;
  ProdutoPdv? get ultimoProdutoBipado => _ultimoProdutoBipado;
  double get quantidadeMultiplicador => _quantidadeMultiplicador;
  bool get processando => _processando;
  String? get mensagemStatus => _mensagemStatus;
  StatusSefaz get statusSefaz => _statusSefaz;
  /// Vendas gravadas na fila local aguardando emissão no backend.
  int get pendentesEnvio => _pendentesEnvio;
  String? get ultimoAvisoFila => _ultimoAvisoFila;
  bool get isCaixaAberto => _caixa != null && _caixa!.status == StatusCaixa.aberto;
  bool get temVendaEmAndamento => _vendaAtual != null && _vendaAtual!.itensAtivos.isNotEmpty;

  // ─── CICLO DO CAIXA ──────────────────────────────────────────

  void abrirCaixa({
    required int caixaNumero,
    required int operadorId,
    required String operadorNome,
    required double fundoTroco,
  }) {
    _caixa = CaixaSessao(
      caixaNumero: caixaNumero,
      operadorId: operadorId,
      operadorNome: operadorNome,
      dataAbertura: DateTime.now(),
      fundoTrocoInicial: fundoTroco,
      status: StatusCaixa.aberto,
    );
    _iniciarNovaVenda();
    notifyListeners();
  }

  /// Carrega o contador da fila e tenta enviar pendências periodicamente.
  void iniciarSincronizacaoAutomatica() {
    _timerSincronizacao?.cancel();
    _timerSincronizacao =
        Timer.periodic(_intervaloSincronizacao, (_) => sincronizarFila());
    sincronizarFila();
  }

  Future<void> sincronizarFila() async {
    try {
      final emitidas = await _api.sincronizarPendentes();
      _pendentesEnvio = await _api.contarPendentes();
      if (emitidas > 0) {
        _ultimoAvisoFila = '$emitidas venda(s) pendente(s) emitida(s) com sucesso.';
      }
    } catch (e, st) {
      debugPrint('Falha ao sincronizar fila de NFC-e: $e\n$st');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timerSincronizacao?.cancel();
    super.dispose();
  }

  void fecharCaixaReducaoZ() {
    if (_caixa == null) return;
    _caixa!.status = StatusCaixa.fechado;
    _caixa!.dataFechamento = DateTime.now();
    _vendaAtual = null;
    _ultimoProdutoBipado = null;
    notifyListeners();
  }

  void realizarSangria(double valor, String motivo, String gerenteNome, {bool imprimir = true}) {
    if (_caixa == null) return;
    final mov = MovimentacaoCaixa(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoMovimentacaoCaixa.sangria,
      valor: valor,
      motivo: motivo,
      dataHora: DateTime.now(),
      operadorNome: _caixa!.operadorNome,
      gerenteAutorizador: gerenteNome,
    );
    _caixa!.movimentacoes.add(mov);
    if (imprimir) {
      try {
        ImpressaoService.imprimirMovimentacao(mov, _caixa!.caixaNumero);
      } catch (_) {}
    }
    notifyListeners();
  }

  void realizarSuprimento(double valor, String motivo, {bool imprimir = true}) {
    if (_caixa == null) return;
    final mov = MovimentacaoCaixa(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoMovimentacaoCaixa.suprimento,
      valor: valor,
      motivo: motivo,
      dataHora: DateTime.now(),
      operadorNome: _caixa!.operadorNome,
    );
    _caixa!.movimentacoes.add(mov);
    if (imprimir) {
      try {
        ImpressaoService.imprimirMovimentacao(mov, _caixa!.caixaNumero);
      } catch (_) {}
    }
    notifyListeners();
  }

  // ─── OPERAÇÕES DE VENDA ───────────────────────────────────────

  void _iniciarNovaVenda() {
    if (_caixa == null) return;
    _vendaAtual = VendaPdv(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      numeroCupom: _contadorCupom++,
      dataHora: DateTime.now(),
      caixaNumero: _caixa!.caixaNumero,
      operadorId: _caixa!.operadorId,
      operadorNome: _caixa!.operadorNome,
      itens: [],
      pagamentos: [],
    );
    _ultimoProdutoBipado = null;
    _quantidadeMultiplicador = 1.0;
  }

  void definirMultiplicador(double qtd) {
    _quantidadeMultiplicador = qtd > 0 ? qtd : 1.0;
    notifyListeners();
  }

  /// Processa entrada de código de barras ou multiplicador (ex: '3*7891234567890')
  Future<bool> biparCodigo(String input) async {
    final texto = input.trim();
    if (texto.isEmpty) return false;

    double qtd = _quantidadeMultiplicador;
    String codigo = texto;

    // Suporte ao formato clássico de supermercado 'QTD*CODIGO' (ex: 5*101)
    if (texto.contains('*')) {
      final partes = texto.split('*');
      if (partes.length == 2) {
        final parsedQtd = double.tryParse(partes[0].replaceAll(',', '.'));
        if (parsedQtd != null && parsedQtd > 0) {
          qtd = parsedQtd;
          codigo = partes[1].trim();
        }
      }
    }

    _processando = true;
    notifyListeners();

    try {
      final produto = await _api.buscarPorCodigoBarras(codigo);
      if (produto == null) {
        _mensagemStatus = 'PRODUTO NÃO ENCONTRADO: $codigo';
        _processando = false;
        notifyListeners();
        return false;
      }

      adicionarProduto(produto, quantidade: qtd);
      _quantidadeMultiplicador = 1.0; // reseta para próximo item
      _mensagemStatus = null;
      _processando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _mensagemStatus = 'ERRO AO CONSULTAR: $e';
      _processando = false;
      notifyListeners();
      return false;
    }
  }

  void adicionarProduto(ProdutoPdv produto, {double quantidade = 1.0}) {
    if (_vendaAtual == null) _iniciarNovaVenda();

    final item = ItemVenda(
      itemNumero: _vendaAtual!.itens.length + 1,
      produtoId: produto.id,
      codigoBarras: produto.codigoBarras,
      descricao: produto.nome,
      ncm: produto.ncm,
      cfop: produto.cfop,
      unidade: produto.unidade,
      quantidade: quantidade,
      valorUnitario: produto.precoVenda,
    );

    _vendaAtual!.itens.add(item);
    _ultimoProdutoBipado = produto;
    notifyListeners();
  }

  /// Cancelamento de Item (requer Alçada de Gerente)
  bool cancelarItem(int itemNumero, {required String gerenteNome, required String motivo}) {
    if (_vendaAtual == null) return false;
    final index = _vendaAtual!.itens.indexWhere((i) => i.itemNumero == itemNumero && !i.cancelado);
    if (index == -1) return false;

    final itemOriginal = _vendaAtual!.itens[index];
    _vendaAtual!.itens[index] = itemOriginal.copyWith(
      cancelado: true,
      motivoCancelamento: motivo,
      gerenteAutorizador: gerenteNome,
    );

    notifyListeners();
    return true;
  }

  /// Cancelamento do Cupom / Venda Completa (requer Alçada de Gerente)
  bool cancelarVenda({required String gerenteNome, required String motivo}) {
    if (_vendaAtual == null) return false;

    final vendaCancelada = VendaPdv(
      id: _vendaAtual!.id,
      numeroCupom: _vendaAtual!.numeroCupom,
      dataHora: _vendaAtual!.dataHora,
      caixaNumero: _vendaAtual!.caixaNumero,
      operadorId: _vendaAtual!.operadorId,
      operadorNome: _vendaAtual!.operadorNome,
      cpfCnpjCliente: _vendaAtual!.cpfCnpjCliente,
      nomeCliente: _vendaAtual!.nomeCliente,
      itens: _vendaAtual!.itens.map((i) => i.copyWith(cancelado: true)).toList(),
      pagamentos: _vendaAtual!.pagamentos,
      status: 'CANCELADA',
      motivoCancelamento: motivo,
      gerenteCancelamento: gerenteNome,
    );

    _caixa?.vendas.add(vendaCancelada);
    _iniciarNovaVenda();
    notifyListeners();
    return true;
  }

  void identificarCliente(String cpfCnpj, [String? nome]) {
    if (_vendaAtual == null) _iniciarNovaVenda();
    _vendaAtual = VendaPdv(
      id: _vendaAtual!.id,
      numeroCupom: _vendaAtual!.numeroCupom,
      dataHora: _vendaAtual!.dataHora,
      caixaNumero: _vendaAtual!.caixaNumero,
      operadorId: _vendaAtual!.operadorId,
      operadorNome: _vendaAtual!.operadorNome,
      cpfCnpjCliente: cpfCnpj.trim().isNotEmpty ? cpfCnpj.trim() : null,
      nomeCliente: nome?.trim().isNotEmpty == true ? nome!.trim() : null,
      itens: _vendaAtual!.itens,
      pagamentos: _vendaAtual!.pagamentos,
      descontoGeral: _vendaAtual!.descontoGeral,
    );
    notifyListeners();
  }

  void adicionarPagamento(String codigoSefaz, double valor) {
    if (_vendaAtual == null || valor <= 0) return;
    _vendaAtual!.pagamentos.add(PagamentoItem(codigoSefaz: codigoSefaz, valor: valor));
    notifyListeners();
  }

  void removerPagamento(int index) {
    if (_vendaAtual == null || index < 0 || index >= _vendaAtual!.pagamentos.length) return;
    _vendaAtual!.pagamentos.removeAt(index);
    notifyListeners();
  }

  /// Finalização e Emissão da NFC-e
  Future<Map<String, dynamic>> finalizarVendaEmitirNfce() async {
    if (_vendaAtual == null || _vendaAtual!.itensAtivos.isEmpty) {
      return {'sucesso': false, 'mensagem': 'Não há itens na venda'};
    }

    if (_vendaAtual!.totalPago < _vendaAtual!.totalLiquido) {
      return {
        'sucesso': false,
        'mensagem': 'Valor pago é inferior ao total da venda',
      };
    }

    _processando = true;
    notifyListeners();

    final troco = _vendaAtual!.totalPago - _vendaAtual!.totalLiquido;
    final resNfce = await _api.emitirNfce(_vendaAtual!);

    // Rejeição/erro de validação: NÃO finaliza a venda nem imprime cupom.
    if (resNfce['sucesso'] != true) {
      _processando = false;
      notifyListeners();
      return {
        'sucesso': false,
        'mensagem': resNfce['mensagem'] ?? 'Falha na emissão da NFC-e',
      };
    }

    final vendaFinal = VendaPdv(
      id: _vendaAtual!.id,
      numeroCupom: _vendaAtual!.numeroCupom,
      dataHora: _vendaAtual!.dataHora,
      caixaNumero: _vendaAtual!.caixaNumero,
      operadorId: _vendaAtual!.operadorId,
      operadorNome: _vendaAtual!.operadorNome,
      cpfCnpjCliente: _vendaAtual!.cpfCnpjCliente,
      nomeCliente: _vendaAtual!.nomeCliente,
      itens: _vendaAtual!.itens,
      pagamentos: _vendaAtual!.pagamentos,
      descontoGeral: _vendaAtual!.descontoGeral,
      troco: troco,
      status: 'FINALIZADA',
      chaveAcessoNfce: resNfce['chaveAcesso'],
      protocoloNfce: resNfce['protocolo'],
      qrCodeNfce: resNfce['qrCode'],
      contingencia: resNfce['contingencia'] ?? false,
      pendenteEnvio: resNfce['pendenteEnvio'] ?? false,
      numeroNfce: resNfce['numeroNfce'] as int?,
      serieNfce: resNfce['serieNfce'] as int?,
    );

    _caixa?.vendas.add(vendaFinal);

    // Dispara impressão do cupom térmico DANFE NFC-e
    await ImpressaoService.imprimirDanfeNfce(vendaFinal);

    _statusSefaz = (resNfce['pendenteEnvio'] == true)
        ? StatusSefaz.offline
        : (resNfce['contingencia'] == true)
            ? StatusSefaz.contingencia
            : StatusSefaz.online;
    _pendentesEnvio = await _api.contarPendentes();

    _iniciarNovaVenda();
    _processando = false;
    notifyListeners();

    return {
      'sucesso': true,
      'cupom': vendaFinal.numeroCupom,
      'chaveAcesso': vendaFinal.chaveAcessoNfce,
      'troco': troco,
      'contingencia': vendaFinal.contingencia,
      'pendenteEnvio': vendaFinal.pendenteEnvio,
      'numeroNfce': vendaFinal.numeroNfce,
      'mensagem': resNfce['mensagem'],
    };
  }
}
