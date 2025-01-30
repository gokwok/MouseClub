import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../painters/grid_painter.dart';

// 配置管理器
class ConfigManager {
  static Future<ConfigManager> getInstance() async {
    if (_instance == null) {
      _instance = ConfigManager._internal();
      await _instance!._loadConfig();
    }
    return _instance!;
  }

  static ConfigManager? _instance;

  // 私有构造函数
  ConfigManager._internal();

  // 默认配置
  static const Map<String, dynamic> _defaultConfig = {
    'comfyuiAddress': '114.55.173.20:8090/api',
  };

  // 当前配置
  Map<String, dynamic> _currentConfig = Map.from(_defaultConfig);

  // 临时配置（未保存）
  Map<String, dynamic> _tempConfig = {};

  // 从 localStorage 加载配置
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedConfig = prefs.getString('appConfig');
      if (savedConfig != null) {
        final Map<String, dynamic> loadedConfig = json.decode(savedConfig);
        _currentConfig = Map.from(_defaultConfig)..addAll(loadedConfig);
      }
      _tempConfig = Map.from(_currentConfig);
    } catch (e) {
      print('加载配置失败: $e');
      _tempConfig = Map.from(_defaultConfig);
    }
  }

  // 保存配置到 localStorage
  Future<void> saveConfig() async {
    _currentConfig = Map.from(_tempConfig);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appConfig', json.encode(_currentConfig));
  }

  // 重置配置
  void resetConfig() {
    _tempConfig = Map.from(_defaultConfig);
  }

  // 更新临时配置
  void updateTempConfig(String key, dynamic value) {
    _tempConfig[key] = value;
  }

  // 获取配置值
  String get comfyuiAddress => _currentConfig['comfyuiAddress'] as String;

  // 获取临时配置值
  String get tempComfyuiAddress => _tempConfig['comfyuiAddress'] as String;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ConfigManager _configManager;
  final TextEditingController _addressController = TextEditingController();
  bool _hasChanges = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeConfig();
  }

  Future<void> _initializeConfig() async {
    _configManager = await ConfigManager.getInstance();
    setState(() {
      _addressController.text = _configManager.tempComfyuiAddress;
      _isLoading = false;
    });
    _addressController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final bool hasChanges =
        _addressController.text != _configManager.comfyuiAddress;
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _resetConfig() {
    setState(() {
      _configManager.resetConfig();
      _addressController.text = _configManager.tempComfyuiAddress;
    });
  }

  Future<void> _saveConfig() async {
    _configManager.updateTempConfig('comfyuiAddress', _addressController.text);
    await _configManager.saveConfig();
    if (mounted) {
      setState(() {
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Setting',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 网格背景
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),
          // 主要内容
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ComfyUI 地址配置项
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey[200]!,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'ComfyUI 地址',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 底部按钮
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey[300]!,
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _resetConfig,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('重置'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _hasChanges ? _saveConfig : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}
