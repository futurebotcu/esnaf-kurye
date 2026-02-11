import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _bagli = false;

  bool get bagli => _bagli;
  io.Socket? get socket => _socket;

  void baglan(String token) {
    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      _bagli = true;
      debugPrint('Socket bağlandı');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _bagli = false;
      debugPrint('Socket bağlantı kesildi');
      notifyListeners();
    });

    _socket!.onConnectError((data) {
      debugPrint('Socket bağlantı hatası: $data');
    });
  }

  void konumGonder(double lat, double lon) {
    _socket?.emit('kurye:konum_guncelle', {'lat': lat, 'lon': lon});
  }

  void dinle(String olay, Function(dynamic) callback) {
    _socket?.on(olay, callback);
  }

  void dinlemeyi_birak(String olay) {
    _socket?.off(olay);
  }

  void kes() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _bagli = false;
    notifyListeners();
  }
}
