class Language {
  final String name;
  final String pistonKey;
  final String version;

  const Language({
    required this.name,
    required this.pistonKey,
    required this.version,
  });
}

const List<Language> supportedLanguages = [
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
    pistonKey: "python",
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
      case 'cpp':
        return 'main.cpp';
      case 'java':
        return 'Main.java';
      case 'python':
        return 'main.py';
      case 'javascript':
        return 'main.js';
      default:
        return 'main';
    }
  }
}
