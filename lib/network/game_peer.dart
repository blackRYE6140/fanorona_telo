abstract class GamePeer {
  Stream<Map<String, dynamic>> get messages;

  void send(Map<String, dynamic> message);

  Future<void> dispose();
}
