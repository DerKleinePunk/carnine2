import 'dart:io';

import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';
import 'lib/carnine.pbgrpc.dart';
import 'styles/colors.dart';
import 'styles/text_styles.dart';

final ValueNotifier<List<String>> appLogLines = ValueNotifier(<String>[]);
final Logger _logger = Logger('CarnineFrontend');

void _setupLogging() {
  Directory('logs').createSync(recursive: true);
  final file = File('logs/frontend.log');
  final sink = file.openWrite(mode: FileMode.append);

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final message = StringBuffer()
      ..write(record.time.toIso8601String())
      ..write(' [${record.level.name}] ')
      ..write(record.loggerName)
      ..write(': ')
      ..write(record.message);

    if (record.error != null) {
      message.write(' | error=${record.error}');
    }
    if (record.stackTrace != null) {
      message.write('\n${record.stackTrace}');
    }

    final line = message.toString();
    final currentLogs = List<String>.from(appLogLines.value);
    currentLogs.add(line);
    if (currentLogs.length > 200) {
      currentLogs.removeRange(0, currentLogs.length - 200);
    }
    appLogLines.value = currentLogs;

    sink.writeln(line);
    sink.flush();
    // Also keep console output for development.
    // ignore: avoid_print
    print(line);
  });
}

void main() {
  _setupLogging();
  _logger.info('Frontend app started');
  runApp(const CarnineApp());
}

class CarnineApp extends StatelessWidget {
  const CarnineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carnine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
        ),
        textTheme: const TextTheme(
          headlineLarge: AppTextStyles.headlineLarge,
          bodyLarge: AppTextStyles.bodyLarge,
          labelLarge: AppTextStyles.labelLarge,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _grpcStatus = 'Not connected';
  List<CanData> _canData = [];

  final List<String> _navItems = ['Home', 'Maps', 'Media', 'Climate', 'Settings'];
  final List<IconData> _navIcons = [
    Icons.home,
    Icons.map,
    Icons.play_circle,
    Icons.thermostat,
    Icons.settings,
  ];

  Future<void> _testGrpc() async {
    _logger.info('Triggering gRPC test request');
    try {
      // For Unix socket, we need to use a custom channel
      // Since Flutter grpc doesn't directly support Unix sockets, we'll try TCP for testing
      // In production, this would be Unix socket
      final channel = ClientChannel(
        'localhost', // Use localhost for testing, in real app use Unix socket path
        port: 50051, // Standard gRPC port, but our server uses Unix socket
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );

      final stub = CarnineServiceClient(channel);

      // Test GetCanData
      final request = CanDataRequest(sensorId: 'engine_temp');
      final response = await stub.getCanData(request);

      _logger.info('gRPC response received with ${response.data.length} data points');
      setState(() {
        _grpcStatus = 'Connected - Received ${response.data.length} data points';
        _canData = response.data;
      });

      await channel.shutdown();
    } catch (e, stack) {
      _logger.severe('gRPC test failed', e, stack);
      setState(() {
        _grpcStatus = 'Error: $e';
      });
    }
  }

  void _showLogViewer() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Frontend Logs'),
          content: SizedBox(
            width: 700,
            height: 500,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: appLogLines,
              builder: (context, logs, child) {
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      logs[index],
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SideNavBar
          Container(
            width: 96, // w-24 in Tailwind ~96px
            color: AppColors.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'KINETIC',
                      style: AppTextStyles.kineticBrand.copyWith(color: AppColors.primary),
                    ),
                    Text(
                      'V8-ACTIVE',
                      style: AppTextStyles.kineticSubtitle.copyWith(color: AppColors.primary40),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(_navItems.length, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedIndex == index ? AppColors.surfaceContainer : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: _selectedIndex == index ? AppColors.primary : Colors.transparent,
                                width: 4,
                              ),
                            ),
                            boxShadow: _selectedIndex == index
                                ? [BoxShadow(color: AppColors.primary40, blurRadius: 15)]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _navIcons[index],
                                color: _selectedIndex == index ? AppColors.primary : AppColors.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _navItems[index],
                                style: AppTextStyles.navItem.copyWith(
                                  color: _selectedIndex == index ? AppColors.primary : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorContainer,
                        foregroundColor: AppColors.onErrorContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        textStyle: AppTextStyles.emergencyButton,
                      ),
                      child: const Text('EMERGENCY'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary20, width: 2),
                        color: AppColors.surfaceContainer, // Hintergrund für Icon
                      ),
                      child: Icon(
                        Icons.directions_car, // Auto-Icon als Platzhalter
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // TopAppBar
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'CarNiNe',
                        style: AppTextStyles.appBarTitle.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Container(height: 12, width: 1, color: AppColors.outlineVariant20),
                      const SizedBox(width: 12),
                      Icon(Icons.signal_cellular_4_bar, color: AppColors.primary, size: 12),
                      const SizedBox(width: 8),
                      Icon(Icons.battery_full, color: AppColors.primary, size: 12),
                      const SizedBox(width: 8),
                      Icon(Icons.light_mode, color: AppColors.primary, size: 12),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _showLogViewer,
                        icon: const Icon(Icons.article, size: 16),
                        color: AppColors.primary,
                        tooltip: 'Show frontend logs',
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Dashboard Content for ${_navItems[_selectedIndex]}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'gRPC Status: $_grpcStatus',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _testGrpc,
                          child: const Text('Test gRPC'),
                        ),
                        const SizedBox(height: 20),
                        if (_canData.isNotEmpty)
                          Column(
                            children: _canData.map((data) => Text(
                              'Sensor: ${data.sensorId}, Value: ${data.value}, Time: ${data.timestamp}',
                              style: const TextStyle(color: Colors.white),
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
