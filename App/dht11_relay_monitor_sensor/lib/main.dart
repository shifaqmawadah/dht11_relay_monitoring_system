import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SensorApp());
}

class SensorApp extends StatelessWidget {
  const SensorApp({super.key});

  Future<Widget> _getStartPage() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      return const SensorHomePage();
    } else {
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartPage(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return MaterialApp(
          title: 'Sensor Monitor',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF800000),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          debugShowCheckedModeBanner: false,
          home: snapshot.data!,
        );
      },
    );
  }
}

class SensorReading {
  final double temperature;
  final double humidity;
  final int relayStatus;
  final DateTime timestamp;

  SensorReading({
    required this.temperature,
    required this.humidity,
    required this.relayStatus,
    required this.timestamp,
  });

  static final DateFormat _formatter = DateFormat("yyyy-MM-dd HH:mm:ss");

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      relayStatus: json['relay_status'] as int,
      timestamp: _formatter.parse(json['timestamp']),
    );
  }
}

class SensorHomePage extends StatefulWidget {
  const SensorHomePage({super.key});

  @override
  State<SensorHomePage> createState() => _SensorHomePageState();
}

class _SensorHomePageState extends State<SensorHomePage> {
  List<SensorReading> _readings = [];
  double _tempThreshold = 26.0;
  double _humThreshold = 70.0;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;

  final String _apiBase = 'https://humancc.site/shifaqmawaddah/backend';

  @override
  void initState() {
    super.initState();
    _loadThresholdsFromServer();
    _fetchSensorData();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchSensorData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse('$_apiBase/fetch.php'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final readings = jsonData.map((e) => SensorReading.fromJson(e)).toList();

        if (!mounted) return;
        setState(() {
          _readings = readings;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<void> _saveThresholdsToServer() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/set_thresholds.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'temp_threshold': _tempThreshold,
          'humidity_threshold': _humThreshold,
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to save thresholds: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving thresholds: $e');
    }
  }

  Future<void> _loadThresholdsFromServer() async {
    try {
      final response = await http.get(Uri.parse('$_apiBase/get_thresholds.php'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tempThreshold = (data['temp_threshold'] as num).toDouble();
          _humThreshold = (data['humidity_threshold'] as num).toDouble();
        });
      }
    } catch (e) {
      print('Error loading thresholds: $e');
    }
  }

  List<FlSpot> _getTempSpots() =>
      _readings.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.temperature)).toList();
  List<FlSpot> _getHumSpots() =>
      _readings.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.humidity)).toList();

  double get _minTemp =>
      _readings.isEmpty ? 20 : _readings.map((e) => e.temperature).reduce((a, b) => a < b ? a : b) - 2;
  double get _maxTemp =>
      _readings.isEmpty ? 40 : _readings.map((e) => e.temperature).reduce((a, b) => a > b ? a : b) + 2;
  double get _minHum =>
      _readings.isEmpty ? 30 : _readings.map((e) => e.humidity).reduce((a, b) => a < b ? a : b) - 5;
  double get _maxHum =>
      _readings.isEmpty ? 100 : _readings.map((e) => e.humidity).reduce((a, b) => a > b ? a : b) + 5;

  @override
  Widget build(BuildContext context) {
    final latest = _readings.isNotEmpty ? _readings.last : null;
    final alert = latest != null &&
        (latest.temperature > _tempThreshold || latest.humidity > _humThreshold);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Monitor'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchSensorData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (latest != null) _buildLatestCard(latest, alert, dateFormatter),
                        _buildThresholdControls(),
                        const SizedBox(height: 20),
                        if (_readings.isNotEmpty) _buildChart(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildLatestCard(SensorReading latest, bool alert, DateFormat formatter) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceVariant,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest Reading',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('📅 ${formatter.format(latest.timestamp)}'),
            Text('🌡 Temperature: ${latest.temperature.toStringAsFixed(1)} °C'),
            Text('💧 Humidity: ${latest.humidity.toStringAsFixed(1)} %'),
            Text('🔌 Relay: ${latest.relayStatus == 1 ? "ON" : "OFF"}'),
            const SizedBox(height: 10),
            Text(
              alert ? "⚠️ Alert: Threshold Exceeded!" : "✅ Normal Status",
              style: TextStyle(
                color: alert ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdControls() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceVariant,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "⚙️ Set Alert Thresholds",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text("Temperature Threshold: ${_tempThreshold.toStringAsFixed(1)} °C"),
            Slider(
              label: '${_tempThreshold.toStringAsFixed(1)} °C',
              value: _tempThreshold,
              min: 20,
              max: 40,
              divisions: 20,
              onChanged: (value) => setState(() => _tempThreshold = value),
              onChangeEnd: (_) => _saveThresholdsToServer(),
            ),
            const SizedBox(height: 12),
            Text("Humidity Threshold: ${_humThreshold.toStringAsFixed(1)} %"),
            Slider(
              label: '${_humThreshold.toStringAsFixed(1)} %',
              value: _humThreshold,
              min: 30,
              max: 100,
              divisions: 14,
              onChanged: (value) => setState(() => _humThreshold = value),
              onChangeEnd: (_) => _saveThresholdsToServer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minY: (_minTemp < _minHum ? _minTemp : _minHum) - 5,
          maxY: (_maxTemp > _maxHum ? _maxTemp : _maxHum) + 5,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (_readings.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _readings.length) return const SizedBox();
                  final time = _readings[index].timestamp;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(DateFormat.Hm().format(time), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _getTempSpots(),
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 3,
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: _getHumSpots(),
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
