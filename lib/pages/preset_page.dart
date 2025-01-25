import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../painters/grid_painter.dart';
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';

// 预设项数据模型
class PresetItem {
  String name;
  bool isEnabled;
  List<String> tags;

  PresetItem({
    required this.name,
    this.isEnabled = false,
    this.tags = const [],
  });

  // 转换为 JSON
  Map<String, dynamic> toJson() => {
    'name': name,
    'isEnabled': isEnabled,
    'tags': tags,
  };

  // 从 JSON 创建实例
  factory PresetItem.fromJson(Map<String, dynamic> json) => PresetItem(
    name: json['name'] as String,
    isEnabled: json['isEnabled'] as bool,
    tags: List<String>.from(json['tags'] as List),
  );
}

class PresetPage extends StatefulWidget {
  const PresetPage({super.key});

  @override
  State<PresetPage> createState() => _PresetPageState();
}

class _PresetPageState extends State<PresetPage> {
  final List<PresetItem> _presets = [];
  
  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  // 加载预设数据
  Future<void> _loadPresets() async {
    try {
      // 首先尝试从 localStorage 加载
      final String? jsonString = html.window.localStorage['prompts'];
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString) as List;
        setState(() {
          _presets.clear();
          _presets.addAll(
            jsonList.map((item) => PresetItem.fromJson(item as Map<String, dynamic>)),
          );
        });
      } else {
        // 如果 localStorage 中没有数据，则加载默认的空列表
        final String defaultJson = await rootBundle.loadString('assets/prompts.json');
        final List<dynamic> jsonList = json.decode(defaultJson) as List;
        setState(() {
          _presets.clear();
          _presets.addAll(
            jsonList.map((item) => PresetItem.fromJson(item as Map<String, dynamic>)),
          );
        });
        // 保存到 localStorage
        _savePresets();
      }
    } catch (e) {
      print('加载预设失败: $e');
      // 如果出现错误，确保至少有一个空列表
      _presets.clear();
      _savePresets();
    }
  }

  // 保存预设数据
  Future<void> _savePresets() async {
    try {
      final jsonList = _presets.map((preset) => preset.toJson()).toList();
      final jsonString = json.encode(jsonList);
      html.window.localStorage['prompts'] = jsonString;
    } catch (e) {
      print('保存预设失败: $e');
    }
  }

  // 获取所有启用的预设标签
  List<String> getEnabledTags() {
    final Set<String> enabledTags = {};
    for (var preset in _presets) {
      if (preset.isEnabled) {
        enabledTags.addAll(preset.tags);
      }
    }
    return enabledTags.toList();
  }

  // 添加新的预设项
  void _addNewPreset() {
    setState(() {
      _presets.add(PresetItem(name: '预设 ${_presets.length + 1}'));
      _savePresets();
    });
  }

  // 删除预设项
  void _removePreset(int index) {
    setState(() {
      _presets.removeAt(index);
      _savePresets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Prompt Presets',
          style: GoogleFonts.notoSansSc(
            textStyle: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              letterSpacing: 1.2,
              height: 1.2,
              shadows: [
                Shadow(
                  color: Colors.deepPurple.withOpacity(0.2),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // 导出按钮
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.deepPurple),
            onPressed: () {
              final jsonList = _presets.map((preset) => preset.toJson()).toList();
              final jsonString = json.encode(jsonList);
              final bytes = utf8.encode(jsonString);
              final blob = html.Blob([bytes]);
              final url = html.Url.createObjectUrlFromBlob(blob);
              final anchor = html.AnchorElement(href: url)
                ..setAttribute('download', 'prompts_export.json')
                ..click();
              html.Url.revokeObjectUrl(url);
            },
            tooltip: '导出预设',
          ),
          // 导入按钮
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.deepPurple),
            onPressed: () {
              final input = html.FileUploadInputElement()..accept = '.json';
              input.click();
              input.onChange.listen((event) {
                final file = input.files?.first;
                if (file != null) {
                  final reader = html.FileReader();
                  reader.readAsText(file);
                  reader.onLoad.listen((event) {
                    try {
                      final jsonString = reader.result as String;
                      final List<dynamic> jsonList = json.decode(jsonString) as List;
                      setState(() {
                        _presets.clear();
                        _presets.addAll(
                          jsonList.map((item) => PresetItem.fromJson(item as Map<String, dynamic>)),
                        );
                      });
                      _savePresets();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('导入失败：无效的文件格式')),
                      );
                    }
                  });
                }
              });
            },
            tooltip: '导入预设',
          ),
          // 添加预设按钮
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.deepPurple),
            onPressed: _addNewPreset,
          ),
          const SizedBox(width: 8),
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
          // 预设列表
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _presets.length,
            itemBuilder: (context, index) {
              return PresetItemWidget(
                preset: _presets[index],
                onPresetChanged: _savePresets,
                onDelete: () => _removePreset(index),
              );
            },
          ),
          // 当没有预设时显示的提示
          if (_presets.isEmpty)
            const Center(
              child: Text(
                '点击右上角添加预设',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 预设项组件
class PresetItemWidget extends StatefulWidget {
  final PresetItem preset;
  final VoidCallback onPresetChanged;
  final VoidCallback onDelete;

  const PresetItemWidget({
    super.key,
    required this.preset,
    required this.onPresetChanged,
    required this.onDelete,
  });

  @override
  State<PresetItemWidget> createState() => _PresetItemWidgetState();
}

class _PresetItemWidgetState extends State<PresetItemWidget> {
  late TextEditingController _nameController;
  late TextEditingController _tagController;
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
    _tagController = TextEditingController();
    _tags.addAll(widget.preset.tags);
  }

  // 更新处理文本变化的函数
  void _handleTextChange(String value) {
    if (value.endsWith('，') || value.endsWith(',') || value.endsWith('\n')) {
      _addTags(value.substring(0, value.length - 1));
      _tagController.clear();
    }
  }

  // 更新处理文本提交的函数
  void _handleTextSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _addTags(value);
      _tagController.clear();
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
        .map((tag) => _processDanbooruTag(tag))  // 添加对d站标签的处理
        .toList();

    setState(() {
      // 添加新标签，排除重复
      for (var tag in splitTags) {
        if (!_tags.contains(tag)) {
          _tags.add(tag);
          widget.preset.tags = _tags;
          widget.onPresetChanged();
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
      processedTag = processedTag
          .replaceAll('(', r'\(')
          .replaceAll(')', r'\)');
    }
    
    return processedTag.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 预设名称输入框
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    onChanged: (value) {
                      widget.preset.name = value;
                      widget.onPresetChanged();
                    },
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                // 删除按钮
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
                ),
                // 启用开关
                Switch(
                  value: widget.preset.isEnabled,
                  onChanged: (value) {
                    setState(() {
                      widget.preset.isEnabled = value;
                      widget.onPresetChanged();
                    });
                  },
                  activeColor: Colors.deepPurple,
                ),
              ],
            ),
          ),
          // 标签显示区域
          if (_tags.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, widget.preset.isEnabled ? 16 : 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) => Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(fontSize: 14),
                  ),
                  deleteIcon: widget.preset.isEnabled ? null : const Icon(Icons.close, size: 18),
                  onDeleted: widget.preset.isEnabled ? null : () {
                    setState(() {
                      _tags.remove(tag);
                      widget.preset.tags = _tags;
                      widget.onPresetChanged();
                    });
                  },
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                )).toList(),
              ),
            ),
          // 输入框 - 只在非激活状态显示
          if (!widget.preset.isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      onChanged: _handleTextChange,
                      onSubmitted: _handleTextSubmitted,
                      decoration: InputDecoration(
                        hintText: '输入提示词，用逗号分隔或回车确认...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (_tagController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _handleTextSubmitted(_tagController.text),
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
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }
} 