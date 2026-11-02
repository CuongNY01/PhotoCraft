import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/photo_record.dart';
import '../services/api_service.dart';
import '../services/image_processor.dart';
import '../theme/app_theme.dart';
import '../widgets/save_diary_sheet.dart';

enum DragHandle { none, topLeft, topRight, bottomLeft, bottomRight, center }

class EditorScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;
  final String title;
  final PhotoRecord? existingRecord;
  final VoidCallback onSaved;

  const EditorScreen({
    super.key,
    this.initialImageBytes,
    this.title = 'Hoàng hôn ven biển',
    this.existingRecord,
    required this.onSaved,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Uint8List _originalBytes;
  Uint8List? _currentBytes;
  bool _isProcessing = false;
  String _activeTitle = 'Hoàng hôn ven biển';
  PhotoRecord? _activeRecord;

  // History stack for "Đặt lại" (Undo last step)
  final List<Uint8List> _historyStack = [];

  // Active sub-tab: 0: Crop/Rotate/Flip, 1: Color Filters, 2: Sharpening
  int _activeTab = 0; // Default to Tab 0 (Crop/Rotate) when entering editor

  // Filter state
  String _selectedFilterId = 'grayscale';
  String _selectedFilterName = 'Trắng đen';
  double _filterIntensity = 0.70; // 70% matching mockup

  // Sharpening state
  String _selectedSharpenMethod = 'unsharp_mask';
  String _selectedSharpenName = 'Unsharp Mask (USM)';
  double _sharpenStrength = 1.5;

  // Aspect ratio and interactive crop state
  String _selectedAspect = 'Tự do';
  double? _targetAspectRatio;
  bool _showGrid = true;
  Rect _normalizedCrop = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
  DragHandle _activeHandle = DragHandle.none;
  int _imgPixelWidth = 1000;
  int _imgPixelHeight = 1000;

  final List<Map<String, dynamic>> _filters = [
    {'id': 'original', 'name': 'Gốc', 'icon': Icons.image},
    {'id': 'grayscale', 'name': 'Trắng đen', 'icon': Icons.tonality},
    {'id': 'sepia', 'name': 'Sepia', 'icon': Icons.history_edu},
    {'id': 'vivid_hdr', 'name': 'vivi HDR', 'icon': Icons.auto_awesome},
    {'id': 'vintage', 'name': 'Màu 1', 'icon': Icons.movie_filter},
    {'id': 'cool', 'name': 'Màu 2', 'icon': Icons.ac_unit},
    {'id': 'pencil', 'name': 'Tranh chì', 'icon': Icons.brush},
    {'id': 'emboss', 'name': 'Chạm nổi', 'icon': Icons.layers},
    {'id': 'invert', 'name': 'Âm bản', 'icon': Icons.invert_colors},
  ];

  final List<Map<String, dynamic>> _sharpenMethods = [
    {'id': 'kernel_3x3', 'name': 'Kernel 3x3', 'desc': 'Tích chập không gian 3x3'},
    {'id': 'unsharp_mask', 'name': 'Unsharp Mask (USM)', 'desc': 'Mặt nạ làm mờ Gaussian'},
    {'id': 'high_boost', 'name': 'High-Boost Filter', 'desc': 'Khuếch đại tần số cao'},
    {'id': 'clahe', 'name': 'CLAHE Contrast', 'desc': 'Cân bằng độ sáng thích ứng'},
  ];

  @override
  void initState() {
    super.initState();
    _activeTitle = widget.title;
    _activeRecord = widget.existingRecord;
    if (widget.initialImageBytes != null) {
      _originalBytes = widget.initialImageBytes!;
      _currentBytes = widget.initialImageBytes!;
      _updateImageDimensions();
    } else {
      _loadRecentOrSamplePhoto();
    }
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImageBytes != null && widget.initialImageBytes != oldWidget.initialImageBytes) {
      setState(() {
        _historyStack.clear();
        _originalBytes = widget.initialImageBytes!;
        _currentBytes = widget.initialImageBytes!;
        _activeTitle = widget.title;
        _activeRecord = widget.existingRecord;
      });
      _updateImageDimensions();
    }
  }

  /// Requirement 1: Nếu người dùng chưa tải ảnh lên, hiển thị ảnh được chỉnh sửa gần nhất
  Future<void> _loadRecentOrSamplePhoto() async {
    try {
      final recents = await DBHelper.instance.getRecentPhotos(limit: 1);
      if (recents.isNotEmpty) {
        final recent = recents.first;
        Uint8List? bytes;
        if (recent.editedPath.startsWith('assets/')) {
          final assetData = await rootBundle.load(recent.editedPath);
          bytes = assetData.buffer.asUint8List();
        } else if (!kIsWeb && File(recent.editedPath).existsSync()) {
          bytes = await File(recent.editedPath).readAsBytes();
        }
        if (bytes != null && mounted) {
          setState(() {
            _historyStack.clear();
            _originalBytes = bytes!;
            _currentBytes = bytes;
            _activeTitle = recent.title;
            _activeRecord = recent;
            _selectedFilterName = recent.filterApplied;
            _selectedSharpenName = recent.sharpenApplied;
          });
          _updateImageDimensions();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading recent photo for editor: $e');
    }

    // Fallback nếu cơ sở dữ liệu chưa có ảnh nào
    final assetData = await rootBundle.load('assets/samples/sunset.jpg');
    final bytes = assetData.buffer.asUint8List();
    if (mounted) {
      setState(() {
        _historyStack.clear();
        _originalBytes = bytes;
        _currentBytes = bytes;
        _activeTitle = 'Hoàng hôn biển';
      });
      _updateImageDimensions();
    }
  }

  /// Update intrinsic image dimensions asynchronously
  void _updateImageDimensions() {
    if (_currentBytes == null) return;
    decodeImageFromList(_currentBytes!).then((decoded) {
      if (mounted) {
        setState(() {
          _imgPixelWidth = decoded.width;
          _imgPixelHeight = decoded.height;
          _resetCropBox();
        });
      }
    });
  }

  void _resetCropBox() {
    if (_targetAspectRatio == null) {
      _normalizedCrop = const Rect.fromLTWH(0.05, 0.05, 0.90, 0.90);
    } else {
      _adjustCropToRatio(_targetAspectRatio!);
    }
  }

  void _adjustCropToRatio(double targetRatio) {
    if (_imgPixelWidth <= 0 || _imgPixelHeight <= 0) return;
    double normW = 0.88;
    double normH = normW / ((_imgPixelHeight / _imgPixelWidth) * targetRatio);

    if (normH > 0.88) {
      normH = 0.88;
      normW = normH * (_imgPixelHeight / _imgPixelWidth) * targetRatio;
    }

    final double left = (1.0 - normW) / 2;
    final double top = (1.0 - normH) / 2;

    setState(() {
      _normalizedCrop = Rect.fromLTWH(
        left.clamp(0.0, 1.0),
        top.clamp(0.0, 1.0),
        normW.clamp(0.08, 1.0),
        normH.clamp(0.08, 1.0),
      );
    });
  }

  void _selectAspectRatio(String name, double? ratio) {
    setState(() {
      _selectedAspect = name;
      _targetAspectRatio = ratio;
      _resetCropBox();
    });
    if (ratio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✂️ Cắt tự do: Bạn có thể kéo chỉnh 4 góc khung cắt tuỳ ý'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _applyCrop() {
    if (_currentBytes == null) return;
    _pushHistory();

    final cropped = ImageProcessor.cropNormalized(
      _currentBytes!,
      left: _normalizedCrop.left,
      top: _normalizedCrop.top,
      width: _normalizedCrop.width,
      height: _normalizedCrop.height,
    );

    setState(() {
      _currentBytes = cropped;
    });

    _updateImageDimensions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.accentCyan,
        content: Text(
          '✓ Đã cắt ảnh thành công ($_selectedAspect)',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Push state before any destructive action
  void _pushHistory() {
    if (_currentBytes != null) {
      _historyStack.add(Uint8List.fromList(_currentBytes!));
      if (_historyStack.length > 20) {
        _historyStack.removeAt(0); // Giữ tối đa 20 bước lịch sử để tiết kiệm RAM
      }
    }
  }

  /// Requirement 1: Nút "Đặt lại" quay lại bước trước đó (Undo step)
  void _undoStep() {
    if (_historyStack.isEmpty) return;
    final prevState = _historyStack.removeLast();
    setState(() {
      _currentBytes = prevState;
    });
    _updateImageDimensions();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('↩ Đã quay lại bước trước đó (${_historyStack.length} bước còn lại)'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Requirement 1: Nút "Khôi phục" khôi phục ảnh gốc ban đầu (thay thế nút đặt lại cũ)
  void _restoreOriginal() {
    if (_currentBytes == null) return;
    _pushHistory();
    setState(() {
      _currentBytes = Uint8List.fromList(_originalBytes);
      _selectedFilterId = 'original';
      _selectedFilterName = 'Gốc';
      _filterIntensity = 0.70;
    });
    _updateImageDimensions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Đã khôi phục về ảnh gốc ban đầu'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _applyFilterApi() async {
    if (_currentBytes == null) return;
    _pushHistory();
    setState(() => _isProcessing = true);

    try {
      final result = await ApiService.instance.applyFilter(
        imageBytes: _originalBytes,
        filterType: _selectedFilterId,
        intensity: _filterIntensity,
      );
      if (mounted) {
        setState(() {
          _currentBytes = result;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentCyan,
            content: Text(
              '✓ Đã áp dụng bộ lọc "$_selectedFilterName" qua Python API (OpenCV)',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      // Fallback locally if backend is unreachable
      debugPrint('API filter failed, using fallback: $e');
      final fallback = ImageProcessor.applyFallbackFilter(
        _originalBytes,
        _selectedFilterId,
        _filterIntensity,
      );
      if (mounted) {
        setState(() {
          _currentBytes = fallback;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              'API chưa kết nối. Đã áp dụng bộ lọc cục bộ ($e)',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _applySharpenApi() async {
    if (_currentBytes == null) return;
    _pushHistory();
    setState(() => _isProcessing = true);

    try {
      final result = await ApiService.instance.applySharpen(
        imageBytes: _currentBytes!,
        method: _selectedSharpenMethod,
        strength: _sharpenStrength,
      );
      if (mounted) {
        setState(() {
          _currentBytes = result;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentGreen,
            content: Text(
              '✓ Đã làm nét bằng "$_selectedSharpenName" qua Python API (OpenCV)',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentPink,
            content: Text('Lỗi làm nét API: $e'),
          ),
        );
      }
    }
  }

  void _rotateImage(int degrees) {
    if (_currentBytes == null) return;
    _pushHistory();
    final res = ImageProcessor.rotate(_currentBytes!, degrees);
    setState(() {
      _currentBytes = res;
    });
    _updateImageDimensions();
  }

  void _flipImageHorizontal() {
    if (_currentBytes == null) return;
    _pushHistory();
    final res = ImageProcessor.flipHorizontal(_currentBytes!);
    setState(() {
      _currentBytes = res;
    });
    _updateImageDimensions();
  }

  void _flipImageVertical() {
    if (_currentBytes == null) return;
    _pushHistory();
    final res = ImageProcessor.flipVertical(_currentBytes!);
    setState(() {
      _currentBytes = res;
    });
    _updateImageDimensions();
  }

  void _openSaveSheet() {
    if (_currentBytes == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SaveDiarySheet(
          imageBytes: _currentBytes!,
          initialTitle: _activeTitle,
          filterApplied: _selectedFilterName,
          sharpenApplied: _selectedSharpenName,
          existingRecord: _activeRecord,
        );
      },
    ).then((saved) {
      if (saved == true) {
        widget.onSaved();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentBytes == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Text(
          _activeTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Nút "Đặt lại" (Quay lại bước trước đó - Undo)
          TextButton.icon(
            onPressed: _historyStack.isNotEmpty ? _undoStep : null,
            icon: Icon(
              Icons.undo,
              size: 15,
              color: _historyStack.isNotEmpty
                  ? AppTheme.accentCyan
                  : AppTheme.textSecondary.withValues(alpha: 0.35),
            ),
            label: Text(
              'Đặt lại',
              style: TextStyle(
                color: _historyStack.isNotEmpty
                    ? AppTheme.accentCyan
                    : AppTheme.textSecondary.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          // Nút "Khôi phục" (Khôi phục ảnh gốc ban đầu)
          TextButton.icon(
            onPressed: _restoreOriginal,
            icon: const Icon(Icons.refresh, size: 15, color: AppTheme.textSecondary),
            label: const Text(
              'Khôi phục',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          // Nút "Lưu"
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openSaveSheet,
              icon: const Text('💾', style: TextStyle(fontSize: 13)),
              label: const Text('Lưu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main Image Viewport with Interactive Crop Overlay
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewW = constraints.maxWidth;
                    final viewH = constraints.maxHeight;

                    // Calculate image placement within viewport (BoxFit.contain)
                    final double imgW = _imgPixelWidth > 0 ? _imgPixelWidth.toDouble() : 1000.0;
                    final double imgH = _imgPixelHeight > 0 ? _imgPixelHeight.toDouble() : 1000.0;
                    final double scale = math.min(viewW / imgW, viewH / imgH);
                    final double dispW = imgW * scale;
                    final double dispH = imgH * scale;
                    final double dispLeft = (viewW - dispW) / 2;
                    final double dispTop = (viewH - dispH) / 2;
                    final Rect imageRect = Rect.fromLTWH(dispLeft, dispTop, dispW, dispH);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_activeTab == 0)
                          // In Crop mode: positioned image with interactive crop overlay on top
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                left: dispLeft,
                                top: dispTop,
                                width: dispW,
                                height: dispH,
                                child: Image.memory(
                                  _currentBytes!,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              _buildCropGestureOverlay(imageRect, viewW, viewH),
                            ],
                          )
                        else
                          // In Filter or Sharpen mode: Interactive zoomable image
                          InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.memory(
                                _currentBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                        if (_isProcessing)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircularProgressIndicator(color: AppTheme.accentCyan),
                                  SizedBox(height: 12),
                                  Text(
                                    'Đang xử lý qua Python API (OpenCV)...',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // 3 Tool Tabs: Cắt / Xoay / Lật | Bộ lọc màu (Filter) | Làm nét
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.dividerColor)),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  index: 0,
                  icon: '✂️',
                  label: 'Cắt / Xoay',
                ),
                _buildTabButton(
                  index: 1,
                  icon: '🎨',
                  label: 'Bộ lọc màu',
                ),
                _buildTabButton(
                  index: 2,
                  icon: '✨',
                  label: 'Làm nét',
                ),
              ],
            ),
          ),

          // Tool Controls Panel according to active tab
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: _buildActiveControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String icon,
    required String label,
  }) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.accentCyan : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveControls() {
    switch (_activeTab) {
      case 0:
        return _buildCropRotateControls();
      case 1:
        return _buildFilterControls();
      case 2:
        return _buildSharpenControls();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCropGestureOverlay(Rect imageRect, double viewW, double viewH) {
    final screenCropRect = Rect.fromLTWH(
      imageRect.left + _normalizedCrop.left * imageRect.width,
      imageRect.top + _normalizedCrop.top * imageRect.height,
      _normalizedCrop.width * imageRect.width,
      _normalizedCrop.height * imageRect.height,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _onCropPanStart(details.localPosition, screenCropRect);
      },
      onPanUpdate: (details) {
        _onCropPanUpdate(details.delta, details.localPosition, imageRect, screenCropRect);
      },
      onPanEnd: (_) {
        setState(() {
          _activeHandle = DragHandle.none;
        });
      },
      onPanCancel: () {
        setState(() {
          _activeHandle = DragHandle.none;
        });
      },
      child: CustomPaint(
        size: Size(viewW, viewH),
        painter: CropFramePainter(
          cropRect: screenCropRect,
          showGrid: _showGrid,
          activeHandle: _activeHandle,
        ),
      ),
    );
  }

  void _onCropPanStart(Offset pos, Rect cropRect) {
    const double hitRadius = 38.0;

    if ((pos - cropRect.topLeft).distance <= hitRadius) {
      _activeHandle = DragHandle.topLeft;
    } else if ((pos - cropRect.topRight).distance <= hitRadius) {
      _activeHandle = DragHandle.topRight;
    } else if ((pos - cropRect.bottomLeft).distance <= hitRadius) {
      _activeHandle = DragHandle.bottomLeft;
    } else if ((pos - cropRect.bottomRight).distance <= hitRadius) {
      _activeHandle = DragHandle.bottomRight;
    } else if (cropRect.contains(pos)) {
      _activeHandle = DragHandle.center;
    } else {
      _activeHandle = DragHandle.none;
    }
    setState(() {});
  }

  void _onCropPanUpdate(
    Offset delta,
    Offset currentPos,
    Rect imageRect,
    Rect screenCropRect,
  ) {
    if (_activeHandle == DragHandle.none) return;

    final double dNormX = delta.dx / imageRect.width;
    final double dNormY = delta.dy / imageRect.height;

    double left = _normalizedCrop.left;
    double top = _normalizedCrop.top;
    double right = _normalizedCrop.right;
    double bottom = _normalizedCrop.bottom;
    const double minNormSize = 0.08;

    if (_activeHandle == DragHandle.center) {
      final double w = _normalizedCrop.width;
      final double h = _normalizedCrop.height;
      left = (left + dNormX).clamp(0.0, 1.0 - w);
      top = (top + dNormY).clamp(0.0, 1.0 - h);
      right = left + w;
      bottom = top + h;
    } else if (_targetAspectRatio == null) {
      // Free Crop (Cắt tự do) - 4 góc kéo chỉnh hoàn toàn độc lập theo ngón tay
      switch (_activeHandle) {
        case DragHandle.topLeft:
          left = (left + dNormX).clamp(0.0, right - minNormSize);
          top = (top + dNormY).clamp(0.0, bottom - minNormSize);
          break;
        case DragHandle.topRight:
          right = (right + dNormX).clamp(left + minNormSize, 1.0);
          top = (top + dNormY).clamp(0.0, bottom - minNormSize);
          break;
        case DragHandle.bottomLeft:
          left = (left + dNormX).clamp(0.0, right - minNormSize);
          bottom = (bottom + dNormY).clamp(top + minNormSize, 1.0);
          break;
        case DragHandle.bottomRight:
          right = (right + dNormX).clamp(left + minNormSize, 1.0);
          bottom = (bottom + dNormY).clamp(top + minNormSize, 1.0);
          break;
        default:
          break;
      }
    } else {
      // Khóa tỷ lệ khung hình đã chọn (1:1, 4:3, 16:9)
      final double ratio = _targetAspectRatio!;

      switch (_activeHandle) {
        case DragHandle.bottomRight:
          double newW = (currentPos.dx - screenCropRect.left).clamp(
            40.0,
            imageRect.right - screenCropRect.left,
          );
          double newH = newW / ratio;
          if (screenCropRect.top + newH > imageRect.bottom) {
            newH = imageRect.bottom - screenCropRect.top;
            newW = newH * ratio;
          }
          right = (screenCropRect.left + newW - imageRect.left) / imageRect.width;
          bottom = (screenCropRect.top + newH - imageRect.top) / imageRect.height;
          break;

        case DragHandle.bottomLeft:
          double newW = (screenCropRect.right - currentPos.dx).clamp(
            40.0,
            screenCropRect.right - imageRect.left,
          );
          double newH = newW / ratio;
          if (screenCropRect.top + newH > imageRect.bottom) {
            newH = imageRect.bottom - screenCropRect.top;
            newW = newH * ratio;
          }
          left = (screenCropRect.right - newW - imageRect.left) / imageRect.width;
          bottom = (screenCropRect.top + newH - imageRect.top) / imageRect.height;
          break;

        case DragHandle.topRight:
          double newW = (currentPos.dx - screenCropRect.left).clamp(
            40.0,
            imageRect.right - screenCropRect.left,
          );
          double newH = newW / ratio;
          if (screenCropRect.bottom - newH < imageRect.top) {
            newH = screenCropRect.bottom - imageRect.top;
            newW = newH * ratio;
          }
          right = (screenCropRect.left + newW - imageRect.left) / imageRect.width;
          top = (screenCropRect.bottom - newH - imageRect.top) / imageRect.height;
          break;

        case DragHandle.topLeft:
          double newW = (screenCropRect.right - currentPos.dx).clamp(
            40.0,
            screenCropRect.right - imageRect.left,
          );
          double newH = newW / ratio;
          if (screenCropRect.bottom - newH < imageRect.top) {
            newH = screenCropRect.bottom - imageRect.top;
            newW = newH * ratio;
          }
          left = (screenCropRect.right - newW - imageRect.left) / imageRect.width;
          top = (screenCropRect.bottom - newH - imageRect.top) / imageRect.height;
          break;

        default:
          break;
      }
    }

    setState(() {
      _normalizedCrop = Rect.fromLTRB(
        left.clamp(0.0, 1.0),
        top.clamp(0.0, 1.0),
        right.clamp(0.0, 1.0),
        bottom.clamp(0.0, 1.0),
      );
    });
  }

  // TAB 1: Cắt / Xoay / Lật
  Widget _buildCropRotateControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tỷ lệ khung hình:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            Row(
              children: [
                const Text('Lưới', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Switch(
                  value: _showGrid,
                  activeColor: AppTheme.accentCyan,
                  onChanged: (v) => setState(() => _showGrid = v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Aspect Ratio buttons: Tự do | 1:1 | 4:3 | 16:9
        Row(
          children: [
            _buildRatioChip('Tự do', null),
            const SizedBox(width: 8),
            _buildRatioChip('1:1 (Vuông)', 1.0),
            const SizedBox(width: 8),
            _buildRatioChip('4:3', 4.0 / 3.0),
            const SizedBox(width: 8),
            _buildRatioChip('16:9', 16.0 / 9.0),
          ],
        ),
        const SizedBox(height: 12),

        // Nút bấm xác nhận cắt ảnh
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _applyCrop,
            icon: const Icon(Icons.crop, size: 18),
            label: Text(
              _selectedAspect == 'Tự do'
                  ? '✓ Áp dụng cắt tự do'
                  : '✓ Áp dụng cắt ($_selectedAspect)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Rotate & Flip buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
              icon: Icons.rotate_left,
              label: 'Xoay trái 90°',
              onTap: () => _rotateImage(270),
            ),
            _buildActionButton(
              icon: Icons.rotate_right,
              label: 'Xoay phải 90°',
              onTap: () => _rotateImage(90),
            ),
            _buildActionButton(
              icon: Icons.flip,
              label: 'Lật ngang',
              onTap: _flipImageHorizontal,
            ),
            _buildActionButton(
              icon: Icons.swap_vert,
              label: 'Lật dọc',
              onTap: _flipImageVertical,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatioChip(String label, double? ratio) {
    final isSelected = _selectedAspect == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectAspectRatio(label, ratio),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentCyan.withValues(alpha: 0.25) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accentCyan : AppTheme.dividerColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.accentCyan : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.accentCyan, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // TAB 2: Bộ lọc màu (Filter) - Matching mockup page 1
  Widget _buildFilterControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title: Bộ lọc: Trắng đen
        Text(
          'Bộ lọc: $_selectedFilterName',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentCyan,
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal filter list
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final f = _filters[index];
              final isSelected = _selectedFilterId == f['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilterId = f['id'];
                    _selectedFilterName = f['name'];
                  });
                },
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentCyan : AppTheme.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : AppTheme.dividerColor,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      child: Icon(
                        f['icon'] as IconData,
                        color: isSelected ? Colors.black87 : Colors.white70,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f['name'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Intensity slider: Cường độ: 70%
        Row(
          children: [
            const Text(
              'Cường độ: ',
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.accentCyan,
                  inactiveTrackColor: AppTheme.cardColor,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _filterIntensity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => setState(() => _filterIntensity = val),
                ),
              ),
            ),
            SizedBox(
              width: 45,
              child: Text(
                '${(_filterIntensity * 100).toInt()}%',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Big button: 🚀 Áp dụng qua Python API (OpenCV)
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _applyFilterApi,
            icon: const Text('🚀', style: TextStyle(fontSize: 16)),
            label: const Text(
              'Áp dụng qua Python API (OpenCV)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // TAB 3: Làm nét (Sharpening)
  Widget _buildSharpenControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thuật toán làm nét: $_selectedSharpenName',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentGreen,
          ),
        ),
        const SizedBox(height: 10),

        // Sharpen method chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sharpenMethods.map((m) {
            final isSelected = _selectedSharpenMethod == m['id'];
            return ChoiceChip(
              label: Text(m['name']),
              selected: isSelected,
              selectedColor: AppTheme.accentGreen.withValues(alpha: 0.25),
              backgroundColor: AppTheme.cardColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.accentGreen : AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.accentGreen : AppTheme.dividerColor,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedSharpenMethod = m['id'];
                  _selectedSharpenName = m['name'];
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Strength Slider
        Row(
          children: [
            const Text(
              'Mức độ làm nét: ',
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.accentGreen,
                  inactiveTrackColor: AppTheme.cardColor,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: _sharpenStrength,
                  min: 0.2,
                  max: 3.0,
                  onChanged: (val) => setState(() => _sharpenStrength = val),
                ),
              ),
            ),
            SizedBox(
              width: 45,
              child: Text(
                _sharpenStrength.toStringAsFixed(1),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Big button: 🚀 Nâng cao chi tiết qua Python API (OpenCV)
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _applySharpenApi,
            icon: const Text('✨', style: TextStyle(fontSize: 16)),
            label: const Text(
              'Nâng cao chi tiết qua Python API (OpenCV)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CropFramePainter extends CustomPainter {
  final Rect cropRect;
  final bool showGrid;
  final DragHandle activeHandle;

  CropFramePainter({
    required this.cropRect,
    required this.showGrid,
    required this.activeHandle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cropRect.width <= 0 || cropRect.height <= 0) return;

    // 1. Dim translucent outer mask outside cropRect
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final maskPath = Path()
      ..addRect(fullRect)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );

    // 2. White clean border around crop frame
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, borderPaint);

    // 3. Rule of Thirds grid lines
    if (showGrid && cropRect.width > 24 && cropRect.height > 24) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.0;
      final gw = cropRect.width / 3;
      final gh = cropRect.height / 3;

      canvas.drawLine(
        Offset(cropRect.left + gw, cropRect.top),
        Offset(cropRect.left + gw, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left + gw * 2, cropRect.top),
        Offset(cropRect.left + gw * 2, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + gh),
        Offset(cropRect.right, cropRect.top + gh),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + gh * 2),
        Offset(cropRect.right, cropRect.top + gh * 2),
        gridPaint,
      );
    }

    // 4. L-shaped thick corner handles with white circular dots
    final cornerPaint = Paint()
      ..color = AppTheme.accentCyan
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double cornerLen = math.min(22.0, math.min(cropRect.width, cropRect.height) / 3);

    // Top-Left Handle
    canvas.drawLine(Offset(cropRect.left, cropRect.top + cornerLen), Offset(cropRect.left, cropRect.top), cornerPaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left + cornerLen, cropRect.top), cornerPaint);
    canvas.drawCircle(Offset(cropRect.left, cropRect.top), 4.0, dotPaint);

    // Top-Right Handle
    canvas.drawLine(Offset(cropRect.right - cornerLen, cropRect.top), Offset(cropRect.right, cropRect.top), cornerPaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right, cropRect.top + cornerLen), cornerPaint);
    canvas.drawCircle(Offset(cropRect.right, cropRect.top), 4.0, dotPaint);

    // Bottom-Left Handle
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom - cornerLen), Offset(cropRect.left, cropRect.bottom), cornerPaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left + cornerLen, cropRect.bottom), cornerPaint);
    canvas.drawCircle(Offset(cropRect.left, cropRect.bottom), 4.0, dotPaint);

    // Bottom-Right Handle
    canvas.drawLine(Offset(cropRect.right - cornerLen, cropRect.bottom), Offset(cropRect.right, cropRect.bottom), cornerPaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right, cropRect.bottom - cornerLen), cornerPaint);
    canvas.drawCircle(Offset(cropRect.right, cropRect.bottom), 4.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CropFramePainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.activeHandle != activeHandle;
  }
}
