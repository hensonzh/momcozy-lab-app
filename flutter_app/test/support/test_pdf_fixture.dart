import 'dart:convert';
import 'dart:typed_data';

Uint8List buildTwoPageTestPdf() {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] '
        '/Resources << /Font << /F1 7 0 R >> >> /Contents 4 0 R >>',
    _pdfStream('BT /F1 24 Tf 50 300 Td (Page 1) Tj ET'),
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] '
        '/Resources << /Font << /F1 7 0 R >> >> /Contents 6 0 R >>',
    _pdfStream('BT /F1 24 Tf 50 300 Td (Page 2) Tj ET'),
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final output = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  var byteLength = latin1.encode(output.toString()).length;
  for (var index = 0; index < objects.length; index += 1) {
    offsets.add(byteLength);
    final object = '${index + 1} 0 obj\n${objects[index]}\nendobj\n';
    output.write(object);
    byteLength += latin1.encode(object).length;
  }
  final xrefOffset = byteLength;
  output
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    output.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  output
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  return Uint8List.fromList(latin1.encode(output.toString()));
}

String _pdfStream(String content) {
  return '<< /Length ${latin1.encode(content).length} >>\n'
      'stream\n$content\nendstream';
}
