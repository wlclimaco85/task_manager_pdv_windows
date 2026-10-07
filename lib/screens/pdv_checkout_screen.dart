import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/constants/pdv_constants.dart';
import '../core/theme/app_theme.dart';
import '../services/pdv_state_notifier.dart';
import 'busca_produto_dialog.dart';
import 'gerente_auth_dialog.dart';
import 'identifica_cliente_dialog.dart';
import 'leitura_x_dialog.dart';
import 'operacoes_caixa_dialog.dart';
import 'pdv_pagamento_dialog.dart';
import 'reducao_z_dialog.dart';

class PdvCheckoutScreen extends StatefulWidget {
  final PdvStateNotifier notifier;
  final VoidCallback onCaixaFechado;

  const PdvCheckoutScreen({
    super.key,
    required this.notifier,
    required this.onCaixaFechado,
  });

  @override
  State<PdvCheckoutScreen> createState() => _PdvCheckoutScreenState();
}

class _PdvCheckoutScreenState extends State<PdvCheckoutScreen> {
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  Timer? _relogioTimer;
  DateTime _agora = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onStateChange);
    widget.notifier.iniciarSincronizacaoAutomatica();
    _relogioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _agora = DateTime.now());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _garantirFocoInput();
    });
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onStateChange);
    _relogioTimer?.cancel();
    _inputCtrl.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});
    // Rola a bobina automaticamente para o final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _garantirFocoInput() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  // ─── PROCESSAMENTO DO INPUT DO LEITOR / TECLADO ───────────

  Future<void> _processarEntrada() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty) {
      // Se der Enter com o campo vazio e houver itens, vai direto para pagamento!
      if (widget.notifier.temVendaEmAndamento) {
        _abrirPagamento();
      }
      return;
    }

    _inputCtrl.clear();
    await widget.notifier.biparCodigo(texto);
    _garantirFocoInput();
  }

  // ─── ATALHOS GLOBAIS DE TECLADO (F1 A F12) ───────────────────

  void _tratarTeclasGlobais(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.f1) {
      _mostrarAjudaAtalhos();
    } else if (key == LogicalKeyboardKey.f2) {
      _abrirBuscaProdutos();
    } else if (key == LogicalKeyboardKey.f3) {
      _abrirIdentificaCliente();
    } else if (key == LogicalKeyboardKey.f4) {
      _abrirDefinirQuantidade();
    } else if (key == LogicalKeyboardKey.f5) {
      _cancelarItemDialog();
    } else if (key == LogicalKeyboardKey.f6) {
      _cancelarVendaDialog();
    } else if (key == LogicalKeyboardKey.f7) {
      _abrirSangria();
    } else if (key == LogicalKeyboardKey.f8) {
      _abrirSuprimento();
    } else if (key == LogicalKeyboardKey.f9) {
      _abrirLeituraX();
    } else if (key == LogicalKeyboardKey.f10) {
      _abrirReducaoZ();
    } else if (key == LogicalKeyboardKey.f12) {
      _abrirPagamento();
    }
  }

  // ─── AÇÕES DE ATALHO ──────────────────────────────────────────

  Future<void> _abrirBuscaProdutos() async {
    final produto = await BuscaProdutoDialog.show(context);
    if (produto != null) {
      widget.notifier.adicionarProduto(produto);
    }
    _garantirFocoInput();
  }

  Future<void> _abrirIdentificaCliente() async {
    final venda = widget.notifier.vendaAtual;
    final dados = await IdentificaClienteDialog.show(
      context,
      cpfAtual: venda?.cpfCnpjCliente,
      nomeAtual: venda?.nomeCliente,
    );
    if (dados != null) {
      widget.notifier.identificarCliente(dados['cpfCnpj'] ?? '', dados['nome']);
    }
    _garantirFocoInput();
  }

  void _abrirDefinirQuantidade() {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '${widget.notifier.quantidadeMultiplicador}');
        return AlertDialog(
          backgroundColor: PdvColors.surface,
          title: const Text('MULTIPLICADOR DE QUANTIDADE [F4]'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantidade para o próximo produto'),
            onSubmitted: (v) {
              final qtd = double.tryParse(v.replaceAll(',', '.')) ?? 1.0;
              widget.notifier.definirMultiplicador(qtd);
              Navigator.of(ctx).pop();
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () {
                final qtd = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 1.0;
                widget.notifier.definirMultiplicador(qtd);
                Navigator.of(ctx).pop();
              },
              child: const Text('DEFINIR'),
            ),
          ],
        );
      },
    ).then((_) => _garantirFocoInput());
  }

  Future<void> _cancelarItemDialog() async {
    final venda = widget.notifier.vendaAtual;
    if (venda == null || venda.itensAtivos.isEmpty) return;

    final itemCtrl = TextEditingController(text: '${venda.itensAtivos.last.itemNumero}');

    final numItem = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PdvColors.surface,
        title: const Text('CANCELAR ITEM [F5]'),
        content: TextField(
          controller: itemCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número do Item a Cancelar',
            hintText: 'Ex: 1, 2, 3...',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PdvColors.error),
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(itemCtrl.text)),
            child: const Text('AVANÇAR'),
          ),
        ],
      ),
    );

    if (numItem == null) {
      _garantirFocoInput();
      return;
    }

    if (!mounted) return;

    // Exige autorização de Gerente
    final auth = await GerenteAuthDialog.solicitarAutorizacao(
      context,
      operacao: 'CANCELAMENTO DE ITEM Nº $numItem',
      detalhes: 'Estorno do item registrado no cupom fiscal atual',
    );

    if (auth != null && auth['autorizado'] == true) {
      widget.notifier.cancelarItem(
        numItem,
        gerenteNome: auth['gerenteNome'],
        motivo: auth['motivo'],
      );
    }

    _garantirFocoInput();
  }

  Future<void> _cancelarVendaDialog() async {
    if (!widget.notifier.temVendaEmAndamento) return;

    final auth = await GerenteAuthDialog.solicitarAutorizacao(
      context,
      operacao: 'CANCELAMENTO DE CUPOM / VENDA COMPLETA [F6]',
      detalhes: 'Cancelamento total do cupom fiscal NFC-e em andamento',
    );

    if (auth != null && auth['autorizado'] == true) {
      widget.notifier.cancelarVenda(
        gerenteNome: auth['gerenteNome'],
        motivo: auth['motivo'],
      );
    }

    _garantirFocoInput();
  }

  Future<void> _abrirSangria() async {
    final sessao = widget.notifier.caixa;
    if (sessao == null) return;

    final res = await OperacoesCaixaDialog.show(
      context,
      modo: ModoOperacaoCaixa.sangria,
      saldoDinheiroAtual: sessao.saldoDinheiroEsperado,
    );

    if (res != null && res['sucesso'] == true) {
      widget.notifier.realizarSangria(
        res['valor'],
        res['motivo'],
        res['gerenteNome'] ?? 'GERENTE',
      );
    }

    _garantirFocoInput();
  }

  Future<void> _abrirSuprimento() async {
    final sessao = widget.notifier.caixa;
    if (sessao == null) return;

    final res = await OperacoesCaixaDialog.show(
      context,
      modo: ModoOperacaoCaixa.suprimento,
      saldoDinheiroAtual: sessao.saldoDinheiroEsperado,
    );

    if (res != null && res['sucesso'] == true) {
      widget.notifier.realizarSuprimento(res['valor'], res['motivo']);
    }

    _garantirFocoInput();
  }

  Future<void> _abrirLeituraX() async {
    final sessao = widget.notifier.caixa;
    if (sessao == null) return;
    await LeituraXDialog.show(context, sessao);
    _garantirFocoInput();
  }

  Future<void> _abrirReducaoZ() async {
    final sessao = widget.notifier.caixa;
    if (sessao == null) return;

    if (widget.notifier.temVendaEmAndamento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancele ou finalize a venda atual antes de fechar o caixa!'),
          backgroundColor: PdvColors.error,
        ),
      );
      return;
    }

    final fechou = await ReducaoZDialog.show(context, sessao);
    if (fechou == true) {
      widget.notifier.fecharCaixaReducaoZ();
      widget.onCaixaFechado();
    } else {
      _garantirFocoInput();
    }
  }

  Future<void> _abrirPagamento() async {
    if (!widget.notifier.temVendaEmAndamento) return;
    await PdvPagamentoDialog.show(context, widget.notifier);
    _garantirFocoInput();
  }

  void _mostrarAjudaAtalhos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PdvColors.surface,
        title: const Text('MANUAL DE ATALHOS DO FRENTE DE CAIXA [F1]'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('[F1]  - Este manual de atalhos'),
            Text('[F2]  - Consultar / Buscar Produto por Nome ou Código'),
            Text('[F3]  - Identificar Cliente (CPF / CNPJ na Nota)'),
            Text('[F4]  - Alterar Multiplicador de Quantidade (ou digite Q*CÓDIGO)'),
            Text('[F5]  - Cancelar Item (com autorização de Gerente)'),
            Text('[F6]  - Cancelar Cupom / Venda Atual (com Gerente)'),
            Text('[F7]  - Sangria de Caixa (Retirada de Dinheiro)'),
            Text('[F8]  - Suprimento de Caixa (Reforço de Troco)'),
            Text('[F9]  - Leitura X (Conferência Parcial do Turno)'),
            Text('[F10] - Redução Z / Fechamento de Caixa'),
            Text('[F12 / ENTER no campo vazio] - Pagamento e Emissão da NFC-e'),
            Text('[ESC] - Cancelar / Fechar diálogos abertos'),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ENTENDIDO')),
        ],
      ),
    ).then((_) => _garantirFocoInput());
  }

  // ─── CONSTRUÇÃO DA TELA ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessao = widget.notifier.caixa;
    final venda = widget.notifier.vendaAtual;
    final ultimo = widget.notifier.ultimoProdutoBipado;
    final horaFormatada = DateFormat('dd/MM/yyyy HH:mm:ss').format(_agora);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _tratarTeclasGlobais,
      child: Scaffold(
        body: Column(
          children: [
            // ─── 1. CABEÇALHO SUPERIOR (STATUS, CAIXA, SEFAZ, HORA) ───
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: PdvColors.surfaceDark,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: PdvColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.store, color: PdvColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'MERCADO & CONVENIÊNCIA APP ACADEMIA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: PdvColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _badgeStatus(
                    label: widget.notifier.pendentesEnvio > 0
                        ? 'PENDENTES NFC-e: ${widget.notifier.pendentesEnvio}'
                        : widget.notifier.statusSefaz == StatusSefaz.online
                            ? 'SEFAZ ONLINE'
                            : 'SEFAZ CONTINGÊNCIA',
                    cor: widget.notifier.pendentesEnvio == 0 &&
                            widget.notifier.statusSefaz == StatusSefaz.online
                        ? PdvColors.success
                        : PdvColors.warning,
                    icone: Icons.cloud_done,
                  ),
                  const SizedBox(width: 12),
                  _badgeStatus(
                    label: 'CAIXA ${sessao?.caixaNumero ?? 1}',
                    cor: PdvColors.accent,
                    icone: Icons.desktop_windows,
                  ),
                  const SizedBox(width: 12),
                  _badgeStatus(
                    label: 'OP: ${sessao?.operadorNome ?? 'OPERADOR'}',
                    cor: PdvColors.primary,
                    icone: Icons.person,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    horaFormatada,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: PdvColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // ─── 2. ÁREA CENTRAL (BOBINA + DISPLAY PRODUTO + TOTAL) ───
            Expanded(
              child: Row(
                children: [
                  // Painel Esquerdo: Bobina Fiscal Virtual
                  Expanded(
                    flex: 6,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PdvColors.bobinaBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PdvColors.bobinaBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            color: PdvColors.surface,
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long, size: 18, color: PdvColors.accent),
                                const SizedBox(width: 8),
                                Text(
                                  'CUPOM FISCAL ELETRÔNICO (Venda Nº ${venda?.numeroCupom ?? 0})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: PdvColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                if (venda?.cpfCnpjCliente != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: PdvColors.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'CPF: ${venda!.cpfCnpjCliente}',
                                      style: const TextStyle(fontSize: 11, color: PdvColors.primary),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Cabeçalho das colunas do cupom
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: PdvColors.surfaceDark,
                            child: const Row(
                              children: [
                                SizedBox(width: 32, child: Text('ITEM', style: TextStyle(fontSize: 10, color: PdvColors.textMuted))),
                                SizedBox(width: 100, child: Text('CÓDIGO/EAN', style: TextStyle(fontSize: 10, color: PdvColors.textMuted))),
                                Expanded(child: Text('DESCRIÇÃO DO PRODUTO', style: TextStyle(fontSize: 10, color: PdvColors.textMuted))),
                                SizedBox(width: 80, child: Text('QTD x UNIT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: PdvColors.textMuted))),
                                SizedBox(width: 90, child: Text('TOTAL (R\$)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: PdvColors.textMuted))),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: PdvColors.bobinaBorder),
                          Expanded(
                            child: (venda == null || venda.itens.isEmpty)
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.qr_code_scanner, size: 48, color: PdvColors.textMuted),
                                        SizedBox(height: 8),
                                        Text(
                                          'CAIXA LIVRE\nPasse o leitor ou digite o código do produto',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: PdvColors.textMuted, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    itemCount: venda.itens.length,
                                    itemBuilder: (context, idx) {
                                      final item = venda.itens[idx];
                                      final isEven = idx % 2 == 0;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        color: item.cancelado
                                            ? PdvColors.cancelled
                                            : (isEven ? PdvColors.bobinaRowEven : PdvColors.bobinaRowOdd),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 32,
                                              child: Text(
                                                item.itemNumero.toString().padLeft(2, '0'),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: item.cancelado ? TextDecoration.lineThrough : null,
                                                  color: item.cancelado ? PdvColors.error : PdvColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                item.codigoBarras,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  decoration: item.cancelado ? TextDecoration.lineThrough : null,
                                                  color: item.cancelado ? PdvColors.error : PdvColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                item.descricao + (item.cancelado ? ' [CANCELADO]' : ''),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  decoration: item.cancelado ? TextDecoration.lineThrough : null,
                                                  color: item.cancelado ? PdvColors.error : PdvColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                '${item.quantidade.toStringAsFixed(item.unidade == 'KG' ? 3 : 0)} x ${_moeda.format(item.valorUnitario).replaceAll('R\$', '')}',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  decoration: item.cancelado ? TextDecoration.lineThrough : null,
                                                  color: item.cancelado ? PdvColors.error : PdvColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                _moeda.format(item.valorTotal),
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: item.cancelado ? TextDecoration.lineThrough : null,
                                                  color: item.cancelado ? PdvColors.error : PdvColors.totalHighlight,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Painel Direito: Último Produto, Display Gigante do Total e Entrada
                  Expanded(
                    flex: 5,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card do Último Produto
                          Container(
                            height: 180,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: PdvColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PdvColors.bobinaBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 140,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: PdvColors.surfaceDark,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag,
                                    size: 64,
                                    color: PdvColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        ultimo?.nome ?? 'NENHUM ITEM BIPADO',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: PdvColors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Cód: ${ultimo?.codigoBarras ?? '---'}',
                                        style: const TextStyle(fontSize: 12, color: PdvColors.textMuted),
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('VALOR UNITÁRIO', style: TextStyle(fontSize: 10, color: PdvColors.textMuted)),
                                              Text(
                                                _moeda.format(ultimo?.precoVenda ?? 0.0),
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: PdvColors.textPrimary),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('QUANTIDADE', style: TextStyle(fontSize: 10, color: PdvColors.textMuted)),
                                              Text(
                                                '${widget.notifier.quantidadeMultiplicador.toStringAsFixed(0)} UN',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: PdvColors.accent),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Display Gigante do TOTAL A PAGAR
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: PdvColors.surfaceDark,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: PdvColors.totalHighlight, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'SUBTOTAL:',
                                        style: TextStyle(fontSize: 14, color: PdvColors.textSecondary),
                                      ),
                                      Text(
                                        _moeda.format(venda?.subtotal ?? 0.0),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PdvColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(color: PdvColors.surfaceLight),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'TOTAL A PAGAR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: PdvColors.textPrimary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _moeda.format(venda?.totalLiquido ?? 0.0),
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: PdvColors.totalHighlight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Campo de Entrada com foco constante (Leitor / Digitação)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: PdvColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PdvColors.primary, width: 2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.qr_code_scanner, color: PdvColors.primary, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _inputCtrl,
                                    focusNode: _focusNode,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      fontFamily: 'monospace',
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Bipe o código de barras ou digite (Ex: 5*789...)',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _processarEntrada(),
                                  ),
                                ),
                                if (widget.notifier.processando)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.notifier.mensagemStatus != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.notifier.mensagemStatus!,
                              style: const TextStyle(color: PdvColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── 3. RODAPÉ DE ATALHOS RÁPIDOS [F1 A F12] ───────────────
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: PdvColors.surfaceDark,
              child: Row(
                children: [
                  _btnAtalho('[F1] Ajuda', PdvColors.surfaceLight, _mostrarAjudaAtalhos),
                  _btnAtalho('[F2] Buscar', PdvColors.primary, _abrirBuscaProdutos),
                  _btnAtalho('[F3] CPF Nota', PdvColors.accent, _abrirIdentificaCliente),
                  _btnAtalho('[F4] Qtd', PdvColors.surfaceLight, _abrirDefinirQuantidade),
                  _btnAtalho('[F5] Cancelar Item', PdvColors.warning, _cancelarItemDialog),
                  _btnAtalho('[F6] Cancelar Cupom', PdvColors.error, _cancelarVendaDialog),
                  _btnAtalho('[F7] Sangria', PdvColors.error, _abrirSangria),
                  _btnAtalho('[F8] Suprimento', PdvColors.success, _abrirSuprimento),
                  _btnAtalho('[F9] Leitura X', PdvColors.primary, _abrirLeituraX),
                  _btnAtalho('[F10] Redução Z', PdvColors.error, _abrirReducaoZ),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PdvColors.totalHighlight,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle, size: 20, color: Colors.black),
                      label: const Text(
                        '[F12 / ENTER] FINALIZAR',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _abrirPagamento,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeStatus({required String label, required Color cor, required IconData icone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor),
          ),
        ],
      ),
    );
  }

  Widget _btnAtalho(String label, Color cor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cor.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor),
            ),
          ),
        ),
      ),
    );
  }
}
