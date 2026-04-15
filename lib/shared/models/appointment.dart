class Appointment {
  const Appointment({
    required this.client,
    required this.service,
    required this.start,
    required this.end,
    required this.column,
    required this.durationBlocks,
    required this.tint,
  });

  final String client;
  final String service;
  final String start;
  final String end;
  final int column;
  final int durationBlocks;
  final int tint;
}