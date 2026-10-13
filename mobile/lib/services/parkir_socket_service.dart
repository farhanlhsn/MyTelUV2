import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:mobile/utils/logger.dart';

/// Service untuk menerima update kapasitas parkir secara real-time via Socket.io.
///
/// Backend mengemit event `parking_update` setiap ada kendaraan masuk/keluar,
/// dengan payload:
///   { id_parkiran: int, live_kapasitas: int, kapasitas: int }
///
/// Backend hanya menerima koneksi yang membawa JWT valid: token dibaca dari
/// secure storage (kunci yang sama dengan [ApiClient]) dan dikirim lewat
/// `auth: { token }`. Jika ditolak dengan `Unauthorized`, service berhenti
/// mencoba menyambung ulang dan melaporkan offline.
class ParkirSocketService {
  static const String _eventName = 'parking_update';
  static const String _tokenKey = 'token';
  static const String _unauthorizedMessage = 'Unauthorized';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;

  /// Bertambah setiap [disconnect] agar [connect] yang masih menunggu token
  /// tahu bahwa ia sudah dibatalkan.
  int _generation = 0;

  bool get isConnected => _isConnected;

  /// Sambungkan ke backend Socket.io dan mulai dengarkan [_eventName].
  /// [baseUrl] — URL backend, contoh: "http://213.210.37.132:5050"
  /// [onUpdate] — callback yang dipanggil setiap kali ada update kapasitas.
  /// [onError] — dipanggil saat gagal tersambung, termasuk `Unauthorized`.
  Future<void> connect({
    required String baseUrl,
    required void Function(Map<String, dynamic> data) onUpdate,
    void Function()? onConnected,
    void Function()? onDisconnected,
    void Function(dynamic err)? onError,
  }) async {
    // Jangan sambung dua kali
    if (_isConnected || _isConnecting || _socket != null) return;

    final int generation = _generation;
    _isConnecting = true;
    String? token;
    try {
      token = await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      debugLog('❌ ParkirSocketService: gagal membaca token: $e');
    } finally {
      _isConnecting = false;
    }

    // disconnect() dipanggil selagi menunggu token
    if (generation != _generation) return;

    if (token == null || token.isEmpty) {
      debugLog('ParkirSocketService: tidak ada token, socket tidak disambungkan');
      _isConnected = false;
      onError?.call(_unauthorizedMessage);
      return;
    }

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket']) // Hindari long-polling
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugLog('✅ ParkirSocketService: terhubung ke $baseUrl');
      onConnected?.call();
    });

    _socket!.on(_eventName, (data) {
      debugLog('📡 parking_update: $data');
      if (data is Map) {
        onUpdate(Map<String, dynamic>.from(data));
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugLog('🔌 ParkirSocketService: terputus');
      onDisconnected?.call();
    });

    _socket!.onError((err) {
      debugLog('❌ ParkirSocketService error: $err');
      _handleError(err, onError);
    });

    _socket!.onConnectError((err) {
      debugLog('❌ ParkirSocketService connect error: $err');
      _handleError(err, onError);
    });

    _socket!.connect();
  }

  /// Token ditolak server (`Unauthorized`): berhenti mencoba menyambung ulang
  /// dan laporkan offline. Error lain (server mati, jaringan putus) tetap
  /// dibiarkan dengan reconnect otomatis milik socket_io_client.
  void _handleError(dynamic err, void Function(dynamic err)? onError) {
    if (err.toString().contains(_unauthorizedMessage)) {
      debugLog('ParkirSocketService: token ditolak, berhenti menyambung ulang');
      disconnect();
    }
    onError?.call(err);
  }

  /// Putuskan koneksi dan bersihkan resources.
  void disconnect() {
    _generation++;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    debugLog('🔌 ParkirSocketService: disconnected & disposed');
  }
}
