import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager_pdv_windows/models/item_venda.dart';
import 'package:task_manager_pdv_windows/models/pagamento_item.dart';
import 'package:task_manager_pdv_windows/models/produto_pdv.dart';
import 'package:task_manager_pdv_windows/models/venda_pdv.dart';
import 'package:task_manager_pdv_windows/services/api_service.dart';
import 'package:task_manager_pdv_windows/services/fila_contingencia_service.dart';
import 'package:task_manager_pdv_windows/services/pdv_state_notifier.dart';

/// Chave de 44 dígitos: serie 001, nNF 000000123.
const _chave = '35260912345678000190650010000001231000000015';

VendaPdv _venda({double pago = 25.0, String? cpf}) => VendaPdv(
      id: 'local-1',
      numeroCupom: 1001,
      dataHora: DateTime(2026, 10, 7, 10),
      caixaNumero: 1,
      operadorId: 5,
      operadorNome: 'OP',
      cpfCnpjCliente: cpf,
      itens: [
        ItemVenda(
          itemNumero: 1,
          produtoId: 20017,
          codigoBarras: '7894900011517',
          descricao: 'COCA 2L',
          ncm: '22021000',
          quantidade: 2,
          valorUnitario: 10.0,
        ),
      ],
      pagamentos: [PagamentoItem(codigoSefaz: '01', valor: pago)],
    );

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilaContingenciaService fila;
  final api = ApiService();

  void usar(MockClientHandler handler, {int? parceiroId}) {
    api.configurarParaTeste(
      client: MockClient(handler),
      filaServico: fila,
      baseUrl: 'https://servidor.teste',
      empresaId: 1,
      parceiroId: parceiroId,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fila = FilaContingenciaService();
  });

  group('emissão pelo fluxo real do backend', () {
    test('200 AUTORIZADA: cria venda, emite e usa dados do backend (sem fila)', () async {
      final chamadas = <String>[];
      Map<String, dynamic>? corpoNfce;
      usar((req) async {
        chamadas.add('${req.method} ${req.url.path}?${req.url.query}');
        if (req.url.path == '/api/vendas') return _json(201, {'id': 77});
        corpoNfce = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(200, {
          'nfceId': 9,
          'chaveAcesso': _chave,
          'status': 'AUTORIZADA',
          'protocolo': '135260000999',
          'qrCodeUrl': 'https://qr/real',
        });
      }, parceiroId: 42);

      final res = await api.emitirNfce(_venda(cpf: '123.456.789-09'));

      expect(chamadas, [
        'POST /api/vendas?',
        'POST /api/vendas/77/emitir-nfce?parceiroId=42',
      ]);
      expect(res['sucesso'], isTrue);
      expect(res['resultado'], 'AUTORIZADA');
      expect(res['chaveAcesso'], _chave);
      expect(res['protocolo'], '135260000999');
      expect(res['qrCode'], 'https://qr/real');
      expect(res['numeroNfce'], 123);
      expect(res['serieNfce'], 1);
      expect(res['pendenteEnvio'], isFalse);
      expect(await fila.contar(), 0);

      expect(corpoNfce!['empresaId'], 1);
      expect(corpoNfce!['cpfConsumidor'], '12345678909');
      expect(corpoNfce!['valorTotalProdutos'], 20.0);
      expect(corpoNfce!['valorTotalNota'], 20.0);
      final pag = (corpoNfce!['pagamentos'] as List).first as Map;
      expect(pag['formaPagamento'], '01');
      expect(pag['troco'], 5.0);
      final item = (corpoNfce!['itens'] as List).first as Map;
      expect(item['produtoId'], 20017);
      expect(item['ncm'], '22021000');
      expect(item['valorTotal'], 20.0);
    });

    test('308 (context-path legado): grava na fila, sem chave/protocolo/QR fictícios', () async {
      usar((req) async => http.Response('', 308,
          headers: {'location': 'https://servidor.teste/api/vendas'}));

      final res = await api.emitirNfce(_venda());

      expect(res['sucesso'], isTrue);
      expect(res['pendenteEnvio'], isTrue);
      expect(res['resultado'], 'PENDENTE_ENVIO');
      expect(res['chaveAcesso'], isNull);
      expect(res['protocolo'], isNull);
      expect(res['qrCode'], isNull);
      final pend = await fila.listar();
      expect(pend, hasLength(1));
      expect(pend.first.status, PendenciaNfce.statusPendente);
      expect(pend.first.ultimoErro, contains('308'));
    });

    test('timeout: grava na fila como PENDENTE_ENVIO', () async {
      usar((req) async => throw TimeoutException('lento'));

      final res = await api.emitirNfce(_venda());

      expect(res['pendenteEnvio'], isTrue);
      expect(res['chaveAcesso'], isNull);
      expect(await fila.contar(), 1);
    });

    test('400 de validação: não enfileira e devolve erro ao operador', () async {
      usar((req) async => _json(400, {'message': 'NCM invalido'}));

      final res = await api.emitirNfce(_venda());

      expect(res['sucesso'], isFalse);
      expect(res['mensagem'], contains('NCM invalido'));
      expect(await fila.contar(), 0);
    });

    test('200 REJEITADA: não finaliza e mostra motivo da SEFAZ', () async {
      usar((req) async {
        if (req.url.path == '/api/vendas') return _json(201, {'id': 5});
        return _json(200, {
          'nfceId': 3,
          'chaveAcesso': _chave,
          'status': 'REJEITADA',
          'codigoRetorno': '539',
          'motivoRejeicao': 'Duplicidade de NF-e',
        });
      });

      final res = await api.emitirNfce(_venda());

      expect(res['sucesso'], isFalse);
      expect(res['mensagem'], contains('539'));
      expect(await fila.contar(), 0);
    });

    test('200 CONTINGENCIA registrada no backend: usa chave real do backend', () async {
      usar((req) async {
        if (req.url.path == '/api/vendas') return _json(201, {'id': 6});
        return _json(200, {
          'nfceId': 4,
          'chaveAcesso': _chave,
          'status': 'CONTINGENCIA',
          'motivoRejeicao': 'SEFAZ indisponivel',
        });
      });

      final res = await api.emitirNfce(_venda());

      expect(res['sucesso'], isTrue);
      expect(res['contingencia'], isTrue);
      expect(res['pendenteEnvio'], isFalse);
      expect(res['chaveAcesso'], _chave);
      expect(res['protocolo'], isNull);
    });
  });

  group('fila de contingência', () {
    test('venda criada mas emissão falhou: sincronização reenvia só a emissão', () async {
      var criarVenda = 0;
      var emitir = 0;
      var online = false;
      usar((req) async {
        if (req.url.path == '/api/vendas') {
          criarVenda++;
          return _json(201, {'id': 88});
        }
        emitir++;
        if (!online) return _json(503, {'message': 'indisponivel'});
        return _json(200, {
          'nfceId': 1,
          'chaveAcesso': _chave,
          'status': 'AUTORIZADA',
          'protocolo': 'P1',
        });
      });

      final res = await api.emitirNfce(_venda());
      expect(res['pendenteEnvio'], isTrue);
      expect((await fila.listar()).first.vendaId, 88);

      // ainda sem rede: continua pendente e conta tentativa
      expect(await api.sincronizarPendentes(), 0);
      expect((await fila.listar()).first.tentativas, 2);

      online = true;
      expect(await api.sincronizarPendentes(), 1);
      expect(await fila.contar(), 0);
      expect(criarVenda, 1, reason: 'não pode duplicar a venda no backend');
      expect(emitir, 3);
    });

    test('rejeição na sincronização marca REJEITADA_REVISAR e não descarta a venda', () async {
      var fase = 0;
      usar((req) async {
        if (req.url.path == '/api/vendas') return _json(201, {'id': 9});
        if (fase == 0) return _json(503, {});
        return _json(422, {'message': 'config fiscal ausente'});
      });
      await api.emitirNfce(_venda());
      fase = 1;

      expect(await api.sincronizarPendentes(), 0);
      final pend = await fila.listar();
      expect(pend, hasLength(1));
      expect(pend.first.status, PendenciaNfce.statusRevisar);
    });

    test('fila sobrevive a nova instância do serviço (persistência)', () async {
      usar((req) async => throw TimeoutException('x'));
      await api.emitirNfce(_venda());

      expect(await FilaContingenciaService().contar(), 1);
    });
  });

  group('helpers', () {
    test('normalizarBaseUrl remove /boletobancos legado só no Railway', () {
      expect(
          ApiService.normalizarBaseUrl(
              'https://appacademia-production-be7e.up.railway.app/boletobancos/'),
          'https://appacademia-production-be7e.up.railway.app');
      expect(ApiService.normalizarBaseUrl('http://localhost:9001/boletobancos'),
          'http://localhost:9001/boletobancos');
    });

    test('NfceChave extrai série e número do backend', () {
      expect(NfceChave.numero(_chave), 123);
      expect(NfceChave.serie(_chave), 1);
      expect(NfceChave.numero('123'), isNull);
      expect(NfceChave.numero(null), isNull);
    });

    test('desconto geral é rateado e fecha com o total da nota', () {
      final base = _venda();
      final venda = VendaPdv(
        id: base.id,
        numeroCupom: base.numeroCupom,
        dataHora: base.dataHora,
        caixaNumero: 1,
        operadorId: 1,
        operadorNome: 'OP',
        itens: [
          ...base.itens,
          ItemVenda(
              itemNumero: 2,
              produtoId: 2,
              codigoBarras: '',
              descricao: 'B',
              ncm: '22021000',
              quantidade: 1,
              valorUnitario: 10.0),
        ],
        pagamentos: [PagamentoItem(codigoSefaz: '17', valor: 27.0)],
        descontoGeral: 3.0,
      );
      final corpo = ApiService.montarCorpoNfce(venda, 1);
      final itens = corpo['itens'] as List;
      final somaDesc = itens.fold(0.0, (a, i) => a + (i as Map)['valorDesconto']);
      expect(somaDesc, closeTo(3.0, 0.001));
      expect(corpo['valorDesconto'], 3.0);
      expect(corpo['valorTotalNota'], 27.0);
      expect((itens[1] as Map)['gtin'], 'SEM GTIN');
    });
  });

  group('PdvStateNotifier', () {
    test('rejeição não finaliza a venda nem limpa o carrinho', () async {
      usar((req) async => _json(400, {'message': 'NCM invalido'}));
      final notifier = PdvStateNotifier();
      notifier.abrirCaixa(
          caixaNumero: 1, operadorId: 1, operadorNome: 'OP', fundoTroco: 0);
      notifier.adicionarProduto(
          ProdutoPdv(
              id: 1,
              codigoBarras: '1',
              codigoInterno: '1',
              nome: 'X',
              precoVenda: 10,
              ncm: '22021000'),
          quantidade: 1);
      notifier.adicionarPagamento('01', 10);

      final res = await notifier.finalizarVendaEmitirNfce();

      expect(res['sucesso'], isFalse);
      expect(res['mensagem'], contains('NCM invalido'));
      expect(notifier.vendaAtual!.itensAtivos, hasLength(1));
      expect(notifier.caixa!.vendas, isEmpty);
      expect(notifier.processando, isFalse);
      notifier.dispose();
    });
  });
}
