import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Dio adapter for tests: answers with canned JSON bodies and remembers the requests.
/// With several responses they are served in order; the last one repeats.
class StubHttpAdapter implements HttpClientAdapter {
  final List<(int, Map<String, dynamic>)> _responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  StubHttpAdapter(int statusCode, Map<String, dynamic> body)
    : _responses = <(int, Map<String, dynamic>)>[(statusCode, body)];

  StubHttpAdapter.sequence(List<(int, Map<String, dynamic>)> responses)
    : _responses = responses;

  RequestOptions? get lastRequest => requests.isEmpty ? null : requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = requests.length < _responses.length
        ? requests.length
        : _responses.length - 1;
    requests.add(options);
    final (statusCode, body) = _responses[index];
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  /// A Dio wired to this adapter.
  Dio dio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = this;
    return dio;
  }
}
