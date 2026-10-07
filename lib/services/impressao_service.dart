import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/venda_pdv.dart';
import '../models/caixa_sessao.dart';
import '../models/movimentacao_caixa.dart';

class ImpressaoService {
  static final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dataHora = DateFormat('dd/MM/yyyy HH:mm:ss');

  /// Impressão do Cupom Fiscal DANFE NFC-e
  static Future<void> imprimirDanfeNfce(VendaPdv venda) async {
    final doc = pw.Document();

    // Formato de Bobina Térmica 80mm contínua
    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('MERCADO & CONVENIENCIA APP ACADEMIA',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  textAlign: pw.TextAlign.center),
              pw.Text('CNPJ: 12.345.678/0001-90  IE: 123.456.789.110',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text('AV. PRINCIPAL, 1000 - CENTRO - SAO PAULO/SP',
                  style: const pw.TextStyle(fontSize: 7)),
              pw.Divider(thickness: 0.5),
              pw.Text(
                  venda.pendenteEnvio
                      ? 'COMPROVANTE DE VENDA'
                      : 'DANFE NFC-e - Documento Auxiliar da',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text(
                  venda.pendenteEnvio
                      ? 'NÃO É DOCUMENTO FISCAL'
                      : 'Nota Fiscal de Consumidor Eletrônica',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              if (venda.pendenteEnvio)
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  child: pw.Text('NFC-e PENDENTE DE EMISSÃO (SEM COMUNICAÇÃO COM O SERVIDOR). SERÁ EMITIDA AUTOMATICAMENTE.',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      textAlign: pw.TextAlign.center),
                ),
              if (venda.contingencia)
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  child: pw.Text('EMITIDA EM CONTINGÊNCIA - PENDENTE DE AUTORIZAÇÃO',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      textAlign: pw.TextAlign.center),
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item Código Descrição', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Qtd x Unit = Total', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              ...venda.itensAtivos.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${item.itemNumero.toString().padLeft(3, '0')} ${item.codigoBarras} ${item.descricao}',
                        style: const pw.TextStyle(fontSize: 8),
                        maxLines: 1,
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '   ${item.quantidade.toStringAsFixed(item.unidade == 'KG' ? 3 : 0)} ${item.unidade} x ${_moeda.format(item.valorUnitario)}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            _moeda.format(item.valorTotal),
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('QTD. TOTAL DE ITENS', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('${venda.itensAtivos.length}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VALOR TOTAL R\$',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_moeda.format(venda.totalLiquido),
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Text('FORMA DE PAGAMENTO                VALOR PAGO',
                  style: const pw.TextStyle(fontSize: 7)),
              ...venda.pagamentos.map(
                (p) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(p.descricao, style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(_moeda.format(p.valor), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              if (venda.troco > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TROCO R\$', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(_moeda.format(venda.troco), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              pw.Divider(thickness: 0.5),
              pw.Text(
                'CONSUMIDOR: ${venda.cpfCnpjCliente != null && venda.cpfCnpjCliente!.isNotEmpty ? 'CPF/CNPJ: ${venda.cpfCnpjCliente}' : 'NÃO IDENTIFICADO'}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                venda.numeroNfce != null
                    ? 'NFC-e Nº ${venda.numeroNfce} Série ${(venda.serieNfce ?? 1).toString().padLeft(3, '0')} Data: ${_dataHora.format(venda.dataHora)}'
                    : 'Venda Nº ${venda.numeroCupom} (sem número fiscal) Data: ${_dataHora.format(venda.dataHora)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              if (venda.protocoloNfce != null)
                pw.Text('Protocolo de Autorização: ${venda.protocoloNfce}',
                    style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 4),
              pw.Text('CHAVE DE ACESSO:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                venda.chaveAcessoNfce ?? 'AGUARDANDO EMISSÃO NO SERVIDOR',
                style: const pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              if (venda.qrCodeNfce != null)
                pw.Container(
                  height: 90,
                  width: 90,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: venda.qrCodeNfce!,
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text('Consulte pela Chave de Acesso em:', style: const pw.TextStyle(fontSize: 7)),
              pw.Text('www.fazenda.sp.gov.br/nfce/consulta', style: const pw.TextStyle(fontSize: 7)),
              pw.Divider(thickness: 0.5),
              pw.Text(
                  'Tributos Totais Incidentes (Lei Federal 12.741/2012): ${_moeda.format(venda.totalLiquido * 0.18)}',
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('Operador: ${venda.operadorNome} | Caixa: ${venda.caixaNumero}',
                  style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: venda.numeroNfce != null
          ? 'NFC-e_${venda.numeroNfce}'
          : 'Venda_${venda.numeroCupom}',
    );
  }

  /// Impressão de Comprovante de Sangria / Suprimento
  static Future<void> imprimirMovimentacao(MovimentacaoCaixa mov, int caixaNumero) async {
    final doc = pw.Document();
    final isSangria = mov.tipo == TipoMovimentacaoCaixa.sangria;

    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 5 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('MERCADO & CONVENIENCIA APP ACADEMIA',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Divider(thickness: 0.5),
              pw.Text(
                isSangria ? 'COMPROVANTE DE SANGRIA DE CAIXA' : 'COMPROVANTE DE SUPRIMENTO DE CAIXA',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CAIXA:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('$caixaNumero', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DATA/HORA:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_dataHora.format(mov.dataHora), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('OPERADOR:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(mov.operadorNome, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (mov.gerenteAutorizador != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GERENTE AUTORIZADOR:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(mov.gerenteAutorizador!, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.SizedBox(height: 6),
              pw.Text('MOTIVO: ${mov.motivo}', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VALOR TOTAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_moeda.format(mov.valor), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 20),
              pw.Container(width: 180, child: pw.Divider(thickness: 0.5)),
              pw.Text('Assinatura do Operador', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 15),
              pw.Container(width: 180, child: pw.Divider(thickness: 0.5)),
              pw.Text('Assinatura do Gerente / Tesouraria', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${isSangria ? 'Sangria' : 'Suprimento'}_Caixa$caixaNumero',
    );
  }

  /// Impressão de Leitura X / Redução Z
  static Future<void> imprimirRelatorioFiscal(CaixaSessao sessao, {required bool isReducaoZ}) async {
    final doc = pw.Document();

    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 5 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('MERCADO & CONVENIENCIA APP ACADEMIA',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Divider(thickness: 0.5),
              pw.Text(
                isReducaoZ ? 'REDUÇÃO Z - FECHAMENTO DE CAIXA' : 'LEITURA X - CONFERÊNCIA PARCIAL',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CAIXA:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('${sessao.caixaNumero}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('OPERADOR:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(sessao.operadorNome, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ABERTURA:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_dataHora.format(sessao.dataAbertura), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (sessao.dataFechamento != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FECHAMENTO:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(_dataHora.format(sessao.dataFechamento!), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('FUNDO DE TROCO INICIAL:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_moeda.format(sessao.fundoTrocoInicial), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL SUPRIMENTOS (+):', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_moeda.format(sessao.totalSuprimentos), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL SANGRIAS (-):', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_moeda.format(sessao.totalSangrias), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Text('TOTALIZADORES POR FORMA DE PAGAMENTO',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              _linhaForma('01', 'DINHEIRO', sessao),
              _linhaForma('03', 'CARTAO DE CREDITO', sessao),
              _linhaForma('04', 'CARTAO DE DEBITO', sessao),
              _linhaForma('17', 'PIX', sessao),
              _linhaForma('10', 'VALE ALIMENTACAO', sessao),
              _linhaForma('11', 'VALE REFEICAO', sessao),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL VENDAS BRUTO:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_moeda.format(sessao.totalVendasBruto), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SALDO EM DINHEIRO NA GAVETA:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_moeda.format(sessao.saldoDinheiroEsperado), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CUPONS EMITIDOS: ${sessao.vendasFinalizadas.length}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('CANCELADOS: ${sessao.vendasCanceladas.length}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Container(width: 180, child: pw.Divider(thickness: 0.5)),
              pw.Text('Assinatura do Operador', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 12),
              pw.Container(width: 180, child: pw.Divider(thickness: 0.5)),
              pw.Text('Assinatura do Gerente Responsável', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${isReducaoZ ? 'ReducaoZ' : 'LeituraX'}_Caixa${sessao.caixaNumero}',
    );
  }

  static pw.Widget _linhaForma(String codigo, String label, CaixaSessao sessao) {
    final valor = sessao.totalPorForma(codigo);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(_moeda.format(valor), style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}
