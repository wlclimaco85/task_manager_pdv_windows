import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/produto_pdv.dart';
import '../services/api_service.dart';

class BuscaProdutoDialog extends StatefulWidget {
  const BuscaProdutoDialog({super.key});

  static Future<ProdutoPdv?> show(BuildContext context) {
    return showDialog<ProdutoPdv>(
      context: context,
      builder: (_) => const BuscaProdutoDialog(),
    );
  }

  @override
  State<BuscaProdutoDialog> createState() => _BuscaProdutoDialogState();
}

class _BuscaProdutoDialogState extends State<BuscaProdutoDialog> {
  final _searchCtrl = TextEditingController();
  final _api = ApiService();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  List<ProdutoPdv> _produtos = [];
  bool _buscando = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    setState(() => _buscando = true);
    final res = await _api.buscarProdutosTexto(q);
    if (!mounted) return;
    setState(() {
      _produtos = res;
      _buscando = false;
      _selectedIndex = 0;
    });
  }

  void _selecionarAtual() {
    if (_produtos.isNotEmpty && _selectedIndex >= 0 && _selectedIndex < _produtos.length) {
      Navigator.of(context).pop(_produtos[_selectedIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PdvColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, color: PdvColors.primary, size: 26),
                  const SizedBox(width: 10),
                  const Text(
                    'CONSULTA DE PRODUTOS [F2]',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: PdvColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Digite nome, código interno ou código de barras...',
                  prefixIcon: Icon(Icons.qr_code_scanner, size: 20),
                ),
                onChanged: _buscar,
                onSubmitted: (_) => _selecionarAtual(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buscando
                    ? const Center(child: CircularProgressIndicator())
                    : _produtos.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum produto localizado',
                              style: TextStyle(color: PdvColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _produtos.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: PdvColors.surfaceLight),
                            itemBuilder: (context, index) {
                              final p = _produtos[index];
                              final isSelected = index == _selectedIndex;

                              return InkWell(
                                onTap: () => Navigator.of(context).pop(p),
                                child: Container(
                                  color: isSelected ? PdvColors.primary.withValues(alpha: 0.15) : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: PdvColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          p.codigoInterno,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.nome,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: PdvColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'EAN: ${p.codigoBarras} | NCM: ${p.ncm} | UN: ${p.unidade}',
                                              style: const TextStyle(fontSize: 11, color: PdvColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _moeda.format(p.precoVenda),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: PdvColors.totalHighlight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: pwMainBetween(),
                children: [
                  const Text(
                    'Clique no item ou use [ENTER] para selecionar e [ESC] para fechar',
                    style: TextStyle(fontSize: 11, color: PdvColors.textMuted),
                  ),
                  ElevatedButton(
                    onPressed: _selecionarAtual,
                    child: const Text('ADICIONAR PRODUTO (ENTER)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  MainAxisAlignment pwMainBetween() => MainAxisAlignment.spaceBetween;
}
