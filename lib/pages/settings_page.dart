import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:convert';
import '../painters/grid_painter.dart';

// 配置管理器
class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  factory ConfigManager() => _instance;
  
  ConfigManager._internal() {
    _loadConfig();
  }

  // 默认配置
  static const Map<String, dynamic> _defaultConfig = {
    'comfyuiAddress': '10.147.18.158:8080/api',
  };

  // 当前配置
  Map<String, dynamic> _currentConfig = Map.from(_defaultConfig);
  
  // 临时配置（未保存）
  Map<String, dynamic> _tempConfig = {};

  // 从 localStorage 加载配置
  void _loadConfig() {
    final String? savedConfig = html.window.localStorage['appConfig'];
    if (savedConfig != null) {
      try {
        final Map<String, dynamic> loadedConfig = json.decode(savedConfig);
        _currentConfig = Map.from(_defaultConfig)..addAll(loadedConfig);
      } catch (e) {
        print('加载配置失败: $e');
      }
    }
    _tempConfig = Map.from(_currentConfig);
  }

  // 保存配置到 localStorage
  Future<void> saveConfig() async {
    _currentConfig = Map.from(_tempConfig);
    html.window.localStorage['appConfig'] = json.encode(_currentConfig);
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
  final ConfigManager _configManager = ConfigManager();
  final TextEditingController _addressController = TextEditingController();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _addressController.text = _configManager.tempComfyuiAddress;
    _addressController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final bool hasChanges = _addressController.text != _configManager.comfyuiAddress;
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
