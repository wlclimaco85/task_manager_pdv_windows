import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/caixa_sessao.dart';
import '../services/impressao_service.dart';

class LeituraXDialog extends StatelessWidget {
  final CaixaSessao sessao;

  const LeituraXDialog({super.key, required this.sessao});

  static Future<void> show(BuildContext context, CaixaSessao sessao) {
    return showDialog(
      context: context,
      builder: (_) => LeituraXDialog(sessao: sessao),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dataHora = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Dialog(
      backgroundColor: PdvColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.assessment, color: PdvColors.primary, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEITURA X - CONFERÊNCIA PARCIAL [F9]',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: PdvColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Relatório gerencial de conferência sem encerramento de turno',
                          style: TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24, color: PdvColors.surfaceLight),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _linhaInfo('Caixa:', '${sessao.caixaNumero}'),
                      _linhaInfo('Operador:', sessao.operadorNome),
                      _linhaInfo('Abertura:', dataHora.format(sessao.dataAbertura)),
                      const Divider(height: 16, color: PdvColors.surfaceLight),
                      _linhaInfo('Fundo de Troco Inicial:', moeda.format(sessao.fundoTrocoInicial)),
                      _linhaInfo('Total de Suprimentos (+):', moeda.format(sessao.totalSuprimentos), cor: PdvColors.success),
                      _linhaInfo('Total de Sangrias (-):', moeda.format(sessao.totalSangrias), cor: PdvColors.error),
                      const Divider(height: 16, color: PdvColors.surfaceLight),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'VENDAS POR MEIO DE PAGAMENTO:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PdvColors.accent),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _linhaInfo('Dinheiro:', moeda.format(sessao.totalPorForma('01'))),
                      _linhaInfo('Cartão de Débito:', moeda.format(sessao.totalPorForma('04'))),
                      _linhaInfo('Cartão de Crédito:', moeda.format(sessao.totalPorForma('03'))),
                      _linhaInfo('PIX:', moeda.format(sessao.totalPorForma('17'))),
                      _linhaInfo('Vale Alimentação / Refeição:', moeda.format(sessao.totalPorForma('10') + sessao.totalPorForma('11'))),
                      const Divider(height: 16, color: PdvColors.surfaceLight),
                      _linhaInfo('Total de Vendas Bruto:', moeda.format(sessao.totalVendasBruto), destaque: true),
                      _linhaInfo('Saldo Dinheiro em Gaveta:', moeda.format(sessao.saldoDinheiroEsperado), destaque: true, cor: PdvColors.totalHighlight),
                      const SizedBox(height: 8),
                      _linhaInfo('Cupons Emitidos:', '${sessao.vendasFinalizadas.length}'),
                      _linhaInfo('Cupons Cancelados:', '${sessao.vendasCanceladas.length}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('FECHAR (ESC)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      onPressed: () async {
                        await ImpressaoService.imprimirRelatorioFiscal(sessao, isReducaoZ: false);
                      },
                      label: const Text('IMPRIMIR BOBINA'),
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

  Widget _linhaInfo(String label, String valor, {bool destaque = false, Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: destaque ? 13 : 12,
              fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
              color: PdvColors.textSecondary,
            ),
          ),
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
