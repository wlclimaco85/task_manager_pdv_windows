import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';

class GerenteAuthDialog extends StatefulWidget {
  final String tituloOperacao;
  final String? detalhesOperacao;

  const GerenteAuthDialog({
    super.key,
    required this.tituloOperacao,
    this.detalhesOperacao,
  });

  static Future<Map<String, dynamic>?> solicitarAutorizacao(
    BuildContext context, {
    required String operacao,
    String? detalhes,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GerenteAuthDialog(
        tituloOperacao: operacao,
        detalhesOperacao: detalhes,
      ),
    );
  }

  @override
  State<GerenteAuthDialog> createState() => _GerenteAuthDialogState();
}

class _GerenteAuthDialogState extends State<GerenteAuthDialog> {
  final _usuarioCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  bool _validando = false;
  String? _erro;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _senhaCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _autorizar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _validando = true;
      _erro = null;
    });

    final usuario = _usuarioCtrl.text.trim();
    final senha = _senhaCtrl.text.trim();
    final motivo = _motivoCtrl.text.trim();

    final ok = await _api.validarGerente(usuario, senha);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop({
        'autorizado': true,
        'gerenteNome': usuario.toUpperCase(),
        'motivo': motivo.isNotEmpty ? motivo : 'Autorização de rotina',
      });
    } else {
      setState(() {
        _validando = false;
        _erro = 'Credenciais de Gerente/Supervisor inválidas ou sem alçada';
      });
    }
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
                        color: PdvColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.security, color: PdvColors.warning, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AUTORIZAÇÃO DE GERENTE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: PdvColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.tituloOperacao,
                            style: const TextStyle(
                              fontSize: 12,
                              color: PdvColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.detalhesOperacao != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PdvColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.detalhesOperacao!,
                      style: const TextStyle(fontSize: 11, color: PdvColors.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usuarioCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Usuário do Gerente',
                    prefixIcon: Icon(Icons.person, size: 20),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o usuário' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha ou PIN do Gerente',
                    prefixIcon: Icon(Icons.lock, size: 20),
                  ),
                  onFieldSubmitted: (_) => _autorizar(),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe a senha' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Justificativa',
                    prefixIcon: Icon(Icons.edit_note, size: 20),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PdvColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _erro!,
                      style: const TextStyle(color: PdvColors.error, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _validando ? null : () => Navigator.of(context).pop(),
                        child: const Text('CANCELAR (ESC)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: PdvColors.warning),
                        onPressed: _validando ? null : _autorizar,
                        child: _validando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('LIBERAR (ENTER)'),
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
