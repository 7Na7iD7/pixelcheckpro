import 'package:flutter/material.dart';
import 'dart:math' as math;

class ColorData {
  final Color color;
  final double percentage;
  final String hexCode;
  final String name;
  final HSVColor hsvColor;
  final HSLColor hslColor;
  final RGBColor rgbColor;

  ColorData({
    required this.color,
    required this.percentage,
    required this.hexCode,
    required this.name,
  }) : hsvColor = HSVColor.fromColor(color),
        hslColor = HSLColor.fromColor(color),
        rgbColor = RGBColor.fromColor(color);

  // متدهای استاتیک بهبود یافته
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  static String getAdvancedColorName(Color color) {
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;
    final saturation = hsl.saturation;
    final lightness = hsl.lightness;

    // تعیین نام اصلی رنگ بر اساس Hue
    String baseName = _getBaseColorName(hue);

    // اضافه کردن توضیحات بر اساس Saturation و Lightness
    if (lightness > 0.9) return 'سفید';
    if (lightness < 0.1) return 'سیاه';
    if (saturation < 0.1) return 'خاکستری ${_getLightnessDescription(lightness)}';

    String modifier = '';
    if (lightness > 0.8) modifier = 'بسیار روشن ';
    else if (lightness > 0.6) modifier = 'روشن ';
    else if (lightness < 0.2) modifier = 'بسیار تیره ';
    else if (lightness < 0.4) modifier = 'تیره ';

    if (saturation > 0.8) modifier += 'پر رنگ ';
    else if (saturation < 0.3) modifier += 'کم رنگ ';

    return '$modifier$baseName';
  }

  static String _getBaseColorName(double hue) {
    if (hue < 15 || hue >= 345) return 'قرمز';
    if (hue < 45) return 'نارنجی';
    if (hue < 75) return 'زرد';
    if (hue < 105) return 'زرد مایل به سبز';
    if (hue < 135) return 'سبز';
    if (hue < 165) return 'سبز مایل به آبی';
    if (hue < 195) return 'آبی';
    if (hue < 225) return 'آبی مایل به بنفش';
    if (hue < 255) return 'بنفش';
    if (hue < 285) return 'بنفش مایل به قرمز';
    if (hue < 315) return 'صورتی';
    return 'صورتی مایل به قرمز';
  }

  static String _getLightnessDescription(double lightness) {
    if (lightness > 0.8) return 'بسیار روشن';
    if (lightness > 0.6) return 'روشن';
    if (lightness > 0.4) return 'متوسط';
    if (lightness > 0.2) return 'تیره';
    return 'بسیار تیره';
  }

  // محاسبه فاصله رنگی
  double distanceTo(ColorData other) {
    final r1 = color.red, g1 = color.green, b1 = color.blue;
    final r2 = other.color.red, g2 = other.color.green, b2 = other.color.blue;

    return math.sqrt(
        math.pow(r2 - r1, 2) +
            math.pow(g2 - g1, 2) +
            math.pow(b2 - b1, 2)
    );
  }

  // تعیین رنگ مکمل
  Color get complementaryColor {
    final hsv = HSVColor.fromColor(color);
    final complementaryHue = (hsv.hue + 180) % 360;
    return hsv.withHue(complementaryHue).toColor();
  }

  // تعیین رنگ‌های مجاور
  List<Color> get analogousColors {
    final hsv = HSVColor.fromColor(color);
    return [
      hsv.withHue((hsv.hue + 30) % 360).toColor(),
      hsv.withHue((hsv.hue - 30) % 360).toColor(),
    ];
  }

  // تعیین رنگ‌های سه‌گانه
  List<Color> get triadicColors {
    final hsv = HSVColor.fromColor(color);
    return [
      hsv.withHue((hsv.hue + 120) % 360).toColor(),
      hsv.withHue((hsv.hue + 240) % 360).toColor(),
    ];
  }

  // محاسبه کنتراست با رنگ دیگر
  double contrastRatio(Color other) {
    final l1 = color.computeLuminance();
    final l2 = other.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  // تعیین بهترین رنگ متن
  Color get bestTextColor {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // تبدیل به JSON پیشرفته
  Map<String, dynamic> toJson() {
    return {
      'color': color.value,
      'percentage': percentage,
      'hexCode': hexCode,
      'name': name,
      'hsl': {
        'hue': hslColor.hue,
        'saturation': hslColor.saturation,
        'lightness': hslColor.lightness,
      },
      'hsv': {
        'hue': hsvColor.hue,
        'saturation': hsvColor.saturation,
        'value': hsvColor.value,
      },
      'rgb': {
        'red': rgbColor.red,
        'green': rgbColor.green,
        'blue': rgbColor.blue,
      },
      'luminance': color.computeLuminance(),
    };
  }

  factory ColorData.fromJson(Map<String, dynamic> json) {
    return ColorData(
      color: Color(json['color']),
      percentage: json['percentage'],
      hexCode: json['hexCode'],
      name: json['name'],
    );
  }

  @override
  String toString() {
    return 'ColorData(name: $name, hex: $hexCode, percentage: ${percentage.toStringAsFixed(2)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ColorData &&
        other.color.value == color.value &&
        other.percentage == percentage;
  }

  @override
  int get hashCode => color.value.hashCode ^ percentage.hashCode;
}

// کلاس‌های کمکی برای مدل‌های رنگی
class RGBColor {
  final int red;
  final int green;
  final int blue;

  RGBColor({required this.red, required this.green, required this.blue});

  factory RGBColor.fromColor(Color color) {
    return RGBColor(
      red: color.red,
      green: color.green,
      blue: color.blue,
    );
  }

  Color toColor() => Color.fromARGB(255, red, green, blue);

  @override
  String toString() => 'RGB($red, $green, $blue)';
}

class HSLColor {
  final double hue;
  final double saturation;
  final double lightness;

  HSLColor({required this.hue, required this.saturation, required this.lightness});

  factory HSLColor.fromColor(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final delta = max - min;

    double h = 0;
    double s = 0;
    final l = (max + min) / 2;

    if (delta != 0) {
      s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);

      if (max == r) {
        h = ((g - b) / delta + (g < b ? 6 : 0)) * 60;
      } else if (max == g) {
        h = ((b - r) / delta + 2) * 60;
      } else {
        h = ((r - g) / delta + 4) * 60;
      }
    }

    return HSLColor(hue: h, saturation: s, lightness: l);
  }

  @override
  String toString() => 'HSL(${hue.toStringAsFixed(1)}°, ${(saturation * 100).toStringAsFixed(1)}%, ${(lightness * 100).toStringAsFixed(1)}%)';
}

// کلاس نتیجه تحلیل پیشرفته
class ImageAnalysisResult {
  final Color dominantColor;
  final List<ColorData> colorPalette;
  final double averageBrightness;
  final bool isDark;
  final String brightnessDescription;
  final int colorCount;
  final double contrast;
  final double saturation;
  final ColorHistogram histogram;
  final ColorHarmony colorHarmony;
  final ColorTemperature temperature;
  final String mood;
  final ColorAccessibility accessibility;
  final List<ColorCluster> clusters;

  ImageAnalysisResult({
    required this.dominantColor,
    required this.colorPalette,
    required this.averageBrightness,
    required this.isDark,
    required this.brightnessDescription,
    required this.colorCount,
    required this.contrast,
    required this.saturation,
    required this.histogram,
    required this.colorHarmony,
    required this.temperature,
    required this.mood,
    required this.accessibility,
    required this.clusters,
  });

  // تولید پالت رنگ های هارمونیک
  List<ColorData> generateHarmonicPalette() {
    final baseColor = ColorData(
      color: dominantColor,
      percentage: 0,
      hexCode: ColorData.colorToHex(dominantColor),
      name: ColorData.getAdvancedColorName(dominantColor),
    );

    return [
      baseColor,
      ColorData(
        color: baseColor.complementaryColor,
        percentage: 0,
        hexCode: ColorData.colorToHex(baseColor.complementaryColor),
        name: ColorData.getAdvancedColorName(baseColor.complementaryColor),
      ),
      ...baseColor.analogousColors.map((color) => ColorData(
        color: color,
        percentage: 0,
        hexCode: ColorData.colorToHex(color),
        name: ColorData.getAdvancedColorName(color),
      )),
      ...baseColor.triadicColors.map((color) => ColorData(
        color: color,
        percentage: 0,
        hexCode: ColorData.colorToHex(color),
        name: ColorData.getAdvancedColorName(color),
      )),
    ];
  }
}

// کلاس دسترسی پذیری رنگ
class ColorAccessibility {
  final double averageContrast;
  final bool isAccessible;
  final List<String> recommendations;
  final AccessibilityLevel level;

  ColorAccessibility({
    required this.averageContrast,
    required this.isAccessible,
    required this.recommendations,
    required this.level,
  });
}

enum AccessibilityLevel {
  AA,
  AAA,
  fail,
}

// کلاس خوشه‌بندی رنگ
class ColorCluster {
  final Color centerColor;
  final List<ColorData> colors;
  final double density;
  final String name;

  ColorCluster({
    required this.centerColor,
    required this.colors,
    required this.density,
    required this.name,
  });
}

// کلاس‌های کمکی موجود با بهبودهای جزئی
class AdvancedColorAnalysis {
  final int uniqueColorCount;
  final double contrast;
  final double saturation;
  final ColorHistogram histogram;
  final double colorDiversity;
  final List<ColorCluster> clusters;

  AdvancedColorAnalysis({
    required this.uniqueColorCount,
    required this.contrast,
    required this.saturation,
    required this.histogram,
    required this.colorDiversity,
    required this.clusters,
  });
}

class BrightnessAnalysis {
  final double averageBrightness;
  final bool isDark;
  final String description;
  final double darkPixelPercentage;
  final double brightPixelPercentage;
  final double contrast;
  final BrightnessDistribution distribution;

  BrightnessAnalysis({
    required this.averageBrightness,
    required this.isDark,
    required this.description,
    required this.darkPixelPercentage,
    required this.brightPixelPercentage,
    required this.contrast,
    required this.distribution,
  });
}

class BrightnessDistribution {
  final List<double> histogram;
  final double median;
  final double standardDeviation;
  final double skewness;

  BrightnessDistribution({
    required this.histogram,
    required this.median,
    required this.standardDeviation,
    required this.skewness,
  });
}

class ColorHistogram {
  final List<int> red;
  final List<int> green;
  final List<int> blue;
  final List<int> luminance;

  ColorHistogram({
    required this.red,
    required this.green,
    required this.blue,
    required this.luminance,
  });

  // محاسبه آمار هیستوگرام
  Map<String, double> get statistics {
    return {
      'redMean': _calculateMean(red),
      'greenMean': _calculateMean(green),
      'blueMean': _calculateMean(blue),
      'luminanceMean': _calculateMean(luminance),
      'redStd': _calculateStandardDeviation(red),
      'greenStd': _calculateStandardDeviation(green),
      'blueStd': _calculateStandardDeviation(blue),
      'luminanceStd': _calculateStandardDeviation(luminance),
    };
  }

  double _calculateMean(List<int> values) {
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateStandardDeviation(List<int> values) {
    final mean = _calculateMean(values);
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }
}

enum ColorHarmony {
  complementary,
  analogous,
  triadic,
  tetradic,
  splitComplementary,
  mixed,
  monochromatic,
  none,
}

enum ColorTemperature {
  veryWarm,
  warm,
  neutral,
  cool,
  veryCool,
}

// Extensions پیشرفته برای enum ها
extension ColorHarmonyExtension on ColorHarmony {
  String get persianName {
    switch (this) {
      case ColorHarmony.complementary:
        return 'مکمل';
      case ColorHarmony.analogous:
        return 'مجاور';
      case ColorHarmony.triadic:
        return 'سه‌گانه';
      case ColorHarmony.tetradic:
        return 'چهارگانه';
      case ColorHarmony.splitComplementary:
        return 'مکمل تقسیم شده';
      case ColorHarmony.monochromatic:
        return 'یک‌رنگ';
      case ColorHarmony.mixed:
        return 'ترکیبی';
      case ColorHarmony.none:
        return 'هیچ';
    }
  }

  String get description {
    switch (this) {
      case ColorHarmony.complementary:
        return 'رنگ‌های مقابل هم در چرخه رنگ';
      case ColorHarmony.analogous:
        return 'رنگ‌های مجاور در چرخه رنگ';
      case ColorHarmony.triadic:
        return 'سه رنگ با فاصله یکسان در چرخه رنگ';
      case ColorHarmony.tetradic:
        return 'چهار رنگ با فاصله یکسان در چرخه رنگ';
      case ColorHarmony.splitComplementary:
        return 'یک رنگ با دو رنگ مجاور مکملش';
      case ColorHarmony.monochromatic:
        return 'تنوع در روشنایی یک رنگ';
      case ColorHarmony.mixed:
        return 'ترکیب چندین طرح هارمونیک';
      case ColorHarmony.none:
        return 'بدون طرح هارمونیک مشخص';
    }
  }
}

extension ColorTemperatureExtension on ColorTemperature {
  String get persianName {
    switch (this) {
      case ColorTemperature.veryWarm:
        return 'بسیار گرم';
      case ColorTemperature.warm:
        return 'گرم';
      case ColorTemperature.neutral:
        return 'خنثی';
      case ColorTemperature.cool:
        return 'سرد';
      case ColorTemperature.veryCool:
        return 'بسیار سرد';
    }
  }

  String get description {
    switch (this) {
      case ColorTemperature.veryWarm:
        return 'قرمز و نارنجی غالب';
      case ColorTemperature.warm:
        return 'رنگ‌های گرم غالب';
      case ColorTemperature.neutral:
        return 'تعادل بین رنگ‌های گرم و سرد';
      case ColorTemperature.cool:
        return 'رنگ‌های سرد غالب';
      case ColorTemperature.veryCool:
        return 'آبی و بنفش غالب';
    }
  }
}

// کلاس‌های کمکی برای محاسبات پیشرفته
class ColorMath {
  // محاسبه فاصله Delta E
  static double deltaE(Color color1, Color color2) {
    // تبدیل به LAB color space و محاسبه فاصله
    // این یک پیاده‌سازی ساده است
    final r1 = color1.red / 255.0;
    final g1 = color1.green / 255.0;
    final b1 = color1.blue / 255.0;

    final r2 = color2.red / 255.0;
    final g2 = color2.green / 255.0;
    final b2 = color2.blue / 255.0;

    return math.sqrt(
        math.pow(r2 - r1, 2) * 0.3 +
            math.pow(g2 - g1, 2) * 0.59 +
            math.pow(b2 - b1, 2) * 0.11
    );
  }

  // محاسبه vibrance
  static double calculateVibrance(List<ColorData> colors) {
    double totalSaturation = 0;
    for (final color in colors) {
      totalSaturation += color.hsvColor.saturation * color.percentage;
    }
    return totalSaturation / 100;
  }

  // تعیین mood بر اساس رنگ‌ها
  static String determineMood(List<ColorData> colors, ColorTemperature temperature) {
    final dominantHue = colors.first.hsvColor.hue;
    final averageSaturation = colors.fold(0.0, (sum, color) => sum + color.hsvColor.saturation) / colors.length;
    final averageBrightness = colors.fold(0.0, (sum, color) => sum + color.hsvColor.value) / colors.length;

    if (averageBrightness > 0.8 && averageSaturation > 0.6) {
      return 'شاد و پر انرژی';
    } else if (averageBrightness < 0.3) {
      return 'آرام و مرموز';
    } else if (temperature == ColorTemperature.warm) {
      return 'گرم و دلپذیر';
    } else if (temperature == ColorTemperature.cool) {
      return 'سرد و آرامش‌بخش';
    } else {
      return 'متعادل و طبیعی';
    }
  }
}