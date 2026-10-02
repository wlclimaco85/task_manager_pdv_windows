import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/pdv_constants.dart';
import '../core/theme/app_theme.dart';
import '../services/pdv_state_notifier.dart';

class PdvPagamentoDialog extends StatefulWidget {
  final PdvStateNotifier notifier;

  const PdvPagamentoDialog({super.key, required this.notifier});

  static Future<bool?> show(BuildContext context, PdvStateNotifier notifier) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PdvPagamentoDialog(notifier: notifier),
    );
  }

  @override
  State<PdvPagamentoDialog> createState() => _PdvPagamentoDialogState();
}

class _PdvPagamentoDialogState extends State<PdvPagamentoDialog> {
  final _valorCtrl = TextEditingController();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String _formaSelecionada = FormaPagamentoSefaz.dinheiro;
  bool _emitindo = false;
  String? _erroEmissao;

  @override
  void initState() {
    super.initState();
    // Sugere o saldo restante no campo de valor
    final saldo = widget.notifier.vendaAtual?.saldoRestante ?? 0.0;
    _valorCtrl.text = saldo > 0 ? saldo.toStringAsFixed(2).replaceAll('.', ',') : '';
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  void _adicionarPagamento() {
    final valor = double.tryParse(_valorCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    if (valor <= 0) return;

    widget.notifier.adicionarPagamento(_formaSelecionada, valor);

    setState(() {
      final novoSaldo = widget.notifier.vendaAtual?.saldoRestante ?? 0.0;
      _valorCtrl.text = novoSaldo > 0 ? novoSaldo.toStringAsFixed(2).replaceAll('.', ',') : '';
    });
  }

  Future<void> _concluirVenda() async {
    final venda = widget.notifier.vendaAtual;
    if (venda == null || venda.saldoRestante > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ainda há saldo restante a pagar!'), backgroundColor: PdvColors.error),
      );
      return;
    }

    setState(() {
      _emitindo = true;
      _erroEmissao = null;
    });

    final res = await widget.notifier.finalizarVendaEmitirNfce();

    if (!mounted) return;

    if (res['sucesso'] == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _emitindo = false;
        _erroEmissao = res['mensagem'] ?? 'Falha na emissão da NFC-e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final venda = widget.notifier.vendaAtual;
    if (venda == null) return const SizedBox();

    final totalLiquido = venda.totalLiquido;
    final totalPago = venda.totalPago;
    final saldoRestante = venda.saldoRestante;
    final troco = (totalPago - totalLiquido) > 0 ? (totalPago - totalLiquido) : 0.0;
    final prontoParaEmitir = saldoRestante <= 0 && totalPago >= totalLiquido;

    return Dialog(
      backgroundColor: PdvColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PdvColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.point_of_sale, color: PdvColors.success, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FINALIZAÇÃO DE VENDA & PAGAMENTO [F12 / ENTER]',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: PdvColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Cupom NFC-e Nº ${venda.numeroCupom} | ${venda.itensAtivos.length} itens',
                          style: const TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _emitindo ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 24, color: PdvColors.surfaceLight),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coluna esquerda: Formas de pagamento
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'SELECIONE O MEIO DE PAGAMENTO:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PdvColors.accent),
                          ),
                          const SizedBox(height: 8),
                          _btnForma('1 - Dinheiro', FormaPagamentoSefaz.dinheiro, Icons.money),
                          _btnForma('2 - Cartão de Débito', FormaPagamentoSefaz.cartaoDebito, Icons.credit_card),
                          _btnForma('3 - Cartão de Crédito', FormaPagamentoSefaz.cartaoCredito, Icons.credit_score),
                          _btnForma('4 - PIX', FormaPagamentoSefaz.pix, Icons.qr_code_2),
                          _btnForma('5 - Vale Alimentação / Refeição', FormaPagamentoSefaz.valeAlimentacao, Icons.restaurant),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _valorCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Valor a Pagar (R\$)',
                                    prefixIcon: Icon(Icons.attach_money, size: 20),
                                  ),
                                  onSubmitted: (_) => _adicionarPagamento(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _adicionarPagamento,
                                child: const Text('+ ADICIONAR'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    const VerticalDivider(width: 1, color: PdvColors.surfaceLight),
                    const SizedBox(width: 20),
                    // Coluna direita: Resumo, pagamentos lançados e troco
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PdvColors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                _linhaResumo('TOTAL DA VENDA:', _moeda.format(totalLiquido), destaque: true),
                                _linhaResumo('TOTAL JÁ PAGO:', _moeda.format(totalPago)),
                                const Divider(height: 12),
                                _linhaResumo(
                                  'SALDO RESTANTE:',
                                  _moeda.format(saldoRestante),
                                  destaque: true,
                                  cor: saldoRestante > 0 ? PdvColors.error : PdvColors.textSecondary,
                                ),
                                if (troco > 0)
                                  _linhaResumo(
                                    'TROCO A DEVOLVER:',
                                    _moeda.format(troco),
                                    destaque: true,
                                    cor: PdvColors.totalHighlight,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'PAGAMENTOS REGISTRADOS:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PdvColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: venda.pagamentos.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Nenhum pagamento adicionado',
                                      style: TextStyle(fontSize: 11, color: PdvColors.textMuted),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: venda.pagamentos.length,
                                    itemBuilder: (context, idx) {
                                      final p = venda.pagamentos[idx];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: PdvColors.surfaceDark,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(p.descricao, style: const TextStyle(fontSize: 12)),
                                            ),
                                            Text(
                                              _moeda.format(p.valor),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => widget.notifier.removerPagamento(idx),
                                              child: const Icon(Icons.delete_outline, size: 16, color: PdvColors.error),
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
                  ],
                ),
              ),
              if (_erroEmissao != null) ...[
                const SizedBox(height: 8),
                Text(
                  _erroEmissao!,
                  style: const TextStyle(color: PdvColors.error, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _emitindo ? null : () => Navigator.of(context).pop(false),
                      child: const Text('VOLTAR AO CUPOM (ESC)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: prontoParaEmitir ? PdvColors.success : PdvColors.surfaceLight,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _emitindo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle, size: 20),
                      label: Text(
                        _emitindo ? 'EMITINDO NFC-e NA SEFAZ...' : 'EMITIR NFC-e E FINALIZAR (ENTER)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: (_emitindo || !prontoParaEmitir) ? null : _concluirVenda,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btnForma(String label, String codigo, IconData icon) {
    final isSelected = _formaSelecionada == codigo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => setState(() => _formaSelecionada = codigo),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? PdvColors.primary.withValues(alpha: 0.2) : PdvColors.surfaceDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? PdvColors.primary : PdvColors.surfaceLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? PdvColors.primary : PdvColors.textSecondary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? PdvColors.textPrimary : PdvColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaResumo(String label, String valor, {bool destaque = false, Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: destaque ? 13 : 11, fontWeight: destaque ? FontWeight.bold : FontWeight.normal)),
          Text(
            valor,
            style: TextStyle(
              fontSize: destaque ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: cor ?? PdvColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
