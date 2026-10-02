import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/caixa_sessao.dart';
import '../services/impressao_service.dart';
import 'gerente_auth_dialog.dart';

class ReducaoZDialog extends StatefulWidget {
  final CaixaSessao sessao;

  const ReducaoZDialog({super.key, required this.sessao});

  static Future<bool?> show(BuildContext context, CaixaSessao sessao) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReducaoZDialog(sessao: sessao),
    );
  }

  @override
  State<ReducaoZDialog> createState() => _ReducaoZDialogState();
}

class _ReducaoZDialogState extends State<ReducaoZDialog> {
  final _dinheiroCtrl = TextEditingController();
  final _cartaoCtrl = TextEditingController();
  final _pixCtrl = TextEditingController();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  bool _conferenciaRealizada = false;
  double _diferencaDinheiro = 0.0;
  String? _gerenteNome;

  @override
  void dispose() {
    _dinheiroCtrl.dispose();
    _cartaoCtrl.dispose();
    _pixCtrl.dispose();
    super.dispose();
  }

  Future<void> _apurarFechamento() async {
    // 1. Exige autorização de Gerente
    final auth = await GerenteAuthDialog.solicitarAutorizacao(
      context,
      operacao: 'REDUÇÃO Z / FECHAMENTO DE CAIXA',
      detalhes: 'Encerramento de turno fiscal do Caixa ${widget.sessao.caixaNumero}',
    );

    if (auth == null || auth['autorizado'] != true) return;

    _gerenteNome = auth['gerenteNome'];

    final dinheiroContado = double.tryParse(_dinheiroCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    final dinheiroEsperado = widget.sessao.saldoDinheiroEsperado;

    setState(() {
      _diferencaDinheiro = dinheiroContado - dinheiroEsperado;
      _conferenciaRealizada = true;
    });
  }

  Future<void> _concluirReducaoZ() async {
    widget.sessao.dataFechamento = DateTime.now();

    // Dispara a impressão física da Redução Z
    await ImpressaoService.imprimirRelatorioFiscal(widget.sessao, isReducaoZ: true);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PdvColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PdvColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.point_of_sale, color: PdvColors.error, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REDUÇÃO Z - FECHAMENTO DE CAIXA [F10]',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: PdvColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Encerramento do turno e bloqueio de novas operações',
                          style: TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: PdvColors.surfaceLight),
              if (!_conferenciaRealizada) ...[
                const Text(
                  'CONFERÊNCIA CEGA (CONTE OS VALORES EM GAVETA):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PdvColors.accent),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dinheiroCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor em Dinheiro / Espécie (R\$)',
                    prefixIcon: Icon(Icons.money, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cartaoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Comprovantes de Cartão (R\$)',
                    prefixIcon: Icon(Icons.credit_card, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pixCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total de Recebimentos PIX (R\$)',
                    prefixIcon: Icon(Icons.qr_code, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('VOLTAR AO PDV (ESC)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: PdvColors.warning),
                        onPressed: _apurarFechamento,
                        child: const Text('AVANÇAR COM GERENTE'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Resultado da apuração
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PdvColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: PdvColors.bobinaBorder),
                  ),
                  child: Column(
                    children: [
                      _linhaResumo('Saldo Esperado (Dinheiro):', _moeda.format(widget.sessao.saldoDinheiroEsperado)),
                      _linhaResumo(
                        'Dinheiro Informado:',
                        _moeda.format(double.tryParse(_dinheiroCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _diferencaDinheiro >= 0 ? 'SOBRA DE CAIXA:' : 'QUEBRA DE CAIXA (FALTA):',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _diferencaDinheiro >= 0 ? PdvColors.success : PdvColors.error,
                            ),
                          ),
                          Text(
                            _moeda.format(_diferencaDinheiro),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _diferencaDinheiro >= 0 ? PdvColors.success : PdvColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Autorizado por: ${_gerenteNome ?? 'GERENTE'}',
                  style: const TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _conferenciaRealizada = false),
                        child: const Text('RECONTAR'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: PdvColors.error),
                        icon: const Icon(Icons.lock, size: 18),
                        label: const Text('ENCERRAR E IMPRIMIR Z'),
                        onPressed: _concluirReducaoZ,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaResumo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: PdvColors.textSecondary)),
          Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PdvColors.textPrimary)),
        ],
      ),
    );
  }
}
