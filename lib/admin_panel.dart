import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001B2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001B2E),
        title: const Text("Admin"),
        actions: [
          IconButton(
            onPressed: () => fb.FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [ReportsScreen(), HeatmapScreen()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white30,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF001B2E),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.report_outlined),
            label: 'Raporlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Heatmap',
          ),
        ],
      ),
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _status = "open";
  bool _onlyMissingStatus = false;

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return "";
    return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(400);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("Açık", _status == "open", () {
                setState(() {
                  _status = "open";
                  _onlyMissingStatus = false;
                });
              }),
              _pill("Çözüldü", _status == "resolved", () {
                setState(() {
                  _status = "resolved";
                  _onlyMissingStatus = false;
                });
              }),
              _pill("Yoksay", _status == "ignored", () {
                setState(() {
                  _status = "ignored";
                  _onlyMissingStatus = false;
                });
              }),
              _pill("Eski (status yok)", _onlyMissingStatus, () {
                setState(() {
                  _onlyMissingStatus = true;
                });
              }),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _backfillMissingToOpen,
                child: const Text("Eski raporları 'Açık' yap"),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final items = docs.map((d) => {"id": d.id, ...d.data()}).toList();

              final filtered = items.where((r) {
                final st = (r['status'] as String?) ?? "";
                if (_onlyMissingStatus) return st.isEmpty;
                if (st.isEmpty) return _status == "open";
                return st == _status;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text("Kayıt yok."));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                itemCount: filtered.length,
                itemBuilder: (c, i) {
                  final r = filtered[i];
                  final id = r['id'] as String;
                  final reason = (r['reason'] as String?) ?? "";
                  final targetType = (r['targetType'] as String?) ?? "";
                  final targetId = (r['targetId'] as String?) ?? "";
                  final targetName = (r['targetName'] as String?) ?? "";
                  final reporterName = (r['reporterName'] as String?) ?? "";
                  final snapshotText = (r['snapshotText'] as String?) ?? "";
                  final createdAt = r['createdAt'] as Timestamp?;
                  final st = (r['status'] as String?) ?? "open";

                  return Card(
                    color: Colors.white.withAlpha(15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withAlpha(20)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _tag("Tür: $targetType"),
                              _tag("Durum: $st"),
                              _tag(_fmtTs(createdAt)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            reason,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Hedef: ${targetName.isEmpty ? targetId : targetName}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            "Raporlayan: $reporterName",
                            style: const TextStyle(color: Colors.white54),
                          ),
                          if (snapshotText.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(13),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withAlpha(16),
                                ),
                              ),
                              child: Text(
                                snapshotText,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _setStatus(id, "open"),
                                  child: const Text("Açık"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _setStatus(id, "ignored"),
                                  child: const Text("Yoksay"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: () => _setStatus(id, "resolved"),
                                  child: const Text("Çözüldü"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pill(String t, bool on, VoidCallback tap) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: on ? Colors.cyanAccent.withAlpha(64) : Colors.white10,
        border: Border.all(
          color: on ? Colors.cyanAccent.withAlpha(140) : Colors.white24,
        ),
      ),
      child: Text(
        t,
        style: TextStyle(
          color: on ? Colors.cyanAccent : Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    ),
  );

  Widget _tag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: Colors.white.withAlpha(12),
      border: Border.all(color: Colors.white.withAlpha(18)),
    ),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Future<void> _setStatus(String reportId, String status) async {
    await FirebaseFirestore.instance.collection('reports').doc(reportId).update(
      {"status": status, "statusAt": FieldValue.serverTimestamp()},
    );
  }

  Future<void> _backfillMissingToOpen() async {
    final db = FirebaseFirestore.instance;
    final snap = await db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(800)
        .get();

    final batch = db.batch();
    int n = 0;

    for (final d in snap.docs) {
      final data = d.data();
      final st = (data['status'] as String?) ?? "";
      if (st.isEmpty) {
        batch.update(d.reference, {
          "status": "open",
          "statusAt": FieldValue.serverTimestamp(),
        });
        n++;
      }
      if (n >= 400) break;
    }

    if (n == 0) return;
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("$n rapor güncellendi.")));
  }
}

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  int _grid = 20;
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final since = Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: _days)),
    );

    final q = FirebaseFirestore.instance
        .collection('reports')
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt', descending: true)
        .limit(2500);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("${_days} gün", false, () {}),
              OutlinedButton(
                onPressed: () => setState(() => _days = 7),
                child: const Text("7 gün"),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _days = 30),
                child: const Text("30 gün"),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _days = 90),
                child: const Text("90 gün"),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => _grid = 16),
                child: const Text("16x16"),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _grid = 20),
                child: const Text("20x20"),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _grid = 24),
                child: const Text("24x24"),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text("Veri yok."));

              final counts = List.generate(_grid * _grid, (_) => 0);
              int maxV = 0;

              for (final d in docs) {
                final r = d.data();
                final targetType = (r['targetType'] as String?) ?? "";
                final targetId = (r['targetId'] as String?) ?? "";
                final reason = (r['reason'] as String?) ?? "";
                final cell = _cellIndex(
                  grid: _grid,
                  targetType: targetType,
                  targetId: targetId,
                  reason: reason,
                );
                final v = ++counts[cell];
                if (v > maxV) maxV = v;
              }

              return Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth;
                    final size = math.min(w / _grid, 22.0);
                    return Center(
                      child: SizedBox(
                        width: size * _grid,
                        child: Wrap(
                          spacing: 1,
                          runSpacing: 1,
                          children: List.generate(_grid * _grid, (i) {
                            final v = counts[i];
                            final p = maxV == 0 ? 0.0 : (v / maxV);
                            return Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.cyanAccent.withAlpha(
                                  (10 + (p * 245)).round().clamp(10, 255),
                                ),
                              ),
                              child: v == 0
                                  ? null
                                  : Center(
                                      child: Text(
                                        v >= 100 ? "99+" : v.toString(),
                                        style: TextStyle(
                                          fontSize: size <= 14 ? 8 : 10,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _pill(String t, bool on, VoidCallback tap) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: on ? Colors.cyanAccent.withAlpha(64) : Colors.white10,
        border: Border.all(
          color: on ? Colors.cyanAccent.withAlpha(140) : Colors.white24,
        ),
      ),
      child: Text(
        t,
        style: TextStyle(
          color: on ? Colors.cyanAccent : Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    ),
  );

  int _cellIndex({
    required int grid,
    required String targetType,
    required String targetId,
    required String reason,
  }) {
    final a = _fnv1a32("$targetType|$targetId");
    final b = _fnv1a32(reason.trim().toLowerCase());
    final x = a % grid;
    final y = b % grid;
    return y * grid + x;
  }

  int _fnv1a32(String s) {
    const int fnvPrime = 16777619;
    int hash = 2166136261;
    final bytes = s.codeUnits;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
