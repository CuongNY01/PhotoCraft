import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const SettingsScreen({super.key, required this.onDataChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  String _apiStatusMessage = 'Chưa kiểm tra';
  bool _isCheckingApi = false;
  bool _apiSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.instance.baseUrl);
    ApiService.instance.serverUrlNotifier.addListener(_onUrlChanged);
    _testConnection();
  }

  void _onUrlChanged() {
    if (mounted && _urlController.text != ApiService.instance.baseUrl) {
      _urlController.text = ApiService.instance.baseUrl;
    }
  }

  @override
  void dispose() {
    ApiService.instance.serverUrlNotifier.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _autoDiscoverWifi() async {
    setState(() {
      _isCheckingApi = true;
      _apiStatusMessage = 'Đang quét tự động mạng Wi-Fi...';
    });
    final success = await ApiService.instance.autoDiscoverServer();
    if (mounted) {
      _urlController.text = ApiService.instance.baseUrl;
      setState(() {
        _isCheckingApi = false;
        _apiSuccess = success;
        _apiStatusMessage = success
            ? '✓ Đã tìm thấy và kết nối máy chủ: ${ApiService.instance.baseUrl}'
            : '✗ Không tìm thấy máy chủ tự động trên dải mạng Wi-Fi.';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isCheckingApi = true;
      _apiStatusMessage = 'Đang kiểm tra kết nối...';
    });
    ApiService.instance.baseUrl = _urlController.text;
    final res = await ApiService.instance.checkHealth();
    if (mounted) {
      setState(() {
        _isCheckingApi = false;
        _apiSuccess = res['success'] == true;
        _apiStatusMessage = res['message'] as String;
      });
    }
  }

  Future<void> _resetSampleData() async {
    final db = await DBHelper.instance.database;
    await db.delete('photos');
    await DBHelper.instance.seedInitialDataIfEmpty();
    widget.onDataChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.accentGreen,
          content: Text('✓ Đã khôi phục dữ liệu mẫu ban đầu thành công!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt & Kết nối'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section: Python API Configuration
          const Text(
            'CẤU HÌNH PYTHON BACKEND API (OPENCV)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.accentCyan,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Địa chỉ máy chủ API:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, color: AppTheme.accentCyan),
                      onPressed: _testConnection,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick preset buttons
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Máy ảo Android (10.0.2.2)'),
                      backgroundColor: AppTheme.surfaceLight,
                      labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                      onPressed: () {
                        _urlController.text = 'http://10.0.2.2:8000';
                        _testConnection();
                      },
                    ),
                    ActionChip(
                      label: const Text('Localhost (127.0.0.1)'),
                      backgroundColor: AppTheme.surfaceLight,
                      labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                      onPressed: () {
                        _urlController.text = 'http://127.0.0.1:8000';
                        _testConnection();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Auto discover on Wi-Fi button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingApi ? null : _autoDiscoverWifi,
                    icon: const Icon(Icons.wifi_find, size: 18, color: AppTheme.accentCyan),
                    label: const Text(
                      'Tự động dò tìm máy chủ Wi-Fi',
                      style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accentCyan),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Test connection button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCheckingApi ? null : _testConnection,
                    icon: _isCheckingApi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                          )
                        : const Icon(Icons.wifi, size: 18),
                    label: const Text('Kiểm tra kết nối thủ công'),
                  ),
                ),
                const SizedBox(height: 10),

                // Status message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _apiSuccess
                        ? AppTheme.accentGreen.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _apiSuccess ? AppTheme.accentGreen : Colors.orange,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _apiSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: _apiSuccess ? AppTheme.accentGreen : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _apiStatusMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: _apiSuccess ? AppTheme.accentGreen : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Database Management
          const Text(
            'QUẢN LÝ DỮ LIỆU SQLITE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.accentCyan,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dữ liệu lịch sử, mục yêu thích và nhật ký ảnh được lưu trong bảng SQLite "photos".',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetSampleData,
                    icon: const Icon(Icons.restart_alt, size: 18, color: AppTheme.accentCyan),
                    label: const Text(
                      'Nạp lại dữ liệu mẫu (Reset & Seed)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.accentCyan),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accentCyan),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App Info
          Center(
            child: Column(
              children: const [
                Text(
                  'PhotoCraft • Phiên bản 1.0.0',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                SizedBox(height: 4),
                Text(
                  'Biên tập & nâng cao chất lượng ảnh trên di động',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
