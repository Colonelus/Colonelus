import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'widgets/admin_user_actions_panel.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Bootstrap(),
    );
  }
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _init = _initialize();
  }

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (s.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.error.toString()),
              ),
            ),
          );
        }
        return const Gate();
      },
    );
  }
}

class Gate extends StatelessWidget {
  const Gate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, s) {
        final u = s.data;
        if (u == null) return const Login();
        return AdminGuard(uid: u.uid);
      },
    );
  }
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _busy = false;
  String? _err;

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final provider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(provider);
    } catch (e) {
      _err = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sırdaş Admin',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    const Text('Google ile giriş yap',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _google,
                        child: Text(_busy ? '...' : 'Google ile Giriş'),
                      ),
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 12),
                      Text(_err!,
                          style: const TextStyle(color: Color(0xFFFF6B6B))),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminGuard extends StatelessWidget {
  final String uid;
  const AdminGuard({super.key, required this.uid});

  Stream<DocumentSnapshot<Map<String, dynamic>>> _allowDoc() {
    return FirebaseFirestore.instance
        .collection('admin_allowlist')
        .doc(uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _allowDoc(),
      builder: (context, s) {
        if (s.hasError) {
          return Scaffold(body: Center(child: Text(s.error.toString())));
        }
        final exists = s.data?.exists == true;
        if (!exists) return const NoAccess();
        return const AdminHome();
      },
    );
  }
}

class NoAccess extends StatelessWidget {
  const NoAccess({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yetki Yok'),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Çıkış'),
          ),
        ],
      ),
      body: const Center(child: Text('Bu hesap admin değil.')),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;
  String _q = '';
  final TextEditingController _qc = TextEditingController();

  @override
  void dispose() {
    _qc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sırdaş Admin'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
                child: Text(uid,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white54))),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Çıkış'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qc,
                    decoration: const InputDecoration(
                      hintText: 'Ara: uid / rumuz / targetId / secretId',
                      filled: true,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        label: Text('Raporlar'),
                        icon: Icon(Icons.flag_outlined)),
                    ButtonSegment(
                        value: 1,
                        label: Text('Secrets'),
                        icon: Icon(Icons.delete_outline)),
                    ButtonSegment(
                        value: 2,
                        label: Text('Kullanıcılar'),
                        icon: Icon(Icons.people_alt_outlined)),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ReportsTab(q: _q),
                SecretsTab(q: _q),
                UsersTab(q: _q),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsTab extends StatelessWidget {
  final String q;
  const ReportsTab({super.key, required this.q});

  Query<Map<String, dynamic>> _base() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(300);
  }

  bool _match(Map<String, dynamic> d, String q) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    final fields = <String>[
      (d['reporterId'] ?? '').toString(),
      (d['reporterName'] ?? '').toString(),
      (d['targetId'] ?? '').toString(),
      (d['targetName'] ?? '').toString(),
      (d['targetType'] ?? '').toString(),
      (d['reason'] ?? '').toString(),
      (d['secretId'] ?? '').toString(),
      (d['convId'] ?? '').toString(),
      (d['status'] ?? '').toString(),
    ].join(' ').toLowerCase();
    return fields.contains(s);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _base().snapshots(),
      builder: (context, s) {
        if (s.hasError) return Center(child: Text(s.error.toString()));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        final items = docs.where((d) => _match(d.data(), q)).toList();
        if (items.isEmpty) return const Center(child: Text('Rapor yok.'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c, i) => _ReportCard(doc: items[i]),
        );
      },
    );
  }
}

class _ReportCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _ReportCard({required this.doc});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _busy = false;

  Future<void> _setStatus(String s) async {
    await widget.doc.reference.update({'status': s});
  }

  Future<void> _strikeUser({required String uid, required String level}) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final cur = (snap.data()?['strikeCount'] as num?)?.toInt() ?? 0;
      final next = cur + 1;
      final data = <String, Object?>{
        'strikeCount': next,
        'lastStrikeAt': now,
      };

      if (level == 'suspend24h') {
        data['suspendedUntil'] =
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));
        data['banned'] = false;
      } else if (level == 'suspend30d') {
        data['suspendedUntil'] =
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
        data['banned'] = false;
      } else if (level == 'ban') {
        data['banned'] = true;
        data['bannedAt'] = now;
        data['suspendedUntil'] = null;
      } else {
        data['banned'] = false;
      }

      tx.set(userRef, data, SetOptions(merge: true));
    });
  }

  Future<String?> _resolveTargetUserId(Map<String, dynamic> r) async {
    final t = (r['targetType'] ?? '').toString();
    if (t == 'user') return (r['targetId'] ?? '').toString();
    if (t == 'secret') {
      final sid = (r['secretId'] ?? r['targetId'] ?? '').toString();
      if (sid.isEmpty) return null;
      final sdoc =
          await FirebaseFirestore.instance.collection('secrets').doc(sid).get();
      final aid = (sdoc.data()?['authorId'] ?? '').toString();
      if (aid.isEmpty) return null;
      return aid;
    }
    return null;
  }

  Future<void> _deleteSecretFromReport(Map<String, dynamic> r) async {
    final sid = (r['secretId'] ?? r['targetId'] ?? '').toString();
    if (sid.isEmpty) return;
    await FirebaseFirestore.instance.collection('secrets').doc(sid).delete();
  }

  Future<void> _doAction(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data();
    final status = (d['status'] ?? 'open').toString();
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final targetType = (d['targetType'] ?? '').toString();
    final title = '${(d['targetName'] ?? '').toString()} · $targetType';
    final reason = (d['reason'] ?? '').toString();
    final reporter = (d['reporterName'] ?? '').toString();
    final targetId = (d['targetId'] ?? '').toString();
    final secretId = (d['secretId'] ?? '').toString();
    final convId = (d['convId'] ?? '').toString();
    final snapshotText = (d['snapshotText'] ?? '').toString();
    final isOpen = status == 'open';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w900))),
                _Pill(text: status.toUpperCase()),
              ],
            ),
            const SizedBox(height: 8),
            Text(reason, style: const TextStyle(color: Colors.white70)),
            if (snapshotText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(snapshotText,
                    style:
                        const TextStyle(color: Colors.white70, height: 1.25)),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniKeyVal(k: 'reporter', v: reporter),
                _MiniKeyVal(k: 'targetId', v: targetId),
                if (secretId.isNotEmpty)
                  _MiniKeyVal(k: 'secretId', v: secretId),
                if (convId.isNotEmpty) _MiniKeyVal(k: 'convId', v: convId),
                if (createdAt != null)
                  _MiniKeyVal(k: 'at', v: createdAt.toIso8601String()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (!isOpen || _busy)
                        ? null
                        : () => _doAction(() => _setStatus('resolved')),
                    child: const Text('Resolved'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (!isOpen || _busy)
                        ? null
                        : () => _doAction(() => _setStatus('dismissed')),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _doAction(() async {
                              final ok =
                                  await _confirm(context, 'Silinsin mi?');
                              if (ok != true) return;
                              await widget.doc.reference.delete();
                            }),
                    child: const Text('Sil'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isOpen) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _doAction(() async {
                              final uid = await _resolveTargetUserId(d);
                              if (uid == null) throw 'userId bulunamadı';
                              await _strikeUser(uid: uid, level: 'strike');
                              await _setStatus('resolved');
                            }),
                    child: const Text('Strike'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _doAction(() async {
                              final uid = await _resolveTargetUserId(d);
                              if (uid == null) throw 'userId bulunamadı';
                              await _strikeUser(uid: uid, level: 'suspend24h');
                              await _setStatus('resolved');
                            }),
                    child: const Text('24h Suspend'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _doAction(() async {
                              final uid = await _resolveTargetUserId(d);
                              if (uid == null) throw 'userId bulunamadı';
                              await _strikeUser(uid: uid, level: 'suspend30d');
                              await _setStatus('resolved');
                            }),
                    child: const Text('30d Suspend'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900),
                    onPressed: _busy
                        ? null
                        : () => _doAction(() async {
                              final ok = await _confirm(
                                  context, 'SÜRESİZ BANLANSIN MI?');
                              if (ok != true) return;
                              final uid = await _resolveTargetUserId(d);
                              if (uid == null) throw 'userId bulunamadı';
                              await _strikeUser(uid: uid, level: 'ban');
                              await _setStatus('resolved');
                            }),
                    child: const Text('SÜRESİZ BAN'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (targetType == 'secret')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _doAction(() async {
                              final ok = await _confirm(context,
                                  'Secret sil + Strike uygulansın mı?');
                              if (ok != true) return;
                              final uid = await _resolveTargetUserId(d);
                              if (uid == null) throw 'userId bulunamadı';
                              await _deleteSecretFromReport(d);
                              await _strikeUser(uid: uid, level: 'strike');
                              await _setStatus('resolved');
                            }),
                    child: const Text('Secret Sil + Strike'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class SecretsTab extends StatelessWidget {
  final String q;
  const SecretsTab({super.key, required this.q});

  Query<Map<String, dynamic>> _base() {
    return FirebaseFirestore.instance
        .collection('secrets')
        .orderBy('createdAt', descending: true)
        .limit(300);
  }

  bool _match(Map<String, dynamic> d, String q) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    final fields = <String>[
      (d['authorId'] ?? '').toString(),
      (d['authorName'] ?? '').toString(),
      (d['content'] ?? '').toString(),
      (d['tip'] ?? '').toString(),
    ].join(' ').toLowerCase();
    return fields.contains(s);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _base().snapshots(),
      builder: (context, s) {
        if (s.hasError) return Center(child: Text(s.error.toString()));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        final items = docs.where((d) => _match(d.data(), q)).toList();
        if (items.isEmpty) return const Center(child: Text('Secret yok.'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c, i) => _SecretCard(doc: items[i]),
        );
      },
    );
  }
}

class _SecretCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _SecretCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final author = (d['authorName'] ?? '').toString();
    final authorId = (d['authorId'] ?? '').toString();
    final content = (d['content'] ?? '').toString();
    final tip = (d['tip'] ?? '').toString();
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final expiresAt = (d['expiresAt'] as Timestamp?)?.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(author,
                        style: const TextStyle(fontWeight: FontWeight.w900))),
                _Pill(text: tip),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(content,
                  style: const TextStyle(color: Colors.white70, height: 1.25)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniKeyVal(k: 'id', v: doc.id),
                _MiniKeyVal(k: 'authorId', v: authorId),
                if (createdAt != null)
                  _MiniKeyVal(k: 'at', v: createdAt.toIso8601String()),
                if (expiresAt != null)
                  _MiniKeyVal(k: 'exp', v: expiresAt.toIso8601String()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _copy(context, content);
                    },
                    child: const Text('Kopyala'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok = await _confirm(context, 'Secret silinsin mi?');
                      if (ok != true) return;
                      await doc.reference.delete();
                    },
                    child: const Text('Sil'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UsersTab extends StatelessWidget {
  final String q;
  const UsersTab({super.key, required this.q});

  Future<Map<String, dynamic>?> _load() async {
    final s = q.trim();
    if (s.isEmpty) return null;
    final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('adminGetUser');
    final res = await fn.call(<String, dynamic>{'query': s});
    final d = (res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{});

    final users = (d['users'] is List)
        ? List<Map<String, dynamic>>.from(
            (d['users'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : const <Map<String, dynamic>>[];

    if (users.isEmpty) return <String, dynamic>{};

    final u = users.first;

    return <String, dynamic>{
      'uid': (u['uid'] ?? '').toString(),
      'user': u,
      'auth': <String, dynamic>{
        'email': (u['email'] ?? '').toString(),
        'phoneNumber': '',
        'createdAt': (u['createdAt'] ?? '').toString(),
        'lastSignIn': (u['lastSignInAt'] ?? '').toString(),
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = q.trim();
    if (s.isEmpty) return const Center(child: Text('UID yaz.'));
    return FutureBuilder<Map<String, dynamic>?>(
      future: _load(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(snap.error.toString()));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data;
        if (d == null || d.isEmpty) {
          return const Center(child: Text('Kullanıcı yok.'));
        }
        final uid = (d['uid'] ?? '').toString();
        final user = (d['user'] is Map
            ? Map<String, dynamic>.from(d['user'] as Map)
            : null);
        final auth = (d['auth'] is Map
            ? Map<String, dynamic>.from(d['auth'] as Map)
            : null);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [_UserDataCard(uid: uid, user: user, auth: auth)],
        );
      },
    );
  }
}

class _UserDataCard extends StatefulWidget {
  final String uid;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? auth;
  const _UserDataCard(
      {required this.uid, required this.user, required this.auth});

  @override
  State<_UserDataCard> createState() => _UserDataCardState();
}

class _UserDataCardState extends State<_UserDataCard> {
  bool _busy = false;

  Future<void> _strikeUser({required String uid, required String level}) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final cur = (snap.data()?['strikeCount'] as num?)?.toInt() ?? 0;
      final next = cur + 1;
      final data = <String, Object?>{
        'strikeCount': next,
        'lastStrikeAt': now,
      };

      if (level == 'suspend24h') {
        data['suspendedUntil'] =
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));
        data['banned'] = false;
      } else if (level == 'suspend30d') {
        data['suspendedUntil'] =
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
        data['banned'] = false;
      } else if (level == 'ban') {
        data['banned'] = true;
        data['bannedAt'] = now;
        data['suspendedUntil'] = null;
      } else {
        data['banned'] = false;
      }

      tx.set(userRef, data, SetOptions(merge: true));
    });
  }

  Future<void> _doAction(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.user ?? const <String, dynamic>{};
    final rumuz =
        ((d['displayName'] ?? d['nickname'] ?? d['username'] ?? d['rumuz']) ??
                '')
            .toString();
    final inci = (d['coins'] as num?)?.toInt() ?? 0;
    final isVip = (d['isVip'] as bool?) ?? false;
    final strike = (d['reportCount'] as num?)?.toInt() ?? 0;
    final bannedUntil = d['bannedUntil'];
    final suspendedUntil = d['suspendedUntil'] ?? d['vipUntil'];
    final banned = (d['banned'] as bool?) == true || bannedUntil != null;
    final suspended = suspendedUntil != null;
    final email =
        widget.auth != null ? (widget.auth!['email'] ?? '').toString() : '';
    final phone = widget.auth != null
        ? (widget.auth!['phoneNumber'] ?? '').toString()
        : '';
    final createdAt =
        widget.auth != null ? (widget.auth!['createdAt'] ?? '').toString() : '';
    final lastSignIn = widget.auth != null
        ? (widget.auth!['lastSignIn'] ?? '').toString()
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rumuz.isEmpty ? widget.uid : rumuz,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (isVip) const _Pill(text: 'VIP'),
              if (banned) const _Pill(text: 'BANNED'),
              if (!banned && suspended) const _Pill(text: 'SUSPENDED'),
              _Pill(text: 'STR $strike'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MiniKeyVal(k: 'uid', v: widget.uid),
              if (email.isNotEmpty) _MiniKeyVal(k: 'email', v: email),
              if (phone.isNotEmpty) _MiniKeyVal(k: 'phone', v: phone),
              if (createdAt.isNotEmpty)
                _MiniKeyVal(k: 'createdAt', v: createdAt),
              if (lastSignIn.isNotEmpty)
                _MiniKeyVal(k: 'lastSignIn', v: lastSignIn),
              _MiniKeyVal(k: 'inci', v: '$inci'),
              _MiniKeyVal(k: 'vip', v: isVip ? '1' : '0'),
              if (bannedUntil != null)
                _MiniKeyVal(k: 'bannedUntil', v: bannedUntil.toString()),
              if (suspendedUntil != null)
                _MiniKeyVal(k: 'suspendedUntil', v: suspendedUntil.toString()),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () => _copy(context, widget.uid),
                child: const Text('UID kopyala'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _doAction(
                        () => _strikeUser(uid: widget.uid, level: 'strike')),
                child: const Text('Strike (+1)'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _doAction(() =>
                        _strikeUser(uid: widget.uid, level: 'suspend24h')),
                child: const Text('24h Suspend'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _doAction(() =>
                        _strikeUser(uid: widget.uid, level: 'suspend30d')),
                child: const Text('30d Suspend'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900),
                onPressed: _busy
                    ? null
                    : () => _doAction(() async {
                          final ok =
                              await _confirm(context, 'SÜRESİZ BANLANSIN MI?');
                          if (ok == true) {
                            await _strikeUser(uid: widget.uid, level: 'ban');
                          }
                        }),
                child: const Text('SÜRESİZ BAN'),
              ),
              if (banned || suspended)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _doAction(() async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.uid)
                                .update({
                              'banned': false,
                              'suspendedUntil': null,
                            });
                          }),
                  child: const Text('Cezayı Kaldır'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AdminUserActionsPanel(
            user: <String, dynamic>{
              ...d,
              'uid': widget.uid,
            },
            onUpdated: () {},
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(38)),
      ),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _MiniKeyVal extends StatelessWidget {
  final String k;
  final String v;
  const _MiniKeyVal({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Text('$k: $v',
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
    );
  }
}

Future<bool?> _confirm(BuildContext context, String t) {
  return showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Onay'),
      content: Text(t),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç')),
        ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Tamam')),
      ],
    ),
  );
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Kopyalandı')));
  }
}

Widget buildAdminActions(Map<String, dynamic> user, VoidCallback refresh) {
  return AdminUserActionsPanel(
    user: user,
    onUpdated: refresh,
  );
}
