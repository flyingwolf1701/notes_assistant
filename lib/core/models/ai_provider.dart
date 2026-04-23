class AiProvider {
  const AiProvider({required this.id, required this.name, required this.baseUrl});
  final String id;
  final String name;
  final String baseUrl;
}

const kKnownProviders = [
  AiProvider(
    id: 'groq',
    name: 'Groq',
    baseUrl: String.fromEnvironment('GROQ_BASE_URL', defaultValue: 'https://api.groq.com/openai/v1'),
  ),
  AiProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: String.fromEnvironment('OPENROUTER_BASE_URL', defaultValue: 'https://openrouter.ai/api/v1'),
  ),
  AiProvider(
    id: 'siliconflow',
    name: 'SiliconFlow',
    baseUrl: String.fromEnvironment('SILICONFLOW_BASE_URL', defaultValue: 'https://api.siliconflow.cn/v1'),
  ),
];

AiProvider providerById(String id) =>
    kKnownProviders.firstWhere((p) => p.id == id, orElse: () => kKnownProviders.first);
