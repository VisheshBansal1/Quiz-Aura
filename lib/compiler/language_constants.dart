class Language {
  final String name;
  final String pistonKey;
  final String version;

  const Language({
    required this.name,
    required this.pistonKey,
    required this.version,
  });

  @override
  bool operator ==(Object other) =>
      other is Language && other.pistonKey == pistonKey;

  @override
  int get hashCode => pistonKey.hashCode;
}

const List<Language> supportedLanguages = [
  Language(
    name: "C",
    pistonKey: "c",
    version: "10.2.0",
  ),
  Language(
    name: "C++",
    pistonKey: "cpp",
    version: "10.2.0",
  ),
  Language(
    name: "Java",
    pistonKey: "java",
    version: "15.0.2",
  ),
  Language(
    name: "Python",
    // FIX: Use "python3" directly — no more relying on _normalizeLanguage
    pistonKey: "python3",
    version: "3.10.0",
  ),
  Language(
    name: "JavaScript",
    pistonKey: "javascript",
    version: "18.15.0",
  ),
];

extension LanguageFile on Language {
  String get fileName {
    switch (pistonKey) {
      case 'c':
        return 'main.c';
      case 'cpp':
        return 'main.cpp';
      case 'java':
        return 'Main.java';
      case 'python3':
      case 'python':
        return 'main.py';
      case 'javascript':
        return 'main.js';
      default:
        return 'main';
    }
  }
}
