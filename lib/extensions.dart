part of 'lite_server.dart';

extension HttpRequestHelpers on HttpRequest {
  Future<String> readBodyAsString([Encoding? encoding]) async {
    final encoder = encoding ?? utf8;
    return encoder.decode((await toList()).expand((i) => i).toList());
  }

  Stream<HttpMultiPartData> multipartData() async* {
    if (headers.contentType == null) {
      throw Exception('Content-Type not found');
    }

    final boundary = headers.contentType!.parameters['boundary'];

    if (boundary == null) {
      throw Exception('Boundary not found');
    }

    final parts = await transform<MimeMultipart>(
            MimeMultipartTransformer(boundary).cast())
        .toList();

    for (final part in parts) {
      final contentDisposition = part.headers['content-disposition'];
      part.headers.remove('content-disposition');

      yield HttpMultiPartData(
        {
          ...parseContentDisposition(contentDisposition),
          ...part.headers,
        },
        await part.fold<List<int>>([], (p, d) => [...p, ...d]),
      );
    }
  }

  Map<String, String> parseContentDisposition(String? contentDisposition) {
    final output = <String, String>{};

    if (contentDisposition == null) {
      return output;
    }

    var params = <String>[];

    for (final entry in contentDisposition.split(';')) {
      if (entry.contains('=')) {
        final parsed = entry.split('=');
        output[parsed.first.trim()] = parsed.last.trim();
      } else {
        params.add(entry);
      }
    }

    output['params'] = params.join(',');

    return output;
  }
}

class HttpMultiPartData {
  const HttpMultiPartData(this.info, this.bytes);
  final Map<String, String> info;
  final List<int> bytes;
}
