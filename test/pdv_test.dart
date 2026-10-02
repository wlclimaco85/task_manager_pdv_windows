import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager_pdv_windows/core/constants/pdv_constants.dart';
import 'package:task_manager_pdv_windows/models/produto_pdv.dart';
import 'package:task_manager_pdv_windows/services/pdv_state_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDV Supermercado NFC-e - Testes de Regra de Negócio e Caixa', () {
    late PdvStateNotifier notifier;

    setUp(() {
      notifier = PdvStateNotifier();
      notifier.abrirCaixa(
        caixaNumero: 1,
        operadorId: 10,
        operadorNome: 'OPERADOR TESTE',
        fundoTroco: 150.0,
      );
    });

    test('1. Abertura de Caixa deve registrar fundo de troco inicial e status aberto', () {
      expect(notifier.isCaixaAberto, isTrue);
      expect(notifier.caixa?.fundoTrocoInicial, equals(150.0));
      expect(notifier.caixa?.saldoDinheiroEsperado, equals(150.0));
    });

    test('2. Adição de itens e cálculo de subtotal com multiplicador', () {
      final coca = ProdutoPdv(
        id: 1,
        codigoBarras: '7894900011517',
        codigoInterno: '101',
        nome: 'COCA-COLA 2L',
        precoVenda: 10.0,
        ncm: '22021000',
      );

      notifier.adicionarProduto(coca, quantidade: 3);

      expect(notifier.temVendaEmAndamento, isTrue);
      expect(notifier.vendaAtual?.itens.length, equals(1));
      expect(notifier.vendaAtual?.subtotal, equals(30.0));
      expect(notifier.vendaAtual?.totalLiquido, equals(30.0));
    });

    test('3. Cancelamento de Item deve exigir justificativa e abater do subtotal', () {
      final item1 = ProdutoPdv(id: 1, codigoBarras: '111', codigoInterno: '1', nome: 'ITEM 1', precoVenda: 20.0, ncm: '00000000');
      final item2 = ProdutoPdv(id: 2, codigoBarras: '222', codigoInterno: '2', nome: 'ITEM 2', precoVenda: 50.0, ncm: '00000000');

      notifier.adicionarProduto(item1);
      notifier.adicionarProduto(item2);

      expect(notifier.vendaAtual?.subtotal, equals(70.0));

      // Cancelar item 1 com alçada de gerente
      final cancelado = notifier.cancelarItem(
        1,
        gerenteNome: 'SUPERVISOR CARLOS',
        motivo: 'Cliente desistiu do item',
      );

      expect(cancelado, isTrue);
      expect(notifier.vendaAtual?.itens.length, equals(2));
      expect(notifier.vendaAtual?.itensAtivos.length, equals(1));
      expect(notifier.vendaAtual?.subtotal, equals(50.0));
      expect(notifier.vendaAtual?.itens.first.cancelado, isTrue);
      expect(notifier.vendaAtual?.itens.first.gerenteAutorizador, equals('SUPERVISOR CARLOS'));
    });

    test('4. Cancelamento de Cupom completo com alçada de gerente', () {
      final item = ProdutoPdv(id: 1, codigoBarras: '111', codigoInterno: '1', nome: 'ITEM 1', precoVenda: 100.0, ncm: '00000000');
      notifier.adicionarProduto(item);

      final cancelou = notifier.cancelarVenda(
        gerenteNome: 'GERENTE SILVA',
        motivo: 'Erro de digitação do operador',
      );

      expect(cancelou, isTrue);
      expect(notifier.caixa?.vendasCanceladas.length, equals(1));
      expect(notifier.caixa?.vendasCanceladas.first.status, equals('CANCELADA'));
      // Novo cupom limpo é iniciado
      expect(notifier.vendaAtual?.itens.isEmpty, isTrue);
    });

    test('5. Pagamento Fracionado (Dinheiro + PIX) e Cálculo Automático de Troco', () {
      final item = ProdutoPdv(id: 1, codigoBarras: '111', codigoInterno: '1', nome: 'COMPRA', precoVenda: 85.0, ncm: '00000000');
      notifier.adicionarProduto(item);

      // Cliente paga R$ 50 no PIX
      notifier.adicionarPagamento(FormaPagamentoSefaz.pix, 50.0);
      expect(notifier.vendaAtual?.saldoRestante, equals(35.0));

      // Cliente dá uma nota de R$ 50 em dinheiro para quitar os R$ 35 restantes
      notifier.adicionarPagamento(FormaPagamentoSefaz.dinheiro, 50.0);
      expect(notifier.vendaAtual?.saldoRestante, equals(0.0));
      expect(notifier.vendaAtual?.totalPago, equals(100.0));

      final troco = notifier.vendaAtual!.totalPago - notifier.vendaAtual!.totalLiquido;
      expect(troco, equals(15.0));
    });

    test('6. Movimentações de Caixa: Suprimento e Sangria com impacto no saldo esperado', () {
      // Saldo inicial: R$ 150,00
      expect(notifier.caixa?.saldoDinheiroEsperado, equals(150.0));

      // Suprimento de reforço: + R$ 100,00
      notifier.realizarSuprimento(100.0, 'Reforço de moedas e notas de 2 reais', imprimir: false);
      expect(notifier.caixa?.totalSuprimentos, equals(100.0));
      expect(notifier.caixa?.saldoDinheiroEsperado, equals(250.0));

      // Sangria para cofre: - R$ 80,00
      notifier.realizarSangria(80.0, 'Recolhimento para cofre por excesso', 'GERENTE ROBERTO', imprimir: false);
      expect(notifier.caixa?.totalSangrias, equals(80.0));
      expect(notifier.caixa?.saldoDinheiroEsperado, equals(170.0));
    });

    test('7. Redução Z e Fechamento de Caixa', () {
      notifier.fecharCaixaReducaoZ();
      expect(notifier.caixa?.status, equals(StatusCaixa.fechado));
      expect(notifier.caixa?.dataFechamento, isNotNull);
      expect(notifier.isCaixaAberto, isFalse);
    });
  });
}
