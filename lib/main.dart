import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'demo/aliyun/aliyun_smart_call_defaults.dart';
import 'demo/aliyun/aliyun_smart_call_demo_page.dart';
import 'demo/aliyun/aliyun_smart_call_service.dart';
import 'game/world/office_game.dart';
import 'demo/maoyan/pages/movie_explorer_page.dart';
import 'office_prototype/office_prototype_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Office Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E74D8),
          primary: const Color(0xFF2E74D8),
          secondary: const Color(0xFF55A844),
          tertiary: const Color(0xFFF08422),
        ),
        useMaterial3: true,
        fontFamily: 'LocalChinese',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E74D8),
          foregroundColor: Colors.white,
        ),
      ),
      home: const ProjectHomePage(),
    );
  }
}

class ProjectHomePage extends StatefulWidget {
  const ProjectHomePage({super.key});

  @override
  State<ProjectHomePage> createState() => _ProjectHomePageState();
}

class _ProjectHomePageState extends State<ProjectHomePage> {
  final _aliyunService = AliyunSmartCallService();
  bool _callingPythonService = false;

  Future<void> _callViaPythonService() async {
    if (_callingPythonService) {
      return;
    }

    setState(() {
      _callingPythonService = true;
    });

    try {
      final response = await _aliyunService.llmSmartCallViaServer(
        accessKeyId: AliyunSmartCallDefaults.accessKeyId,
        accessKeySecret: AliyunSmartCallDefaults.accessKeySecret,
        applicationCode: AliyunSmartCallDefaults.applicationCode,
        securityToken: AliyunSmartCallDefaults.securityToken,
        callerNumber: AliyunSmartCallDefaults.callerNumber,
        calledNumber: AliyunSmartCallDefaults.calledNumber,
        endpoint: AliyunSmartCallDefaults.endpoint,
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Python 服务外呼结果'),
              content: SelectableText(
                response.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join('\n'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Python 服务外呼失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _callingPythonService = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(title: const Text('Office Game'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apartment, size: 80, color: Color(0xFF2E74D8)),
            const SizedBox(height: 40),
            _buildNavButton(
              context,
              icon: Icons.gamepad,
              label: '进入 Office Game',
              color: const Color(0xFF2E74D8),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => Scaffold(
                            body: GameWidget(game: OfficeGame()),
                            floatingActionButton: FloatingActionButton(
                              mini: true,
                              onPressed: () => Navigator.pop(context),
                              child: const Icon(Icons.arrow_back),
                            ),
                          ),
                    ),
                  ),
            ),
            const SizedBox(height: 20),
            _buildNavButton(
              context,
              icon: Icons.business,
              label: '进入办公室模拟原型',
              color: const Color(0xFF6B7F45),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OfficePrototypePage(),
                    ),
                  ),
            ),
            const SizedBox(height: 20),
            _buildNavButton(
              context,
              icon: Icons.movie,
              label: '进入电影 Demo (免 Key)',
              color: const Color(0xFF55A844),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MovieExplorerPage(),
                    ),
                  ),
            ),
            const SizedBox(height: 20),
            _buildNavButton(
              context,
              icon: Icons.call,
              label: '进入阿里云外呼 Demo',
              color: Colors.teal,
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AliyunSmartCallDemoPage(),
                    ),
                  ),
            ),
            const SizedBox(height: 20),
            _buildNavButton(
              context,
              icon: Icons.call_made,
              label:
                  _callingPythonService
                      ? 'Python 服务外呼中...'
                      : '首页直接调用 Python 外呼',
              color: const Color(0xFFF08422),
              onPressed: _callingPythonService ? null : _callViaPythonService,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 240,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}
