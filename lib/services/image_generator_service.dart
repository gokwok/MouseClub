import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ImageGeneratorService {
  final String comfyuiAddress;
  final bool isDetailedMode;
  final int? lastSeed;
  final Function(double) onProgress;
  final Function(String) onImageGenerated;
  final Function(String) onError;

  ImageGeneratorService({
    required this.comfyuiAddress,
    required this.isDetailedMode,
    this.lastSeed,
    required this.onProgress,
    required this.onImageGenerated,
    required this.onError,
  });

  Future<void> generateImage(String prompt,
      {required String assetBundlePath}) async {
    WebSocketChannel? ws;
    try {
      print('开始生成图片流程...');

      // 创建 WebSocket 连接
      print('正在创建WebSocket连接...');
      final clientId = DateTime.now().millisecondsSinceEpoch.toString();
      final wsUrl = Uri.parse('ws://$comfyuiAddress/ws?clientId=$clientId');
      print('WebSocket URL: $wsUrl');

      ws = WebSocketChannel.connect(wsUrl);

      // 等待连接建立
      await ws.ready;
      print('WebSocket连接已建立');

      // 读取工作流文件
      print('正在读取工作流文件...');
      final String workflow;
      try {
        workflow = await rootBundle.loadString(assetBundlePath);
        print('工作流文件读取成功: $assetBundlePath');
      } catch (e) {
        print('工作流文件读取失败: $e');
        throw Exception('无法读取工作流文件');
      }

      // 更新工作流配置
      print('正在更新工作流配置...');
      final Map<String, dynamic> workflowData = json.decode(workflow);
      _updateWorkflow(workflowData, prompt);

      // 准备请求数据
      final requestData = {
        'prompt': workflowData,
        'client_id': clientId,
      };

      // 设置WebSocket监听
      ws.stream.listen(
        (message) async {
          print('收到WebSocket消息: $message');
          if (message is String) {
            // 处理文本消息（如进度信息）
            final data = json.decode(message);
            if (data['type'] == 'progress') {
              final progressData = data['data'];
              if (progressData['max'] != 1) {
                final progress = progressData['value'] / progressData['max'];
                onProgress(progress);
                print('生成进度: ${(progress * 100).toStringAsFixed(1)}%');
              }
            }
          } else {
            // 处理二进制消息（图片数据）
            try {
              final imageBytes = message.sublist(8);
              final tempDir = await Directory.systemTemp.createTemp();
              final tempFile = File(
                  '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.png');
              await tempFile.writeAsBytes(imageBytes);
              onImageGenerated(tempFile.path);
              print('成功接收并显示图片');
            } catch (e) {
              print('处理图片数据时出错: $e');
              onError('处理图片数据时出错: $e');
            }
          }
        },
        onError: (error) {
          print('WebSocket错误: $error');
          onError('WebSocket错误: $error');
        },
        onDone: () {
          print('WebSocket连接关闭');
        },
      );

      // 发送 HTTP 请求
      print('正在发送HTTP请求...');
      final requestUrl = Uri.parse('http://$comfyuiAddress/prompt');
      print('HTTP请求URL: $requestUrl');
      print('请求体: ${json.encode(requestData)}');

      final queueResponse = await http
          .post(
        requestUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Connection': 'keep-alive',
        },
        body: json.encode(requestData),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('请求超时');
        },
      );

      print('HTTP响应状态码: ${queueResponse.statusCode}');
      print('HTTP响应体: ${queueResponse.body}');

      if (queueResponse.statusCode != 200) {
        throw Exception(
            '请求失败: ${queueResponse.statusCode} - ${queueResponse.body}');
      }
    } catch (e, stackTrace) {
      print('发生错误: $e');
      print('错误堆栈: $stackTrace');
      onError(e.toString());
      ws?.sink.close();
    }
  }

  void _updateWorkflow(Map<String, dynamic> workflow, String prompt) {
    // 更新提示词
    if (workflow.containsKey('1') &&
        workflow['1'].containsKey('inputs') &&
        workflow['1']['inputs'].containsKey('positive')) {
      workflow['1']['inputs']['positive'] = prompt;
    }

    // 更新随机种子
    if (workflow.containsKey('2') && workflow['2'].containsKey('inputs')) {
      int seed;
      if (isDetailedMode && lastSeed != null) {
        seed = lastSeed!;
      } else {
        seed = Random().nextInt(100000000);
      }
      workflow['2']['inputs']['seed'] = seed;
      print('使用的随机种子: $seed (${isDetailedMode ? "复用" : "新生成"})');
    }
  }
}
