import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/color_data.dart';
import '../core/image_utils.dart';


class ResultScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final ImageAnalysisResult analysisResult;

  const ResultScreen({
    Key? key,
    required this.imageBytes,
    required this.analysisResult,
  }) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with TickerProviderStateMixin {
  Uint8List? _filteredImage;
  String _currentFilter = 'اصلی';
  bool _isComparisonMode = false;
  bool _isProcessing = false;

  final List<Uint8List> _historyStack = [];
  final List<Uint8List> _redoStack = [];

  double _brightnessValue = 0.0;
  double _contrastValue = 1.0;
  double _saturationValue = 1.0;
  double _hueValue = 0.0;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _filteredImage = widget.imageBytes;

    _historyStack.add(widget.imageBytes);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _undo() {
    if (_historyStack.length > 1) {
      setState(() {
        final lastState = _historyStack.removeLast();
        _redoStack.add(lastState);
        _filteredImage = _historyStack.last;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        final nextState = _redoStack.removeLast();
        _historyStack.add(nextState);
        _filteredImage = nextState;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _applyFilter(String filterType) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _currentFilter = filterType;
    });

    HapticFeedback.lightImpact();

    await Future.delayed(Duration(milliseconds: 50));

    Uint8List? newImage;

    try {
      switch (filterType) {
        case 'منفی':
          newImage = ImageUtils.applyNegativeFilter(widget.imageBytes);
          break;
        case 'روشن':
          newImage = ImageUtils.applyBrightenFilter(widget.imageBytes, 50);
          break;
        case 'کنتراست':
          newImage = ImageUtils.applyContrastFilter(widget.imageBytes, 150);
          break;
        case 'سیاه و سفید':
          newImage = ImageUtils.applyGrayscaleFilter(widget.imageBytes);
          break;
        case 'سپیا':
          newImage = ImageUtils.applySepiaFilter(widget.imageBytes);
          break;
        default:
          newImage = widget.imageBytes;
      }

      if(newImage != null){
        setState(() {
          _filteredImage = newImage;
          _historyStack.add(newImage!);
          _redoStack.clear();
        });
      }

    } catch (e) {
      _filteredImage = _historyStack.last;
    }

    setState(() {
      _isProcessing = false;
    });
  }

  // lib/features/result_screen.dart

  void _applyCustomFilter() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _currentFilter = 'سفارشی';
    });

    try {
      // FIX: Added the 'imageBytes:' named parameter
      final newImage = await ImageUtils.applyCustomFilter(
        imageBytes: widget.imageBytes,
        brightness: _brightnessValue,
        contrast: _contrastValue,
        saturation: _saturationValue,
        hue: _hueValue,
      );
      setState(() {
        _filteredImage = newImage;
        _historyStack.add(newImage);
        _redoStack.clear();
      });

    } catch (e) {
      _filteredImage = _historyStack.last;
    }

    setState(() {
      _isProcessing = false;
    });
  }


  void _toggleComparisonMode() {
    setState(() {
      _isComparisonMode = !_isComparisonMode;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _exportImage() async {
    try {
      HapticFeedback.mediumImpact();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('در حال ذخیره...'),
            ],
          ),
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/pixelcheck_${DateTime.now().millisecondsSinceEpoch}.png';

      final file = File(imagePath);
      await file.writeAsBytes(_filteredImage!);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تصویر با موفقیت ذخیره شد'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ذخیره تصویر: $e'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _shareImage() async {
    try {
      HapticFeedback.mediumImpact();

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/pixelcheck_share.png';

      final file = File(imagePath);
      await file.writeAsBytes(_filteredImage!);

      await Share.shareXFiles([XFile(imagePath)], text: 'تحلیل رنگ با PixelCheck');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اشتراک‌گذاری: $e'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'نتیجه تحلیل',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.undo),
            onPressed: _historyStack.length > 1 ? _undo : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: Icon(Icons.redo),
            onPressed: _redoStack.isNotEmpty ? _redo : null,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: Icon(Icons.compare),
            onPressed: _toggleComparisonMode,
            tooltip: 'مقایسه قبل/بعد',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _exportImage();
              } else if (value == 'share') {
                _shareImage();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('ذخیره تصویر'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('اشتراک‌گذاری'),
                  ],
                ),
              ),
            ],
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _slideAnimation.value) * 50),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildImageFilterPage(),
                  _buildAnalysisPage(),
                  _buildChartPage(),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.tune),
            label: 'فیلترها',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'تحلیل',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'نمودار',
          ),
        ],
        selectedItemColor: Colors.blue[600],
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  Widget _buildImageFilterPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildImageSection(),
          _buildFilterControls(),
          _buildCustomFilterSliders(),
        ],
      ),
    );
  }

  Widget _buildAnalysisPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildColorAnalysisSection(),
          _buildColorPaletteSection(),
        ],
      ),
    );
  }

  Widget _buildChartPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPieChartSection(),
          _buildColorDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Hero(
            tag: 'image_preview',
            child: Container(
              height: _isComparisonMode ? 200 : 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _isComparisonMode
                    ? _buildComparisonView()
                    : _buildSingleImageView(),
              ),
            ),
          ),
          if (_isComparisonMode) ...[
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'اصلی',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  _currentFilter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          _buildFilterButtons(),
        ],
      ),
    );
  }

  Widget _buildSingleImageView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _filteredImage != null
              ? Image.memory(
            _filteredImage!,
            key: ValueKey(_filteredImage),
            fit: BoxFit.cover,
          )
              : CircularProgressIndicator(),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComparisonView() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white, width: 2),
              ),
            ),
            child: Image.memory(
              widget.imageBytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Expanded(
          child: _filteredImage != null
              ? Image.memory(
            _filteredImage!,
            fit: BoxFit.cover,
          )
              : Container(),
        ),
      ],
    );
  }

  Widget _buildFilterButtons() {
    final filters = ['اصلی', 'منفی', 'روشن', 'کنتراست', 'سیاه و سفید', 'سپیا'];

    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _currentFilter == filter;

          return Container(
            margin: EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: () => _applyFilter(filter),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue[600] : Colors.grey[200],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterControls() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  'کنترل فیلترها',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickFilterChip('اصلی', Icons.image),
                _buildQuickFilterChip('منفی', Icons.invert_colors),
                _buildQuickFilterChip('روشن', Icons.brightness_high),
                _buildQuickFilterChip('کنتراست', Icons.contrast),
                _buildQuickFilterChip('سیاه و سفید', Icons.filter_b_and_w),
                _buildQuickFilterChip('سپیا', Icons.gradient),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(String name, IconData icon) {
    final isSelected = _currentFilter == name;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: 4),
          Text(name),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => _applyFilter(name),
      selectedColor: Colors.blue[600],
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildCustomFilterSliders() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  'تنظیمات سفارشی',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            _buildSlider(
              'روشنایی',
              _brightnessValue,
              -100,
              100,
                  (value) {
                setState(() {
                  _brightnessValue = value;
                });
                _applyCustomFilter();
              },
              Icons.brightness_6,
            ),

            _buildSlider(
              'کنتراست',
              _contrastValue,
              0.5,
              2.0,
                  (value) {
                setState(() {
                  _contrastValue = value;
                });
                _applyCustomFilter();
              },
              Icons.contrast,
            ),

            _buildSlider(
              'اشباع رنگ',
              _saturationValue,
              0.0,
              2.0,
                  (value) {
                setState(() {
                  _saturationValue = value;
                });
                _applyCustomFilter();
              },
              Icons.colorize,
            ),

            _buildSlider(
              'رنگ',
              _hueValue,
              -180,
              180,
                  (value) {
                setState(() {
                  _hueValue = value;
                });
                _applyCustomFilter();
              },
              Icons.palette,
            ),

            SizedBox(height: 16),

            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _brightnessValue = 0.0;
                    _contrastValue = 1.0;
                    _saturationValue = 1.0;
                    _hueValue = 0.0;
                  });
                  _applyFilter('اصلی');
                },
                icon: Icon(Icons.restore),
                label: Text('بازنشانی'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
      String label,
      double value,
      double min,
      double max,
      ValueChanged<double> onChanged,
      IconData icon,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue[600],
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.blue[600],
            overlayColor: Colors.blue[600]!.withOpacity(0.2),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildColorAnalysisSection() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  'تحلیل رنگ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[50]!,
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: widget.analysisResult.dominantColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: widget.analysisResult.dominantColor.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رنگ غالب',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ColorData.colorToHex(widget.analysisResult.dominantColor),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        // --- FIX: Corrected typo from `brightnesDescription` ---
                        Text(
                          widget.analysisResult.brightnessDescription,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.brightness_6, color: Colors.orange[600]),
                      SizedBox(width: 8),
                      Text(
                        'میزان روشنایی:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(widget.analysisResult.averageBrightness * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  'توزیع رنگ‌ها',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            Container(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: widget.analysisResult.colorPalette.take(6).map((colorData) {
                    return PieChartSectionData(
                      color: colorData.color,
                      value: colorData.percentage,
                      title: '${colorData.percentage.toStringAsFixed(1)}%',
                      radius: 110,
                      titleStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 3,
                  centerSpaceRadius: 50,
                  startDegreeOffset: -90,
                ),
              ),
            ),

            SizedBox(height: 20),

            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: widget.analysisResult.colorPalette.take(6).map((colorData) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colorData.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${colorData.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDistributionChart() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  'توزیع رنگ‌ها (نموداری)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            ...widget.analysisResult.colorPalette.take(8).map((colorData) {
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: colorData.color,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              colorData.hexCode,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${colorData.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: colorData.percentage / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorData.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPaletteSection() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.color_lens, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  'پالت رنگی کامل',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widget.analysisResult.colorPalette.length,
              itemBuilder: (context, index) {
                final colorData = widget.analysisResult.colorPalette[index];
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: colorData.color,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                colorData.hexCode,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                '${colorData.percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}