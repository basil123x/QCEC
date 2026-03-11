import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class DioHelper {
  /// Creates a Dio instance with SSL certificate handling configured
  static Dio createDio({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout ?? const Duration(seconds: 30),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        sendTimeout: sendTimeout ?? const Duration(seconds: 30),
      ),
    );

    // Configure SSL certificate handling for qcec.online
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Accept certificates from qcec.online domains
        return host == 'qcec-qatar.com' || 
               host == 'www.qcec-qatar.com' ||
               host.endsWith('.qcec-qatar.com');
      };
      return client;
    };

    return dio;
  }
}
