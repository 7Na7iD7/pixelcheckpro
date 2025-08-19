import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/color_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorHistoryItem {
  final String id;
  final DateTime timestamp;
  final Color dominantColor;
  final double averageBrightness;
  final String brightnessDescription;
  final List<ColorData> colorPalette;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? filterType;
  final String? notes;

  ColorHistoryItem({
    required this.id,
    required this.timestamp,
    required this.dominantColor,
    required this.averageBrightness,
    required this.brightnessDescription,
    required this.colorPalette,
    this.imagePath,
    this.imageBytes,
    this.filterType,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'dominantColor': dominantColor.value,
      'averageBrightness': averageBrightness,
      'brightnessDescription': brightnessDescription,
      'colorPalette': colorPalette.map((e) => e.toJson()).toList(),
      'imagePath': imagePath,
      'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      'filterType': filterType,
      'notes': notes,
    };
  }

  factory ColorHistoryItem.fromJson(Map<String, dynamic> json) {
    return ColorHistoryItem(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      dominantColor: Color(json['dominantColor']),
      averageBrightness: json['averageBrightness'].toDouble(),
      brightnessDescription: json['brightnessDescription'],
      colorPalette: (json['colorPalette'] as List)
          .map((e) => ColorData.fromJson(e))
          .toList(),
      imagePath: json['imagePath'],
      imageBytes: json['imageBytes'] != null 
          ? base64Decode(json['imageBytes']) 
          : null,
      filterType: json['filterType'],
      notes: json['notes'],
    );
  }

  ColorHistoryItem copyWith({
    String? id,
    DateTime? timestamp,
    Color? dominantColor,
    double? averageBrightness,
    String? brightnessDescription,
    List<ColorData>? colorPalette,
    String? imagePath,
    Uint8List? imageBytes,
    String? filterType,
    String? notes,
  }) {
    return ColorHistoryItem(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      dominantColor: dominantColor ?? this.dominantColor,
      averageBrightness: averageBrightness ?? this.averageBrightness,
      brightnessDescription: brightnessDescription ?? this.brightnessDescription,
      colorPalette: colorPalette ?? this.colorPalette,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
      filterType: filterType ?? this.filterType,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ColorHistoryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ColorHistoryStorage {
  static const String _historyKey = 'color_analysis_history';
  static const String _favoritesKey = 'color_favorites';
  static const String _settingsKey = 'color_history_settings';
  static const int _maxHistoryItems = 100;

  static SharedPreferences? _prefs;

  // Initialize shared preferences
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Save a new color analysis to history
  static Future<bool> saveColorAnalysis({
    required Color dominantColor,
    required double averageBrightness,
    required String brightnessDescription,
    required List<ColorData> colorPalette,
    String? imagePath,
    Uint8List? imageBytes,
    String? filterType,
    String? notes,
  }) async {
    try {
      await init();
      
      final historyItem = ColorHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        dominantColor: dominantColor,
        averageBrightness: averageBrightness,
        brightnessDescription: brightnessDescription,
        colorPalette: colorPalette,
        imagePath: imagePath,
        imageBytes: imageBytes,
        filterType: filterType,
        notes: notes,
      );

      List<ColorHistoryItem> history = await getHistory();
      history.insert(0, historyItem);

      // Keep only the most recent items
      if (history.length > _maxHistoryItems) {
        history = history.take(_maxHistoryItems).toList();
      }

      final jsonList = history.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_historyKey, jsonString);
    } catch (e) {
      print('Error saving color analysis: $e');
      return false;
    }
  }

  // Get all history items
  static Future<List<ColorHistoryItem>> getHistory() async {
    try {
      await init();
      
      final jsonString = _prefs!.getString(_historyKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => ColorHistoryItem.fromJson(json)).toList();
    } catch (e) {
      print('Error getting history: $e');
      return [];
    }
  }

  // Get history items by date range
  static Future<List<ColorHistoryItem>> getHistoryByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final history = await getHistory();
    return history.where((item) {
      return item.timestamp.isAfter(startDate) && 
             item.timestamp.isBefore(endDate);
    }).toList();
  }

  // Get history items by filter type
  static Future<List<ColorHistoryItem>> getHistoryByFilter(String filterType) async {
    final history = await getHistory();
    return history.where((item) => item.filterType == filterType).toList();
  }

  // Search history by color similarity
  static Future<List<ColorHistoryItem>> searchByColor(
    Color searchColor, {
    double tolerance = 50.0,
  }) async {
    final history = await getHistory();
    return history.where((item) {
      final colorDistance = _calculateColorDistance(
        item.dominantColor, 
        searchColor,
      );
      return colorDistance <= tolerance;
    }).toList();
  }

  // Calculate color distance (simplified)
  static double _calculateColorDistance(Color color1, Color color2) {
    final r1 = color1.red;
    final g1 = color1.green;
    final b1 = color1.blue;
    final r2 = color2.red;
    final g2 = color2.green;
    final b2 = color2.blue;

    return ((r1 - r2) * (r1 - r2) + 
            (g1 - g2) * (g1 - g2) + 
            (b1 - b2) * (b1 - b2)).toDouble();
  }

  // Delete a history item
  static Future<bool> deleteHistoryItem(String id) async {
    try {
      await init();
      
      List<ColorHistoryItem> history = await getHistory();
      history.removeWhere((item) => item.id == id);

      final jsonList = history.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_historyKey, jsonString);
    } catch (e) {
      print('Error deleting history item: $e');
      return false;
    }
  }

  // Clear all history
  static Future<bool> clearHistory() async {
    try {
      await init();
      return await _prefs!.remove(_historyKey);
    } catch (e) {
      print('Error clearing history: $e');
      return false;
    }
  }

  // Update history item notes
  static Future<bool> updateHistoryItemNotes(String id, String notes) async {
    try {
      await init();
      
      List<ColorHistoryItem> history = await getHistory();
      final index = history.indexWhere((item) => item.id == id);
      
      if (index == -1) return false;
      
      history[index] = history[index].copyWith(notes: notes);

      final jsonList = history.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_historyKey, jsonString);
    } catch (e) {
      print('Error updating history item: $e');
      return false;
    }
  }

  // Favorites management
  static Future<List<String>> getFavorites() async {
    try {
      await init();
      return _prefs!.getStringList(_favoritesKey) ?? [];
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  static Future<bool> addToFavorites(String id) async {
    try {
      await init();
      
      List<String> favorites = await getFavorites();
      if (!favorites.contains(id)) {
        favorites.add(id);
        return await _prefs!.setStringList(_favoritesKey, favorites);
      }
      return true;
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }

  static Future<bool> removeFromFavorites(String id) async {
    try {
      await init();
      
      List<String> favorites = await getFavorites();
      favorites.remove(id);
      return await _prefs!.setStringList(_favoritesKey, favorites);
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  static Future<bool> isFavorite(String id) async {
    final favorites = await getFavorites();
    return favorites.contains(id);
  }

  static Future<List<ColorHistoryItem>> getFavoriteItems() async {
    final favorites = await getFavorites();
    final history = await getHistory();
    
    return history.where((item) => favorites.contains(item.id)).toList();
  }

  // Statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final history = await getHistory();
    
    if (history.isEmpty) {
      return {
        'totalAnalyses': 0,
        'averageBrightness': 0.0,
        'mostUsedFilter': 'هیچ',
        'colorDistribution': <String, int>{},
        'dailyUsage': <String, int>{},
        'weeklyUsage': <String, int>{},
      };
    }

    // Calculate statistics
    final totalAnalyses = history.length;
    final averageBrightness = history
        .map((item) => item.averageBrightness)
        .reduce((a, b) => a + b) / totalAnalyses;

    // Most used filter
    final filterCounts = <String, int>{};
    for (final item in history) {
      final filter = item.filterType ?? 'اصلی';
      filterCounts[filter] = (filterCounts[filter] ?? 0) + 1;
    }
    final mostUsedFilter = filterCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Color distribution (by brightness ranges)
    final colorDistribution = <String, int>{};
    for (final item in history) {
      final brightness = item.averageBrightness;
      String range;
      if (brightness < 0.3) {
        range = 'تیره';
      } else if (brightness < 0.7) {
        range = 'متوسط';
      } else {
        range = 'روشن';
      }
      colorDistribution[range] = (colorDistribution[range] ?? 0) + 1;
    }

    // Daily usage (last 7 days)
    final dailyUsage = <String, int>{};
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyUsage[dateKey] = 0;
    }
    
    for (final item in history) {
      final dateKey = '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')}';
      if (dailyUsage.containsKey(dateKey)) {
        dailyUsage[dateKey] = (dailyUsage[dateKey] ?? 0) + 1;
      }
    }

    // Weekly usage (last 4 weeks)
    final weeklyUsage = <String, int>{};
    for (int i = 0; i < 4; i++) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final weekKey = 'هفته ${i + 1}';
      weeklyUsage[weekKey] = 0;
    }

    for (final item in history) {
      final daysDiff = now.difference(item.timestamp).inDays;
      final weekIndex = daysDiff ~/ 7;
      if (weekIndex < 4) {
        final weekKey = 'هفته ${weekIndex + 1}';
        weeklyUsage[weekKey] = (weeklyUsage[weekKey] ?? 0) + 1;
      }
    }

    return {
      'totalAnalyses': totalAnalyses,
      'averageBrightness': averageBrightness,
      'mostUsedFilter': mostUsedFilter,
      'colorDistribution': colorDistribution,
      'dailyUsage': dailyUsage,
      'weeklyUsage': weeklyUsage,
    };
  }

  // Export history to JSON
  static Future<String> exportHistory() async {
    final history = await getHistory();
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'totalItems': history.length,
      'history': history.map((item) => item.toJson()).toList(),
    };
    
    return jsonEncode(exportData);
  }

  // Import history from JSON
  static Future<bool> importHistory(String jsonData) async {
    try {
      await init();
      
      final data = jsonDecode(jsonData);
      final importedHistory = (data['history'] as List)
          .map((json) => ColorHistoryItem.fromJson(json))
          .toList();

      // Merge with existing history
      final existingHistory = await getHistory();
      final mergedHistory = <ColorHistoryItem>[];
      
      // Add existing items
      mergedHistory.addAll(existingHistory);
      
      // Add imported items that don't already exist
      for (final item in importedHistory) {
        if (!mergedHistory.any((existing) => existing.id == item.id)) {
          mergedHistory.add(item);
        }
      }

      // Sort by timestamp (newest first)
      mergedHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Keep only the most recent items
      final finalHistory = mergedHistory.take(_maxHistoryItems).toList();

      final jsonList = finalHistory.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_historyKey, jsonString);
    } catch (e) {
      print('Error importing history: $e');
      return false;
    }
  }

  // Settings management
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      await init();
      
      final jsonString = _prefs!.getString(_settingsKey);
      if (jsonString == null) {
        return {
          'autoSave': true,
          'maxHistoryItems': _maxHistoryItems,
          'includeImages': true,
          'compressionQuality': 80,
          'sortOrder': 'newest',
        };
      }
      
      return jsonDecode(jsonString);
    } catch (e) {
      print('Error getting settings: $e');
      return {
        'autoSave': true,
        'maxHistoryItems': _maxHistoryItems,
        'includeImages': true,
        'compressionQuality': 80,
        'sortOrder': 'newest',
      };
    }
  }

  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      await init();
      
      final jsonString = jsonEncode(settings);
      return await _prefs!.setString(_settingsKey, jsonString);
    } catch (e) {
      print('Error updating settings: $e');
      return false;
    }
  }

  // Get storage info
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      await init();
      
      final history = await getHistory();
      final favorites = await getFavorites();
      
      int totalSize = 0;
      int imagesSize = 0;
      int imagesCount = 0;
      
      for (final item in history) {
        final itemJson = jsonEncode(item.toJson());
        totalSize += itemJson.length;
        
        if (item.imageBytes != null) {
          imagesSize += item.imageBytes!.length;
          imagesCount++;
        }
      }
      
      return {
        'totalItems': history.length,
        'favoritesCount': favorites.length,
        'totalSize': totalSize,
        'imagesSize': imagesSize,
        'imagesCount': imagesCount,
        'averageItemSize': history.isNotEmpty ? totalSize / history.length : 0,
      };
    } catch (e) {
      print('Error getting storage info: $e');
      return {
        'totalItems': 0,
        'favoritesCount': 0,
        'totalSize': 0,
        'imagesSize': 0,
        'imagesCount': 0,
        'averageItemSize': 0,
      };
    }
  }

  // Clean up old items
  static Future<bool> cleanupOldItems({int keepDays = 30}) async {
    try {
      await init();
      
      final history = await getHistory();
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      
      final filteredHistory = history.where((item) {
        return item.timestamp.isAfter(cutoffDate);
      }).toList();
      
      final jsonList = filteredHistory.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_historyKey, jsonString);
    } catch (e) {
      print('Error cleaning up old items: $e');
      return false;
    }
  }
}