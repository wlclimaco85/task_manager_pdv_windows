import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import 'gerente_auth_dialog.dart';

enum ModoOperacaoCaixa {
  sangria,
  suprimento,
}

class OperacoesCaixaDialog extends StatefulWidget {
  final ModoOperacaoCaixa modo;
  final double saldoDinheiroAtual;

  const OperacoesCaixaDialog({
    super.key,
    required this.modo,
    required this.saldoDinheiroAtual,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required ModoOperacaoCaixa modo,
    required double saldoDinheiroAtual,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OperacoesCaixaDialog(
        modo: modo,
        saldoDinheiroAtual: saldoDinheiroAtual,
      ),
    );
  }

  @override
  State<OperacoesCaixaDialog> createState() => _OperacoesCaixaDialogState();
}

class _OperacoesCaixaDialogState extends State<OperacoesCaixaDialog> {
  final _valorCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  bool get isSangria => widget.modo == ModoOperacaoCaixa.sangria;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _processar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = double.parse(_valorCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
    final motivo = _motivoCtrl.text.trim();

    String? gerenteNome;

    // Se for sangria de caixa, é obrigatório passar por alçada de gerente
    if (isSangria) {
      final auth = await GerenteAuthDialog.solicitarAutorizacao(
        context,
        operacao: 'SANGRIA DE CAIXA',
        detalhes: 'Retirada de ${_moeda.format(valor)} para o cofre / tesouraria',
      );

      if (auth == null || auth['autorizado'] != true) return;
      gerenteNome = auth['gerenteNome'];
    }

    if (!mounted) return;

    Navigator.of(context).pop({
      'sucesso': true,
      'valor': valor,
      'motivo': motivo,
      'gerenteNome': gerenteNome,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PdvColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSangria ? PdvColors.error : PdvColors.success).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isSangria ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isSangria ? PdvColors.error : PdvColors.success,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSangria ? 'SANGRIA DE CAIXA [F7]' : 'SUPRIMENTO DE CAIXA [F8]',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: PdvColors.textPrimary,
                            ),
                          ),
                          Text(
                            isSangria
                                ? 'Retirada de dinheiro para cofre/tesouraria'
                                : 'Entrada de reforço de troco',
                            style: const TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PdvColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Saldo atual em gaveta:',
                        style: TextStyle(fontSize: 12, color: PdvColors.textSecondary),
                      ),
                      Text(
                        _moeda.format(widget.saldoDinheiroAtual),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: PdvColors.totalHighlight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    prefixIcon: Icon(Icons.attach_money, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o valor';
                    final numVal = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));
                    if (numVal == null || numVal <= 0) return 'Valor inválido';
                    if (isSangria && numVal > widget.saldoDinheiroAtual) {
                      return 'Valor maior que o saldo em gaveta';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motivoCtrl,
                  decoration: InputDecoration(
                    labelText: isSangria
                        ? 'Motivo (Ex: Recolhimento para cofre)'
                        : 'Motivo (Ex: Troco inicial / Reforço)',
                    prefixIcon: const Icon(Icons.description, size: 20),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o motivo' : null,
                  onFieldSubmitted: (_) => _processar(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCELAR (ESC)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSangria ? PdvColors.error : PdvColors.success,
                        ),
                        onPressed: _processar,
                        child: Text(isSangria ? 'CONFIRMAR SANGRIA' : 'CONFIRMAR SUPRIMENTO'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
