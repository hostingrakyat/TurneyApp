/// A player slot in a bracket. `id` is an auth user id for real registrants,
/// or a synthetic id for demo/bot opponents in offline mode.
class Participant {
  const Participant({required this.id, required this.name, this.isBot = false});

  final String id;
  final String name;
  final bool isBot;
}
