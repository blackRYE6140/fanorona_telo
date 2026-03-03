import 'dart:convert';
import 'dart:io';
import 'dart:math';

class LanUtils {
  static Future<String?> findLocalNetworkIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;
          if (_isPrivateIPv4(ip)) {
            return ip;
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static bool _isPrivateIPv4(String ip) {
    return ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        _is172Private(ip);
  }

  static bool _is172Private(String ip) {
    if (!ip.startsWith('172.')) {
      return false;
    }

    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }

    final second = int.tryParse(parts[1]);
    if (second == null) {
      return false;
    }

    return second >= 16 && second <= 31;
  }

  static String generateSessionCode() {
    final random = Random();
    final value = random.nextInt(900000) + 100000;
    return value.toString();
  }

  static String buildQrPayload({
    required String ip,
    required int port,
    required String code,
  }) {
    return jsonEncode({
      'v': 1,
      'ip': ip,
      'port': port,
      'code': code,
    });
  }

  static LanJoinPayload? parseQrPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final map = decoded.cast<String, dynamic>();
      final ip = map['ip'] as String?;
      final port = (map['port'] as num?)?.toInt();
      final code = map['code'] as String?;

      if (ip == null || ip.isEmpty || port == null || code == null || code.isEmpty) {
        return null;
      }

      return LanJoinPayload(ip: ip, port: port, code: code);
    } catch (_) {
      return null;
    }
  }
}

class LanJoinPayload {
  final String ip;
  final int port;
  final String code;

  const LanJoinPayload({
    required this.ip,
    required this.port,
    required this.code,
  });
}
