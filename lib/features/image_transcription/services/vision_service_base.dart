abstract class VisionServiceBase {
  Future<String> extractFromImage(String imagePath);
  Future<String> mergeExtractions(List<String> extractions);
}
