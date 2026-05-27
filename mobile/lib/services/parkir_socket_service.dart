import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:mobile/utils/logger.dart';

/// Service untuk menerima update kapasitas parkir secara real-time via Socket.io.
///
/// Backend mengemit event `parking_update` setiap ada kendaraan masuk/keluar,
/// dengan payload:
///   { id_parkiran: int, live_kapasitas: int, kapasitas: int }
class ParkirSocketService {
  static const String _eventName = 'parking_update';

  io.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Sambungkan ke backend Socket.io dan mulai dengarkan [_eventName].
  /// [baseUrl] — URL backend, contoh: "http://213.210.37.132:5050"
  /// [onUpdate] — callback yang dipanggil setiap kali ada update kapasitas.
  void connect({
    required String baseUrl,
    required void Function(Map<String, dynamic> data) onUpdate,
    void Function()? onConnected,
    void Function()? onDisconnected,
    void Function(dynamic err)? onError,
  }) {
    if (_isConnected) return; // Jangan sambung dua kali

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket']) // Hindari long-polling
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
      onError?.call(err);
    });

    _socket!.onConnectError((err) {
      debugLog('❌ ParkirSocketService connect error: $err');
      onError?.call(err);
    });

    _socket!.connect();
  }

  /// Putuskan koneksi dan bersihkan resources.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    debugLog('🔌 ParkirSocketService: disconnected & disposed');
  }
}
