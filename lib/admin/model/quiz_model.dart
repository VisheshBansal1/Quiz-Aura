class Quiz {
  final String id;
  final String title;
  final String topic;
  final String joinCode;

  Quiz({
    required this.id,
    required this.title,
    required this.topic,
    required this.joinCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'topic': topic,
      'joinCode': joinCode,
      'createdAt': DateTime.now(),
    };
  }
}
