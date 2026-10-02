import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AberturaCaixaDialog extends StatefulWidget {
  final int caixaNumero;
  final String operadorNome;

  const AberturaCaixaDialog({
    super.key,
    required this.caixaNumero,
    required this.operadorNome,
  });

  static Future<double?> show(
    BuildContext context, {
    required int caixaNumero,
    required String operadorNome,
  }) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AberturaCaixaDialog(
        caixaNumero: caixaNumero,
        operadorNome: operadorNome,
      ),
    );
  }

  @override
  State<AberturaCaixaDialog> createState() => _AberturaCaixaDialogState();
}

class _AberturaCaixaDialogState extends State<AberturaCaixaDialog> {
  final _fundoCtrl = TextEditingController(text: '100,00');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _fundoCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    final valor = double.parse(_fundoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PdvColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                        color: PdvColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.lock_open, color: PdvColors.primary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ABERTURA DE CAIXA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: PdvColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Caixa Nº ${widget.caixaNumero} | Operador: ${widget.operadorNome}',
                            style: const TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Informe o valor do fundo de troco inicial para abertura da gaveta:',
                  style: TextStyle(fontSize: 12, color: PdvColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fundoCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Fundo de Troco Inicial (R\$)',
                    prefixIcon: Icon(Icons.attach_money, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o valor';
                    final numVal = double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));
                    if (numVal == null || numVal < 0) return 'Valor inválido';
                    return null;
                  },
                  onFieldSubmitted: (_) => _confirmar(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _confirmar,
                  child: const Text('ABRIR CAIXA E INICIAR VENDAS (ENTER)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
