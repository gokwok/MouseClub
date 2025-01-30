import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:math';
import 'pages/preset_page.dart';
import 'painters/grid_painter.dart';
import 'pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'services/image_generator_service.dart';

// 将 PresetManager 移到顶部，在 main() 函数之前
class PresetManager {
  static final PresetManager _instance = PresetManager._internal();
  factory PresetManager() => _instance;
  PresetManager._internal();

  Future<List<String>> getEnabledTags() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('prompts');
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString) as List;
        final presets = jsonList
            .map((item) => PresetItem.fromJson(item as Map<String, dynamic>))
            .where((preset) => preset.isEnabled)
            .expand((preset) => preset.tags)
            .toList();
        return presets;
      } catch (e) {
        print('获取预设标签失败: $e');
      }
    }
    return [];
  }
}

// 配置管理器
class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  factory ConfigManager() => _instance;

  ConfigManager._internal() {
    _loadConfig();
  }

  // 默认配置
  static const Map<String, dynamic> _defaultConfig = {
    'comfyuiAddress': '114.55.173.20:8090/api',
  };

  // 当前配置
  Map<String, dynamic> _currentConfig = Map.from(_defaultConfig);

  // 临时配置（未保存）
  Map<String, dynamic> _tempConfig = {};

  // 从 localStorage 加载配置
  void _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedConfig = prefs.getString('appConfig');
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Image Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2A2A), // 深灰色背景
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const ImageGeneratorPage(),
    );
  }
}

class ImageGeneratorPage extends StatefulWidget {
  const ImageGeneratorPage({super.key});

  @override
  State<ImageGeneratorPage> createState() => _ImageGeneratorPageState();
}

class _ImageGeneratorPageState extends State<ImageGeneratorPage> {
  final TextEditingController _promptController = TextEditingController();
  String? _currentImage;
  final List<String> _imageHistory = [];
  final List<String> _tags = []; // 存储标签
  bool _isGenerating = false;
  bool _isDetailedMode = false; // 细节增强开关状态
  int? _lastSeed; // 保存上一次使用的随机种子

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.photos.request();
  }

  // 更新生成图片函数
  Future<void> _generateImage() async {
    if (_tags.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      // 获取预设标签
      final presetTags = await PresetManager().getEnabledTags();

      // 合并主界面标签和预设标签
      final allTags = [..._tags, ...presetTags];
      final String prompt = allTags.join(', ');

      print('生成的提示词: $prompt');
      print('其中预设标签: ${presetTags.join(', ')}');

      final generator = ImageGeneratorService(
        comfyuiAddress: ConfigManager().comfyuiAddress,
        isDetailedMode: _isDetailedMode,
        lastSeed: _lastSeed,
        onProgress: (progress) {
          // 可以在这里处理进度更新UI
        },
        onImageGenerated: (imagePath) {
          setState(() {
            _currentImage = imagePath;
            _imageHistory.insert(0, imagePath);
            _isGenerating = false;
            if (_isDetailedMode) {
              _lastSeed = null;
            }
          });
        },
        onError: (error) {
          setState(() => _isGenerating = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('生成图片时发生错误: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      // 根据细节增强模式选择不同的工作流文件
      final workflowPath = _isDetailedMode
          ? 'assets/workflows/anime_detailed.json'
          : 'assets/workflows/anime_simple.json';

      await generator.generateImage(
        prompt,
        assetBundlePath: workflowPath,
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成图片时发生错误: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 更新处理文本变化的函数
  void _handleTextChange(String value) {
    if (value.endsWith('，') || value.endsWith(',') || value.endsWith('\n')) {
      _addTags(value.substring(0, value.length - 1));
      _promptController.clear();
    }
  }

  // 添加新的处理文本提交的函数
  void _handleTextSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _addTags(value);
      _promptController.clear();
    }
  }

  // 添加新的标签处理函数
  void _addTags(String text) {
    // 移除首尾空格
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    // 使用中英文逗号分割文本
    final splitTags = trimmedText
        .split(RegExp(r'[,，]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map((tag) => _processDanbooruTag(tag)) // 添加对d站标签的处理
        .toList();

    setState(() {
      // 添加新标签，排除重复
      for (var tag in splitTags) {
        if (!_tags.contains(tag)) {
          _tags.add(tag);
        }
      }
    });
  }

  // 添加处理d站标签的函数
  String _processDanbooruTag(String tag) {
    // 检查标签中是否同时包含下划线和括号
    bool hasUnderscore = tag.contains('_');
    bool hasParentheses = tag.contains('(') || tag.contains(')');

    // 替换下划线为空格
    String processedTag = tag.replaceAll('_', ' ');

    // 只有当标签同时包含下划线和括号时，才对括号进行转义
    if (hasUnderscore && hasParentheses) {
      processedTag = processedTag.replaceAll('(', r'\(').replaceAll(')', r'\)');
    }

    return processedTag.trim();
  }

  // 删除标签
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  // 添加新的保存图片方法
  Future<void> _saveImage(String imagePath) async {
    try {
      // 读取图片文件
      final imageBytes = await File(imagePath).readAsBytes();

      // 保存到相册
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: "generated_image_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (result['isSuccess']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片已保存到相册')),
          );
        }
      } else {
        throw Exception('保存失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double minImageHeight = MediaQuery.of(context).size.height * 0.7;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        title: const Text(
          'Mickey Mouse Clubhouse',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 网格背景
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),
          // 主要内容 - 使用 LayoutBuilder 确保最小高度
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight, // 确保至少和屏幕一样高
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                      child: Column(
                        children: [
                          // 输入区域 Container
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white, // 改为纯白色背景
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey[200]!,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 标签显示区域
                                if (_tags.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 16, 16, 8),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 12, // 增加行间距
                                      children: _tags
                                          .map((tag) => Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.deepPurple
                                                          .withOpacity(0.1),
                                                      Colors.deepPurple
                                                          .withOpacity(0.05),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Chip(
                                                  label: Text(
                                                    tag,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.deepPurple,
                                                    ),
                                                  ),
                                                  deleteIcon: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.deepPurple,
                                                  ),
                                                  onDeleted: () =>
                                                      _removeTag(tag),
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  side: BorderSide.none,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 4,
                                                    vertical: -2,
                                                  ),
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                // 输入框
                                Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _promptController,
                                          onChanged: _handleTextChange,
                                          onSubmitted: _handleTextSubmitted,
                                          decoration: InputDecoration(
                                            hintText: '输入提示词，用逗号分隔或回车确认...',
                                            hintStyle: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 14,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                          ),
                                          maxLines: null,
                                          textInputAction: TextInputAction.done,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                      if (_promptController.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          onPressed: () {
                                            _handleTextSubmitted(
                                                _promptController.text);
                                          },
                                          color: Colors.deepPurple,
                                          iconSize: 20,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 修改操作按钮区域
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 提示词预设按钮
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PresetPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.list_alt, size: 20),
                                label: const Text('提示词预设'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  side: const BorderSide(
                                      color: Colors.deepPurple),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 生成按钮
                              ElevatedButton.icon(
                                onPressed: _isGenerating || _tags.isEmpty
                                    ? null
                                    : _generateImage,
                                icon: _isGenerating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 20),
                                label: Text(
                                  _isGenerating ? '生成中...' : '生成图片',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 细节增强开关
                              Container(
                                height: 44, // 与按钮高度保持一致
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '细节增强',
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.8, // 稍微缩小开关的大小
                                      child: Switch(
                                        value: _isDetailedMode,
                                        onChanged: (value) {
                                          setState(() {
                                            _isDetailedMode = value;
                                            if (!value) {
                                              _lastSeed = null;
                                            }
                                          });
                                        },
                                        activeColor: Colors.deepPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 当前生成的图片显示区域
                          if (_currentImage != null)
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                minHeight: minImageHeight,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey[200]!,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 图片显示
                                    Image.file(
                                      File(_currentImage!),
                                      fit: BoxFit.contain,
                                      width: MediaQuery.of(context).size.width *
                                          0.8,
                                    ),
                                    // 下载按钮
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.save_alt),
                                          onPressed: () =>
                                              _saveImage(_currentImage!),
                                          color: Colors.deepPurple,
                                          tooltip: '保存到相册',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // 历史图片滑动栏
                          if (_imageHistory.isNotEmpty)
                            SizedBox(
                              height: 100,
                              child: ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    stops: const [0.95, 1.0],
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.dstIn,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _imageHistory.length,
                                    padding: const EdgeInsets.all(8),
                                    physics: const BouncingScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _currentImage =
                                                  _imageHistory[index];
                                            });
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: AspectRatio(
                                              aspectRatio: 0.6,
                                              child: Image.file(
                                                File(_imageHistory[index]),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}
