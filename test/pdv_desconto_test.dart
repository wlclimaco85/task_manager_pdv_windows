import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager_pdv_windows/models/produto_pdv.dart';
import 'package:task_manager_pdv_windows/services/pdv_state_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDV Windows - desconto na venda (F11)', () {
    late PdvStateNotifier notifier;

    setUp(() {
      notifier = PdvStateNotifier();
      notifier.abrirCaixa(
        caixaNumero: 1,
        operadorId: 10,
        operadorNome: 'OPERADOR TESTE',
        fundoTroco: 0,
      );
      notifier.adicionarProduto(
        ProdutoPdv(
          id: 1,
          codigoBarras: '7894900011517',
          codigoInterno: '101',
          nome: 'CAMISETA',
          precoVenda: 100.0,
          ncm: '61091000',
        ),
      );
    });

    test('desconto reduz o total liquido da venda', () {
      notifier.definirDescontoGeral(10);

      expect(notifier.vendaAtual!.descontoGeral, 10.0);
      expect(notifier.vendaAtual!.totalLiquido, 90.0);
    });

    test('desconto maior que o subtotal e limitado ao subtotal', () {
      notifier.definirDescontoGeral(500);

      expect(notifier.vendaAtual!.descontoGeral, 100.0);
      expect(notifier.vendaAtual!.totalLiquido, 0.0);
    });

    test('desconto negativo vira zero', () {
      notifier.definirDescontoGeral(-5);

      expect(notifier.vendaAtual!.descontoGeral, 0.0);
    });
  });
}
