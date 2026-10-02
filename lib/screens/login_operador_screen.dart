import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/pdv_state_notifier.dart';
import 'abertura_caixa_dialog.dart';
import 'pdv_checkout_screen.dart';

class LoginOperadorScreen extends StatefulWidget {
  final PdvStateNotifier notifier;

  const LoginOperadorScreen({super.key, required this.notifier});

  @override
  State<LoginOperadorScreen> createState() => _LoginOperadorScreenState();
}

class _LoginOperadorScreenState extends State<LoginOperadorScreen> {
  final _usuarioCtrl = TextEditingController(text: 'operador');
  final _senhaCtrl = TextEditingController(text: '123456');
  final _caixaCtrl = TextEditingController(text: '1');
  final _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  bool _carregando = false;
  String? _erro;
  bool _mostrarConfigUrl = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = _api.baseUrl;
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _senhaCtrl.dispose();
    _caixaCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    if (_mostrarConfigUrl) {
      await _api.setBaseUrl(_urlCtrl.text);
    }

    final usuario = _usuarioCtrl.text.trim();
    final senha = _senhaCtrl.text.trim();
    final caixaNum = int.tryParse(_caixaCtrl.text) ?? 1;

    final res = await _api.login(usuario, senha);

    if (!mounted) return;

    if (res['sucesso'] == true) {
      final dados = res['dados'] ?? {};
      final operadorNome = dados['nome'] ?? usuario.toUpperCase();
      final operadorId = dados['id'] ?? 1;

      setState(() => _carregando = false);

      // Solicita abertura de caixa se não estiver aberto
      final fundoTroco = await AberturaCaixaDialog.show(
        context,
        caixaNumero: caixaNum,
        operadorNome: operadorNome,
      );

      if (!mounted || fundoTroco == null) return;

      widget.notifier.abrirCaixa(
        caixaNumero: caixaNum,
        operadorId: operadorId,
        operadorNome: operadorNome,
        fundoTroco: fundoTroco,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PdvCheckoutScreen(
            notifier: widget.notifier,
            onCaixaFechado: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LoginOperadorScreen(notifier: widget.notifier),
                ),
              );
            },
          ),
        ),
      );
    } else {
      setState(() {
        _carregando = false;
        _erro = res['mensagem'] ?? 'Falha na autenticação';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PdvColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: PdvColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PdvColors.surfaceLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PdvColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.point_of_sale, size: 48, color: PdvColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'FRENTE DE CAIXA / PDV',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: PdvColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Emissor de Cupom Fiscal Eletrônico NFC-e',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: PdvColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usuarioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Operador / Usuário',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o operador' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senhaCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha de Acesso',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe a senha' : null,
                      onFieldSubmitted: (_) => _entrar(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _caixaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Número do Caixa',
                        prefixIcon: Icon(Icons.desktop_windows),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o número do caixa' : null,
                      onFieldSubmitted: (_) => _entrar(),
                    ),
                    if (_mostrarConfigUrl) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL do Servidor Backend',
                          prefixIcon: Icon(Icons.dns),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _mostrarConfigUrl = !_mostrarConfigUrl),
                        child: Text(
                          _mostrarConfigUrl ? 'Ocultar Servidor' : 'Configurar Servidor',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _carregando ? null : _entrar,
                      child: _carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'ENTRAR NO PDV (ENTER)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
