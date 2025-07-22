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
  List<String> dates = [];
  List<int> paidCounts = [];
  List<int> unpaidCounts = [];
  List<Map<String, dynamic>> dailySnapshots = [];

  @override
  void initState() {
    super.initState();
    _fetchCollectionStatus();
    _fetchDailySnapshots();
  }

  Future<void> _fetchDailySnapshots() async {
    final snapshots = await FirebaseFirestore.instance
        .collection('admin')
        .doc('summary')
        .collection('dailyStatus')
        .orderBy('createdAt', descending: true)
        .limit(7)
        .get();

    dailySnapshots = [];

    for (var doc in snapshots.docs) {
      final data = doc.data();
      final dateStr = data['date'] ?? ''; // already saved as 'yyyy-MM-dd'
      final formatted = dateStr.substring(5); // show as MM-dd

      dailySnapshots.add({
        'date': formatted,
        'paid': data['paidCount'] ?? 0,
        'unpaid': data['unpaidCount'] ?? 0,
      });
    }

    dailySnapshots = dailySnapshots.reversed.toList(); // Oldest to latest
    setState(() {});
  }

  Future<void> _saveDailyStatusSnapshot(int paidCount, int unpaidCount) async {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final docRef = FirebaseFirestore.instance
        .collection('admin')
        .doc('summary')
        .collection('dailyStatus')
        .doc(formattedDate); // One doc per day

    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      await docRef.set({
        'date': formattedDate,
        'paidCount': paidCount,
        'unpaidCount': unpaidCount,
        'createdAt': Timestamp.now(),
      });
      print('✅ Daily snapshot saved for $formattedDate');
    } else {
      print('⚠️ Snapshot already exists for $formattedDate');
    }
  }

  Future<void> _fetchCollectionStatus() async {
    int paid = 0;
    int unpaid = 0;

    try {
      final routesSnapshot =
          await FirebaseFirestore.instance.collection('routes').get();

      for (var routeDoc in routesSnapshot.docs) {
        final shopsSnapshot =
            await routeDoc.reference.collection('shops').get();
        for (var shopDoc in shopsSnapshot.docs) {
          final data = shopDoc.data();
          if (data['status'] == 'Paid') {
            paid++;
          } else {
            unpaid++;
          }
        }
      }

      setState(() {
        collectedCount = paid;
        notCollectedCount = unpaid;
        isLoading = false;
      });

      // Save to Firestore
      await _saveDailyStatusSnapshot(paid, unpaid);
    } catch (e) {
      print('❌ Error fetching collection status: $e');
      setState(() => isLoading = false);
    }
  }

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
        backgroundColor: Colors.green.shade800,
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
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      // ← ADD HERE
                      icon: const Icon(Icons.save),
                      label: const Text("Save Daily Snapshot"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        await _saveDailyStatusSnapshot(
                            collectedCount, notCollectedCount);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("✅ Snapshot saved successfully")),
                        );
                      },
                    ),
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
                    const SizedBox(height: 20),
                    Text("📈 Daily Collection Trend",
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
                                      return Text(dailySnapshots[index]
                                          ['date']); // already formatted
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              // Green Line - Paid
                              LineChartBarData(
                                spots:
                                    List.generate(dailySnapshots.length, (i) {
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
                              // Red Line - Unpaid
                              LineChartBarData(
                                spots:
                                    List.generate(dailySnapshots.length, (i) {
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
