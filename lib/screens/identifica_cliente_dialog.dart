import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class IdentificaClienteDialog extends StatefulWidget {
  final String? cpfAtual;
  final String? nomeAtual;

  const IdentificaClienteDialog({
    super.key,
    this.cpfAtual,
    this.nomeAtual,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    String? cpfAtual,
    String? nomeAtual,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => IdentificaClienteDialog(
        cpfAtual: cpfAtual,
        nomeAtual: nomeAtual,
      ),
    );
  }

  @override
  State<IdentificaClienteDialog> createState() => _IdentificaClienteDialogState();
}

class _IdentificaClienteDialogState extends State<IdentificaClienteDialog> {
  late final TextEditingController _cpfCtrl;
  late final TextEditingController _nomeCtrl;

  @override
  void initState() {
    super.initState();
    _cpfCtrl = TextEditingController(text: widget.cpfAtual ?? '');
    _nomeCtrl = TextEditingController(text: widget.nomeAtual ?? '');
  }

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _nomeCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    Navigator.of(context).pop({
      'cpfCnpj': _cpfCtrl.text.trim(),
      'nome': _nomeCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PdvColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
                      color: PdvColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.person_pin, color: PdvColors.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IDENTIFICAÇÃO DO CONSUMIDOR',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: PdvColors.textPrimary,
                          ),
                        ),
                        Text(
                          'CPF / CNPJ na Nota Fiscal (NFC-e)',
                          style: TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cpfCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'CPF ou CNPJ do Cliente',
                  hintText: 'Digite apenas números',
                  prefixIcon: Icon(Icons.badge, size: 20),
                ),
                onSubmitted: (_) => _confirmar(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do Cliente (Opcional)',
                  prefixIcon: Icon(Icons.person, size: 20),
                ),
                onSubmitted: (_) => _confirmar(),
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
                      onPressed: _confirmar,
                      child: const Text('CONFIRMAR (ENTER)'),
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
}
