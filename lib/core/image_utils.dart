import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image/image.dart' as img;
import '../models/color_data.dart';

class ImageUtils {
  // --- All analysis methods remain the same ---
  static Future<ImageAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    final imageProvider = MemoryImage(imageBytes);
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Cannot decode image');
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      maximumColorCount: 256,
    );
    final advancedAnalysis = await _performAdvancedColorAnalysis(image, paletteGenerator);
    final dominantColor = _calculateDominantColor(image, paletteGenerator);
    final colorPalette = _createDetailedColorPalette(paletteGenerator, image);
    final brightnessAnalysis = _calculateBrightnessAnalysis(image);
    final harmonyAnalysis = _analyzeColorHarmony(colorPalette);
    final temperatureAnalysis = _analyzeColorTemperature(image);
    final accessibility = ColorAccessibility(
      averageContrast: 0.0,
      isAccessible: false,
      recommendations: [],
      level: AccessibilityLevel.fail,
    );
    return ImageAnalysisResult(
      dominantColor: dominantColor,
      colorPalette: colorPalette,
      averageBrightness: brightnessAnalysis.averageBrightness,
      isDark: brightnessAnalysis.isDark,
      brightnessDescription: brightnessAnalysis.description,
      colorCount: advancedAnalysis.uniqueColorCount,
      contrast: advancedAnalysis.contrast,
      saturation: advancedAnalysis.saturation,
      histogram: advancedAnalysis.histogram,
      colorHarmony: harmonyAnalysis,
      temperature: temperatureAnalysis,
      mood: _determineMood(colorPalette, brightnessAnalysis, temperatureAnalysis),
      accessibility: accessibility,
      clusters: advancedAnalysis.clusters,
    );
  }

  static Color _calculateDominantColor(img.Image image, PaletteGenerator palette) {
    final Map<int, int> colorCount = {};
    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final pixel = image.getPixel(x, y);
        final color = _quantizeColor(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
        colorCount[color] = (colorCount[color] ?? 0) + 1;
      }
    }
    int dominantColorInt = colorCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    return Color(dominantColorInt | 0xFF000000);
  }

  static int _quantizeColor(int r, int g, int b) {
    const int factor = 32;
    return ((r ~/ factor) * factor) << 16 |
    ((g ~/ factor) * factor) << 8 |
    ((b ~/ factor) * factor);
  }

  static List<ColorData> _createDetailedColorPalette(PaletteGenerator palette, img.Image image) {
    final Map<Color, int> colorPixelCount = {};
    final totalPixels = image.width * image.height;
    for (final color in palette.colors) {
      int pixelCount = 0;
      for (int y = 0; y < image.height; y += 3) {
        for (int x = 0; x < image.width; x += 3) {
          final pixel = image.getPixel(x, y);
          final pixelColor = Color.fromARGB(
            255,
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
          );
          if (_colorsAreSimilar(color, pixelColor)) {
            pixelCount++;
          }
        }
      }
      colorPixelCount[color] = pixelCount;
    }
    final sortedColors = colorPixelCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final List<ColorData> colorPalette = [];
    for (final entry in sortedColors.take(12)) {
      final color = entry.key;
      final pixelCount = entry.value;
      final percentage = (pixelCount / (totalPixels / 9)) * 100;
      colorPalette.add(ColorData(
        color: color,
        percentage: percentage.clamp(0, 100),
        hexCode: ColorData.colorToHex(color),
        name: _getAdvancedColorName(color),
      ));
    }
    return colorPalette;
  }

  static bool _colorsAreSimilar(Color color1, Color color2) {
    const threshold = 30;
    return (color1.red - color2.red).abs() < threshold &&
        (color1.green - color2.green).abs() < threshold &&
        (color1.blue - color2.blue).abs() < threshold;
  }

  static BrightnessAnalysis _calculateBrightnessAnalysis(img.Image image) {
    double totalBrightness = 0;
    int darkPixels = 0;
    int brightPixels = 0;
    int totalPixels = 0;
    List<double> brightnessValues = [];
    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final pixel = image.getPixel(x, y);
        final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b) / 255;
        totalBrightness += brightness;
        brightnessValues.add(brightness);
        totalPixels++;
        if (brightness < 0.3) darkPixels++;
        if (brightness > 0.7) brightPixels++;
      }
    }
    final averageBrightness = totalPixels > 0 ? totalBrightness / totalPixels : 0.0;
    final isDark = averageBrightness < 0.4;
    final variance = totalPixels > 0
        ? brightnessValues.fold(0.0, (sum, value) => sum + math.pow(value - averageBrightness, 2)) / totalPixels
        : 0.0;
    final standardDeviation = math.sqrt(variance);
    String description;
    if (averageBrightness > 0.7) {
      description = 'تصویر بسیار روشن';
    } else if (averageBrightness > 0.5) {
      description = 'تصویر روشن';
    } else if (averageBrightness > 0.3) {
      description = 'تصویر متوسط';
    } else {
      description = 'تصویر تاریک';
    }
    final distribution = BrightnessDistribution(
      histogram: [],
      median: 0.0,
      standardDeviation: standardDeviation,
      skewness: 0.0,
    );
    return BrightnessAnalysis(
      averageBrightness: averageBrightness,
      isDark: isDark,
      description: description,
      darkPixelPercentage: totalPixels > 0 ? (darkPixels / totalPixels) * 100 : 0.0,
      brightPixelPercentage: totalPixels > 0 ? (brightPixels / totalPixels) * 100 : 0.0,
      contrast: standardDeviation,
      distribution: distribution,
    );
  }

  static Future<AdvancedColorAnalysis> _performAdvancedColorAnalysis(
      img.Image image, PaletteGenerator palette) async {
    final Set<int> uniqueColors = {};
    double totalSaturation = 0;
    int totalPixels = 0;
    final List<int> redHist = List.filled(256, 0);
    final List<int> greenHist = List.filled(256, 0);
    final List<int> blueHist = List.filled(256, 0);
    final List<int> luminanceHist = List.filled(256, 0);
    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        uniqueColors.add((r << 16) | (g << 8) | b);
        final maxVal = math.max(r, math.max(g, b));
        final minVal = math.min(r, math.min(g, b));
        final saturation = maxVal == 0 ? 0 : (maxVal - minVal) / maxVal;
        totalSaturation += saturation;
        redHist[r]++;
        greenHist[g]++;
        blueHist[b]++;
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
        luminanceHist[luminance.clamp(0, 255)]++;
        totalPixels++;
      }
    }
    final contrast = _calculateContrast(redHist, greenHist, blueHist);
    return AdvancedColorAnalysis(
      uniqueColorCount: uniqueColors.length,
      contrast: contrast,
      saturation: totalPixels > 0 ? totalSaturation / totalPixels : 0.0,
      histogram: ColorHistogram(
        red: redHist,
        green: greenHist,
        blue: blueHist,
        luminance: luminanceHist,
      ),
      colorDiversity: totalPixels > 0 ? uniqueColors.length / totalPixels : 0.0,
      clusters: [],
    );
  }

  static double _calculateContrast(List<int> redHist, List<int> greenHist, List<int> blueHist) {
    double redVariance = _calculateVariance(redHist);
    double greenVariance = _calculateVariance(greenHist);
    double blueVariance = _calculateVariance(blueHist);
    return (redVariance + greenVariance + blueVariance) / 3;
  }

  static double _calculateVariance(List<int> histogram) {
    int total = histogram.fold(0, (sum, value) => sum + value);
    if (total == 0) return 0;
    double mean = 0;
    for (int i = 0; i < histogram.length; i++) {
      mean += i * histogram[i];
    }
    mean /= total;
    double variance = 0;
    for (int i = 0; i < histogram.length; i++) {
      variance += histogram[i] * math.pow(i - mean, 2);
    }
    return variance / total;
  }

  static ColorHarmony _analyzeColorHarmony(List<ColorData> colors) {
    if (colors.length < 2) return ColorHarmony.none;
    final hues = colors.map((color) => _getHue(color.color)).toList();
    for (int i = 0; i < hues.length; i++) {
      for (int j = i + 1; j < hues.length; j++) {
        final diff = (hues[i] - hues[j]).abs();
        if (diff > 150 && diff < 210) {
          return ColorHarmony.complementary;
        }
      }
    }
    bool isAnalogous = true;
    for (int i = 1; i < hues.length; i++) {
      if ((hues[i] - hues[i-1]).abs() > 60) {
        isAnalogous = false;
        break;
      }
    }
    if (isAnalogous) return ColorHarmony.analogous;
    if (hues.length >= 3) {
      for (int i = 0; i < hues.length - 2; i++) {
        for (int j = i + 1; j < hues.length - 1; j++) {
          for (int k = j + 1; k < hues.length; k++) {
            final diff1 = (hues[j] - hues[i]).abs();
            final diff2 = (hues[k] - hues[j]).abs();
            if (diff1 > 100 && diff1 < 140 && diff2 > 100 && diff2 < 140) {
              return ColorHarmony.triadic;
            }
          }
        }
      }
    }
    return ColorHarmony.mixed;
  }

  static ColorTemperature _analyzeColorTemperature(img.Image image) {
    double warmth = 0;
    int totalPixels = 0;
    for (int y = 0; y < image.height; y += 3) {
      for (int x = 0; x < image.width; x += 3) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final warmScore = (r + g * 0.5) - (b * 1.5);
        warmth += warmScore;
        totalPixels++;
      }
    }
    final averageWarmth = totalPixels > 0 ? warmth / totalPixels : 0.0;
    if (averageWarmth > 20) {
      return ColorTemperature.warm;
    } else if (averageWarmth < -20) {
      return ColorTemperature.cool;
    } else {
      return ColorTemperature.neutral;
    }
  }

  static String _determineMood(List<ColorData> colors, BrightnessAnalysis brightness, ColorTemperature temperature) {
    if (brightness.isDark) {
      if (temperature == ColorTemperature.cool) return 'آرامش‌بخش';
      if (temperature == ColorTemperature.warm) return 'رمانتیک';
      return 'مرموز';
    } else {
      if (temperature == ColorTemperature.warm) return 'شاد و پرانرژی';
      if (temperature == ColorTemperature.cool) return 'تازه و زنده';
      return 'متعادل';
    }
  }

  static double _getHue(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;
    final maxVal = math.max(r, math.max(g, b));
    final minVal = math.min(r, math.min(g, b));
    final diff = maxVal - minVal;
    if (diff == 0) return 0;
    double hue;
    if (maxVal == r) {
      hue = (60 * ((g - b) / diff) + 360) % 360;
    } else if (maxVal == g) {
      hue = (60 * ((b - r) / diff) + 120) % 360;
    } else {
      hue = (60 * ((r - g) / diff) + 240) % 360;
    }
    return hue;
  }

  static String _getAdvancedColorName(Color color) {
    final hue = _getHue(color);
    final saturation = _getSaturation(color);
    final lightness = color.computeLuminance();
    String baseName;
    if (hue < 30 || hue >= 330) baseName = 'قرمز';
    else if (hue < 60) baseName = 'نارنجی';
    else if (hue < 90) baseName = 'زرد';
    else if (hue < 150) baseName = 'سبز';
    else if (hue < 210) baseName = 'آبی';
    else if (hue < 270) baseName = 'بنفش';
    else baseName = 'صورتی';
    if (saturation < 0.3) baseName = 'خاکستری ' + baseName;
    if (lightness > 0.8) baseName = baseName + ' روشن';
    else if (lightness < 0.2) baseName = baseName + ' تیره';
    return baseName;
  }

  static double _getSaturation(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;
    final maxVal = math.max(r, math.max(g, b));
    final minVal = math.min(r, math.min(g, b));
    return maxVal == 0 ? 0 : (maxVal - minVal) / maxVal;
  }

  // --- Filter Methods ---

  static Uint8List _encodeImage(img.Image image) {
    return Uint8List.fromList(img.encodePng(image));
  }

  static Uint8List applyNegativeFilter(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    return _encodeImage(img.invert(image));
  }

  // FIX: Reverted to manual pixel manipulation for brightness
  static Uint8List applyBrightenFilter(Uint8List imageBytes, int amount) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    for (final pixel in image) {
      pixel.r = (pixel.r + amount).clamp(0, 255);
      pixel.g = (pixel.g + amount).clamp(0, 255);
      pixel.b = (pixel.b + amount).clamp(0, 255);
    }
    return _encodeImage(image);
  }

  static Uint8List applyContrastFilter(Uint8List imageBytes, double contrast) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    return _encodeImage(img.contrast(image, contrast: contrast));
  }

  static Uint8List applyGrayscaleFilter(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    return _encodeImage(img.grayscale(image));
  }

  static Uint8List applySepiaFilter(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    return _encodeImage(img.sepia(image));
  }

  static Uint8List applyCustomFilter({
    required Uint8List imageBytes,
    required double brightness,
    required double contrast,
    required double saturation,
    required double hue,
  }) {
    var image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // FIX: Reverted to manual pixel manipulation for brightness
    if (brightness != 0) {
      final brightnessInt = brightness.round();
      for (final pixel in image) {
        pixel.r = (pixel.r + brightnessInt).clamp(0, 255);
        pixel.g = (pixel.g + brightnessInt).clamp(0, 255);
        pixel.b = (pixel.b + brightnessInt).clamp(0, 255);
      }
    }

    if (contrast != 1.0) {
      image = img.contrast(image, contrast: contrast);
    }

    if (saturation != 1.0 || hue != 0.0) {
      image = img.adjustColor(image, saturation: saturation, hue: hue);
    }

    return _encodeImage(image);
  }
}