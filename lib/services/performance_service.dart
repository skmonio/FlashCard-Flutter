import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import '../utils/app_logger.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Cache for expensive computations
  final Map<String, dynamic> _computationCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Debounce timers
  final Map<String, Timer> _debounceTimers = {};

  // Image cache
  final Map<String, ui.Image?> _imageCache = {};

  /// Clear all caches to free memory
  void clearAllCaches() {
    _computationCache.clear();
    _cacheTimestamps.clear();
    _imageCache.clear();

    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Clear Flutter's image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Get cached computation or compute and cache
  T? getCachedComputation<T>(String key, T Function() computation) {
    final now = DateTime.now();
    final timestamp = _cacheTimestamps[key];

    // Check if cache is expired
    if (timestamp != null && now.difference(timestamp) > _cacheExpiry) {
      _computationCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    // Return cached value if available
    if (_computationCache.containsKey(key)) {
      return _computationCache[key] as T?;
    }

    // Compute and cache
    try {
      final result = computation();
      _computationCache[key] = result;
      _cacheTimestamps[key] = now;
      return result;
    } catch (e) {
      AppLogger.log(
        'PerformanceService: Error computing cached value for key $key: $e',
      );
      return null;
    }
  }

  /// Debounce function calls
  void debounce(String key, VoidCallback callback, Duration delay) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
    });
  }

  /// Cancel a specific debounce timer
  void cancelDebounce(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
  }

  /// Optimize list performance with pagination
  List<T> paginateList<T>(List<T> list, int page, int pageSize) {
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, list.length);

    if (startIndex >= list.length) {
      return [];
    }

    return list.sublist(startIndex, endIndex);
  }

  /// Optimize search with fuzzy matching
  List<T> fuzzySearch<T>(
    List<T> items,
    String query,
    String Function(T) getSearchableText, {
    int maxResults = 50,
  }) {
    if (query.isEmpty) return items;

    final queryLower = query.toLowerCase();
    final results = <T>[];

    for (final item in items) {
      if (results.length >= maxResults) break;

      final text = getSearchableText(item).toLowerCase();

      // Exact match gets highest priority
      if (text.contains(queryLower)) {
        results.add(item);
        continue;
      }

      // Fuzzy match for typos
      if (_fuzzyMatch(text, queryLower)) {
        results.add(item);
      }
    }

    return results;
  }

  /// Simple fuzzy matching algorithm
  bool _fuzzyMatch(String text, String query) {
    if (query.length > text.length) return false;

    int queryIndex = 0;
    for (int i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        queryIndex++;
      }
    }

    return queryIndex == query.length;
  }

  /// Optimize image loading
  Future<ui.Image?> loadImageOptimized(
    String url, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    // Check cache first
    if (_imageCache.containsKey(url)) {
      return _imageCache[url];
    }

    try {
      final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: maxWidth,
        targetHeight: maxHeight,
      );
      final frame = await codec.getNextFrame();

      // Cache the image
      _imageCache[url] = frame.image;

      return frame.image;
    } catch (e) {
      AppLogger.log('PerformanceService: Error loading image $url: $e');
      return null;
    }
  }

  /// Optimize text rendering
  TextPainter createOptimizedTextPainter(
    String text, {
    TextStyle? style,
    TextDirection textDirection = TextDirection.ltr,
    double? maxWidth,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      maxLines: maxWidth != null ? null : 1,
    );
  }

  /// Optimize list view with automatic item height calculation
  double estimateListItemHeight({
    required double baseHeight,
    required int itemCount,
    double? maxHeight,
  }) {
    final estimatedHeight = baseHeight * itemCount;
    if (maxHeight != null && estimatedHeight > maxHeight) {
      return maxHeight;
    }
    return estimatedHeight;
  }

  /// Optimize animations with reduced motion support
  Duration getOptimizedAnimationDuration(Duration baseDuration) {
    final context = navigatorKey.currentContext;
    if (context == null) return baseDuration;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.accessibleNavigation == true) {
      return Duration(
        milliseconds: (baseDuration.inMilliseconds * 0.5).round(),
      );
    }
    return baseDuration;
  }

  /// Optimize memory usage by limiting list sizes
  List<T> limitListSize<T>(List<T> list, int maxSize) {
    if (list.length <= maxSize) return list;
    return list.take(maxSize).toList();
  }

  /// Optimize string operations
  String optimizeString(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Get memory usage information
  Map<String, dynamic> getMemoryInfo() {
    return {
      'computationCacheSize': _computationCache.length,
      'imageCacheSize': _imageCache.length,
      'debounceTimersCount': _debounceTimers.length,
      'cacheEntries': _cacheTimestamps.length,
    };
  }

  /// Optimize widget rebuilds with automatic key generation
  Key generateOptimizedKey(String baseKey, [Object? additionalData]) {
    return ValueKey(
      '${baseKey}_${additionalData ?? DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Optimize scroll performance
  ScrollController createOptimizedScrollController({
    bool keepScrollOffset = true,
    String? debugLabel,
  }) {
    return ScrollController(
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }

  /// Optimize list view builder with automatic item count estimation
  int estimateItemCount(int actualCount, {int maxEstimate = 1000}) {
    return actualCount.clamp(0, maxEstimate);
  }

  /// Optimize search with indexing
  Map<String, List<int>> createSearchIndex<T>(
    List<T> items,
    String Function(T) getSearchableText,
  ) {
    final index = <String, List<int>>{};

    for (int i = 0; i < items.length; i++) {
      final text = getSearchableText(items[i]).toLowerCase();
      final words = text.split(' ');

      for (final word in words) {
        if (word.length < 2) continue; // Skip very short words

        if (!index.containsKey(word)) {
          index[word] = [];
        }
        index[word]!.add(i);
      }
    }

    return index;
  }

  /// Optimize search using pre-built index
  List<T> searchWithIndex<T>(
    List<T> items,
    Map<String, List<int>> index,
    String query,
  ) {
    if (query.isEmpty) return items;

    final queryWords = query.toLowerCase().split(' ');
    final matchingIndices = <int>{};

    for (final word in queryWords) {
      if (word.length < 2) continue;

      final indices = index[word];
      if (indices != null) {
        matchingIndices.addAll(indices);
      }
    }

    return matchingIndices.map((index) => items[index]).toList();
  }

  /// Optimize color calculations
  Color optimizeColor(Color color, {double opacity = 1.0}) {
    if (opacity == 1.0) return color;
    return color.withValues(alpha: (color.alpha * opacity).round().toDouble());
  }

  /// Optimize date formatting with caching
  String formatDateOptimized(DateTime date, String format) {
    final cacheKey = '${date.millisecondsSinceEpoch}_$format';
    return getCachedComputation(cacheKey, () {
          // This would use a date formatting library
          return '${date.day}/${date.month}/${date.year}';
        }) ??
        '${date.day}/${date.month}/${date.year}';
  }

  /// Optimize number formatting
  String formatNumberOptimized(num number, {int decimalPlaces = 2}) {
    return number.toStringAsFixed(decimalPlaces);
  }

  /// Optimize list sorting with memoization
  List<T> sortOptimized<T>(
    List<T> list,
    int Function(T, T) compare, {
    String? cacheKey,
  }) {
    if (cacheKey != null) {
      return getCachedComputation(cacheKey, () {
            final sorted = List<T>.from(list);
            sorted.sort(compare);
            return sorted;
          }) ??
          list;
    }

    final sorted = List<T>.from(list);
    sorted.sort(compare);
    return sorted;
  }

  /// Optimize list filtering with memoization
  List<T> filterOptimized<T>(
    List<T> list,
    bool Function(T) test, {
    String? cacheKey,
  }) {
    if (cacheKey != null) {
      return getCachedComputation(cacheKey, () {
            return list.where(test).toList();
          }) ??
          list;
    }

    return list.where(test).toList();
  }

  /// Optimize map operations
  Map<K, V> mapOptimized<K, V, T>(
    List<T> list,
    MapEntry<K, V> Function(T) convert, {
    String? cacheKey,
  }) {
    if (cacheKey != null) {
      return getCachedComputation(cacheKey, () {
            return Map.fromEntries(list.map(convert));
          }) ??
          {};
    }

    return Map.fromEntries(list.map(convert));
  }

  /// Optimize reduce operations
  T reduceOptimized<T>(
    List<T> list,
    T Function(T, T) combine, {
    String? cacheKey,
  }) {
    if (cacheKey != null) {
      return getCachedComputation(cacheKey, () {
            return list.reduce(combine);
          }) ??
          list.first;
    }

    return list.reduce(combine);
  }

  /// Optimize image precaching
  Future<void> precacheOptimizedImage(
    BuildContext context,
    String imagePath,
  ) async {
    try {
      await precacheImage(AssetImage(imagePath), context);
    } catch (e) {
      AppLogger.log(
        'PerformanceService: Error precaching image $imagePath: $e',
      );
    }
  }

  /// Optimize network image precaching
  Future<void> precacheOptimizedNetworkImage(
    BuildContext context,
    String imageUrl,
  ) async {
    try {
      await precacheImage(NetworkImage(imageUrl), context);
    } catch (e) {
      AppLogger.log(
        'PerformanceService: Error precaching network image $imageUrl: $e',
      );
    }
  }

  /// Optimize file image precaching
  Future<void> precacheOptimizedFileImage(
    BuildContext context,
    String filePath,
  ) async {
    if (kIsWeb) return;
    try {
      await precacheImage(FileImage(File(filePath)), context);
    } catch (e) {
      AppLogger.log(
        'PerformanceService: Error precaching file image $filePath: $e',
      );
    }
  }

  /// Optimize memory image precaching
  Future<void> precacheOptimizedMemoryImage(
    BuildContext context,
    Uint8List bytes,
  ) async {
    try {
      await precacheImage(MemoryImage(bytes), context);
    } catch (e) {
      AppLogger.log('PerformanceService: Error precaching memory image: $e');
    }
  }

  /// Initialize the performance service
  void initialize() {
    // Initialize performance optimizations
    clearAllCaches();
    AppLogger.log(
      'PerformanceService: Initialized with performance optimizations',
    );
  }
}

// Global navigator key for performance service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
