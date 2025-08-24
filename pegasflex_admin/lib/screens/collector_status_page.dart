import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CollectorStatusPage extends StatefulWidget {
  const CollectorStatusPage({super.key});

  @override
  State<CollectorStatusPage> createState() => _CollectorStatusPageState();
}

class _CollectorStatusPageState extends State<CollectorStatusPage> {
  int collectedCount = 0;
  int notCollectedCount = 0;
  bool isLoading = true;
  int totalShops = 0;
  List<Map<String, dynamic>> dailySnapshots = [];

  @override
  void initState() {
    super.initState();
    _fetchCollectionStatus();
    _fetchDailySnapshots();
  }

  /// ✅ Fetch last 7 days trend from `dailyPaidShops`
  Future<void> _fetchDailySnapshots() async {
    try {
      // 1️⃣ Count total shops once
      int total = 0;
      final routesSnapshot =
          await FirebaseFirestore.instance.collection('routes').get();
      for (var routeDoc in routesSnapshot.docs) {
        final shopsSnapshot =
            await routeDoc.reference.collection('shops').get();
        total += shopsSnapshot.docs.length;
      }
      totalShops = total;

      // 2️⃣ Fetch dailyPaidShops
      final snapshots = await FirebaseFirestore.instance
          .collection('admin')
          .doc('summary')
          .collection('dailyPaidShops')
          .orderBy('date', descending: true)
          .limit(7)
          .get();

      dailySnapshots = [];

      for (var doc in snapshots.docs) {
        final data = doc.data();
        final dateStr = data['date'] ?? ''; // yyyy-MM-dd
        final formatted =
            dateStr.length >= 5 ? dateStr.substring(5) : dateStr;

        final paid = data['paidShopsCount'] ?? 0;
        final unpaid = totalShops - paid;

        dailySnapshots.add({
          'date': formatted,
          'paid': paid,
          'unpaid': unpaid,
        });
      }

      dailySnapshots = dailySnapshots.reversed.toList(); // oldest → latest
      setState(() {});
    } catch (e) {
      print('❌ Error fetching daily snapshots: $e');
    }
  }

  /// ✅ Fetch today’s collection summary
  Future<void> _fetchCollectionStatus() async {
    try {
      final now = DateTime.now();
      final todayKey =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Get today’s snapshot
      final todayDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc('summary')
          .collection('dailyPaidShops')
          .doc(todayKey)
          .get();

      int paid = 0;
      if (todayDoc.exists) {
        paid = todayDoc.data()?['paidShopsCount'] ?? 0;
      }

      // Count all shops
      int total = 0;
      final routesSnapshot =
          await FirebaseFirestore.instance.collection('routes').get();
      for (var routeDoc in routesSnapshot.docs) {
        final shopsSnapshot =
            await routeDoc.reference.collection('shops').get();
        total += shopsSnapshot.docs.length;
      }

      final unpaid = total - paid;

      setState(() {
        collectedCount = paid;
        notCollectedCount = unpaid;
        totalShops = total;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching collection status: $e');
      setState(() => isLoading = false);
    }
  }

  /// ✅ Pie chart sections
  List<PieChartSectionData> _generateSections() {
    final total = collectedCount + notCollectedCount;
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: 1,
          title: 'No Data',
          titleStyle: const TextStyle(color: Colors.white, fontSize: 16),
          radius: 60,
        )
      ];
    }

    final collectedPercent = (collectedCount / total) * 100;
    final notCollectedPercent = (notCollectedCount / total) * 100;

    return [
      PieChartSectionData(
        color: Colors.green.shade600,
        value: collectedCount.toDouble(),
        title: '${collectedPercent.toStringAsFixed(1)}%',
        radius: 70,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      PieChartSectionData(
        color: Colors.red.shade600,
        value: notCollectedCount.toDouble(),
        title: '${notCollectedPercent.toStringAsFixed(1)}%',
        radius: 70,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ];
  }

  Widget _buildStatusCard(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: color),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Collector Status"),
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Collection Summary',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusCard(
                        "✅ Collected", collectedCount, Colors.green),
                    _buildStatusCard(
                        "❌ Not Collected", notCollectedCount, Colors.red),
                    const SizedBox(height: 30),

                    const Text(
                      'Collection Chart',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 1.3,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 50,
                          sectionsSpace: 4,
                          sections: _generateSections(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text("📈 Daily Collection Trend",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    AspectRatio(
                      aspectRatio: 1.7,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: true),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index < dailySnapshots.length) {
                                      return Text(
                                          dailySnapshots[index]['date']);
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              // ✅ Collected Line
                              LineChartBarData(
                                spots: List.generate(dailySnapshots.length, (i) {
                                  return FlSpot(
                                      i.toDouble(),
                                      (dailySnapshots[i]['paid'] ?? 0)
                                          .toDouble());
                                }),
                                isCurved: true,
                                color: Colors.green,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                              ),
                              // ❌ Not Collected Line
                              LineChartBarData(
                                spots: List.generate(dailySnapshots.length, (i) {
                                  return FlSpot(
                                      i.toDouble(),
                                      (dailySnapshots[i]['unpaid'] ?? 0)
                                          .toDouble());
                                }),
                                isCurved: true,
                                color: Colors.red,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
