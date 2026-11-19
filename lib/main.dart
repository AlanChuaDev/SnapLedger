import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF24404F), gold = Color(0xFFF2B01E), outC = Color(0xFFD6455D), inC = Color(0xFF2A9D68);
const eC = [['🚗', 'catTransport'], ['🍔', 'catFood'], ['💧', 'catBills'], ['👕', 'catClothing'], ['🎮', 'catEntertainment'], ['🏋️', 'catFitness'], ['💄', 'catBeauty'], ['🛋️', 'catFurniture'], ['🐱', 'catPets'], ['🛒', 'catShopping'], ['✈️', 'catTravel'], ['🌀', 'catOthers'], ['💸', 'catFineInterest']];
const iC = [['💰', 'catSalary'], ['🧧', 'catBonus'], ['🌟', 'catReward'], ['📈', 'catDividend'], ['🏦', 'catInvestment'], ['🎲', 'catLottery'], ['💴', 'catTips'], ['🔙', 'catRefund']];

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String ymd(DateTime d) => '${d.year}/${d.month}/${d.day}';
DateTime pd(String s) { final d = s.split('/'); try { return DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2])); } catch (_) { return DateTime.now(); } }
String fm(num n) => n.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
int ts(Map t) { final h = '${t['time'] ?? '0:0'}'.split(':'); final d = pd('${t['fullDate']}'); return DateTime(d.year, d.month, d.day, int.tryParse(h[0]) ?? 0, h.length > 1 ? int.tryParse(h[1]) ?? 0 : 0).millisecondsSinceEpoch; }
String icOf(String c) { final m = RegExp(r'^(\S+)\s').firstMatch(c); return m == null ? '🔁' : m.group(1)!; }
String nmOf(String c) => c.replaceFirst(RegExp(r'^\S+\s'), '').split(':').first;
String lbl(String k) => k == '支出' ? st.f('支出', 'Expense') : k == '收入' ? st.f('收入', 'Income') : st.f('转账', 'Transfer');

class Store extends ChangeNotifier {
  late SharedPreferences p;
  List<Map<String, dynamic>> tx = [], ac = [];
  Map<String, dynamic> ex = {}, S = {};
  String cur = 'RM', lang = 'en';
  String t(String k) => '${S[k] ?? k}';
  String f(String zh, String en) => lang == 'zh' ? zh : en;
  List<Map<String, dynamic>> rd(String k) => (jsonDecode(p.getString(k) ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<void> init() async {
    p = await SharedPreferences.getInstance();
    tx = rd('tx'); ac = rd('ac');
    ex = Map<String, dynamic>.from(jsonDecode(p.getString('ex') ?? '{}') as Map);
    cur = p.getString('cur') ?? 'RM';
    final l = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final all = jsonDecode(await rootBundle.loadString('assets/strings.json')) as Map<String, dynamic>;
    lang = all.containsKey(l) ? l : 'en';
    S = Map<String, dynamic>.from(all[lang] as Map);
  }
  Future<void> save() async {
    await p.setString('tx', jsonEncode(tx)); await p.setString('ac', jsonEncode(ac));
    await p.setString('ex', jsonEncode(ex)); await p.setString('cur', cur);
    notifyListeners();
  }
  void bump(dynamic n, double d) { for (final a in ac) { if (a['name'] == n) a['balance'] = ((_n(a['balance']) + d) * 100).round() / 100; } }
  void eff(Map t, int k) {
    final a = _n(t['amount']) * k;
    if (t['type'] == '转账') { bump(t['account'], -a - _n(t['fee']) * k); bump(t['toAccount'], a); } else { bump(t['account'], t['type'] == '支出' ? -a : a); }
  }
}

final st = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  await st.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'SnapLedger', debugShowCheckedModeBanner: false, themeMode: ThemeMode.system,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: navy),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: navy, brightness: Brightness.dark),
        home: const Home());
}

Future<bool> ask(BuildContext c, String m) async => await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(content: Text(m), actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(st.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(st.f('确定', 'OK'))),
        ])) ?? false;

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext c) => ListenableBuilder(listenable: st, builder: (c, _) {
        final td = ymd(DateTime.now());
        double e = 0, n = 0;
        for (final t in st.tx) { if (t['fullDate'] == td) { if (t['type'] == '支出') e += _n(t['amount']); if (t['type'] == '收入') n += _n(t['amount']); } }
        final total = st.ac.fold<double>(0, (s, a) => s + _n(a['balance']));
        return Scaffold(
          body: Column(children: [
            Container(width: double.infinity, color: navy, padding: EdgeInsets.fromLTRB(20, MediaQuery.of(c).padding.top + 14, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.t('totalAssets'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text('${st.cur} ${fm(total)}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${st.t('todayExpense')} ${fm(e)}     ${st.t('todayIncome')} ${fm(n)}', style: const TextStyle(color: Colors.white, fontSize: 14)),
              ])),
            Expanded(child: [TxPage(), StatsPage(), WalletPage()][i]),
          ]),
          floatingActionButton: i == 2 ? null : FloatingActionButton.extended(backgroundColor: gold, foregroundColor: const Color(0xFF2A2000), onPressed: () => txSheet(c, null), icon: const Icon(Icons.add), label: Text(st.t('addTransaction'))),
          bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: [
            NavigationDestination(icon: const Icon(Icons.receipt_long), label: st.t('tabTransaction')),
            NavigationDestination(icon: const Icon(Icons.bar_chart), label: st.t('tabStatistics')),
            NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: st.t('tabWallet')),
          ]),
        );
      });
}

class TxPage extends StatelessWidget {
  const TxPage({super.key});
  @override
  Widget build(BuildContext c) {
    if (st.tx.isEmpty) return Center(child: Text(st.f('还没有记录，点“记一笔”开始', 'Nothing yet. Tap Add to start.'), style: const TextStyle(color: Colors.grey)));
    final l = [...st.tx]..sort((a, b) => ts(b).compareTo(ts(a)));
    final w = <Widget>[];
    String d = '';
    for (final t in l) {
      if ('${t['fullDate']}' != d) { d = '${t['fullDate']}'; w.add(Padding(padding: const EdgeInsets.fromLTRB(6, 14, 6, 4), child: Text(d, style: const TextStyle(fontSize: 13, color: Colors.grey)))); }
      final ty = t['type'];
      final col = ty == '支出' ? outC : ty == '收入' ? inC : null;
      final rm = '${t['remark'] ?? ''}';
      w.add(Card(margin: const EdgeInsets.only(bottom: 6), elevation: 0, child: ListTile(
        leading: CircleAvatar(child: Text(icOf('${t['category']}'))),
        title: Text(ty == '转账' ? '${t['account']} → ${t['toAccount']}' : nmOf('${t['category']}')),
        subtitle: Text(rm.isEmpty ? '${t['account']}' : rm),
        trailing: Text('${ty == '支出' ? '-' : ty == '收入' ? '+' : ''}${fm(_n(t['amount']))}', style: TextStyle(fontWeight: FontWeight.w600, color: col)),
        onTap: () => txSheet(c, t))));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: w);
  }
}

Future<void> txSheet(BuildContext c, Map<String, dynamic>? t) async {
  if (st.ac.isEmpty) st.ac.add({'id': 'asset_default', 'name': '一般账户', 'balance': 0.0, 'type': '一般账户'});
  await showModalBottomSheet<void>(context: c, isScrollControlled: true, showDragHandle: true, builder: (_) => TxSheet(t));
}

class TxSheet extends StatefulWidget {
  final Map<String, dynamic>? t;
  const TxSheet(this.t, {super.key});
  @override
  State<TxSheet> createState() => _TxSheetState();
}

class _TxSheetState extends State<TxSheet> {
  late String ty, cat, acc, to;
  late DateTime dt;
  late TextEditingController am, rm;
  @override
  void initState() {
    super.initState();
    final t = widget.t;
    ty = '${t?['type'] ?? '支出'}';
    cat = t == null || ty == '转账' ? '' : '${t['category']}';
    final names = st.ac.map((a) => '${a['name']}').toList();
    acc = names.contains('${t?['account']}') ? '${t?['account']}' : names.first;
    to = names.contains('${t?['toAccount']}') ? '${t?['toAccount']}' : names.firstWhere((n) => n != acc, orElse: () => names.first);
    dt = t == null ? DateTime.now() : pd('${t['fullDate']}');
    am = TextEditingController(text: t == null ? '' : '${t['amount']}');
    rm = TextEditingController(text: '${t?['remark'] ?? ''}');
  }

  Future<void> ok() async {
    final a = double.tryParse(am.text.replaceAll(',', '.')) ?? 0;
    if (a <= 0 || (ty != '转账' && cat.isEmpty) || (ty == '转账' && to == acc)) return;
    final old = widget.t;
    if (old != null) { st.eff(old, -1); st.tx.remove(old); }
    final now = DateTime.now();
    final n = <String, dynamic>{
      ...?old,
      'id': old?['id'] ?? 'tx_${now.microsecondsSinceEpoch.toRadixString(36)}',
      'type': ty, 'category': ty == '转账' ? to : cat, 'amount': a, 'account': acc,
      'time': old?['time'] ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'fullDate': ymd(dt), 'remark': rm.text.trim(), 'updatedAt': now.millisecondsSinceEpoch,
    };
    if (ty == '转账') { n['toAccount'] = to; } else { n.remove('toAccount'); n.remove('fee'); }
    st.eff(n, 1); st.tx.insert(0, n);
    await st.save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> del() async {
    if (await ask(context, st.f('确定删除吗？', 'Delete this?'))) {
      st.eff(widget.t!, -1); st.tx.remove(widget.t);
      await st.save();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget drop(String label, String v, ValueChanged<String> on) => Padding(padding: const EdgeInsets.only(top: 8), child: DropdownButtonFormField<String>(
        value: v, decoration: InputDecoration(labelText: label),
        items: [for (final a in st.ac) DropdownMenuItem(value: '${a['name']}', child: Text('${a['name']}'))],
        onChanged: (x) => on(x!)));

  @override
  Widget build(BuildContext c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: [for (final k in ['支出', '收入', '转账']) ButtonSegment<String>(value: k, label: Text(lbl(k)))],
            selected: {ty}, onSelectionChanged: (s) => setState(() { ty = s.first; cat = ''; })),
          TextField(controller: am, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700), decoration: const InputDecoration(hintText: '0.00', border: InputBorder.none)),
          if (ty != '转账') Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in (ty == '收入' ? iC : eC)) ChoiceChip(label: Text('${e[0]} ${st.t(e[1])}'), selected: cat == '${e[0]} ${st.t(e[1])}', onSelected: (_) => setState(() => cat = '${e[0]} ${st.t(e[1])}')),
          ]),
          drop(st.f('账户', 'Account'), acc, (v) => setState(() => acc = v)),
          if (ty == '转账') drop(st.f('转入账户', 'To account'), to, (v) => setState(() => to = v)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: Text(ymd(dt)), onTap: () async {
            final p = await showDatePicker(context: c, initialDate: dt, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (p != null) setState(() => dt = p);
          }),
          TextField(controller: rm, decoration: InputDecoration(labelText: st.t('remark'))),
          const SizedBox(height: 12),
          Row(children: [
            if (widget.t != null) TextButton(onPressed: del, child: Text(st.t('delete'), style: const TextStyle(color: outC))),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(st.t('cancel'))),
            FilledButton(onPressed: ok, child: Text(st.t('save'))),
          ]),
        ])));
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsState();
}

class _StatsState extends State<StatsPage> {
  DateTime mo = DateTime(DateTime.now().year, DateTime.now().month);
  String k = '支出';
  Widget stat(String l, double v, Color? col) => Expanded(child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(fm(v), style: TextStyle(fontWeight: FontWeight.w700, color: col)),
      ]))));
  @override
  Widget build(BuildContext c) {
    final l = st.tx.where((t) { final d = '${t['fullDate']}'.split('/'); return d.length > 2 && d[0] == '${mo.year}' && d[1] == '${mo.month}'; }).toList();
    double sum(String ty) => l.where((t) => t['type'] == ty).fold(0.0, (s, t) => s + _n(t['amount']));
    final e = sum('支出'), n = sum('收入'), tot = k == '支出' ? e : n;
    final by = <String, double>{};
    for (final t in l.where((t) => t['type'] == k)) { final cn = '${t['category']}'.split(':').first.trim(); by[cn] = (by[cn] ?? 0) + _n(t['amount']); }
    final rows = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: () => setState(() => mo = DateTime(mo.year, mo.month - 1)), icon: const Icon(Icons.chevron_left)),
        Text('${mo.year} / ${mo.month.toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(onPressed: () => setState(() => mo = DateTime(mo.year, mo.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      Row(children: [stat(st.t('statsExpense'), e, outC), stat(st.t('statsIncome'), n, inC), stat(st.t('statsBalance'), n - e, null)]),
      const SizedBox(height: 8),
      SegmentedButton<String>(segments: [for (final x in ['支出', '收入']) ButtonSegment<String>(value: x, label: Text(lbl(x)))], selected: {k}, onSelectionChanged: (s) => setState(() => k = s.first)),
      const SizedBox(height: 8),
      for (final r in rows) Card(elevation: 0, child: ListTile(
        leading: CircleAvatar(child: Text(icOf(r.key))), title: Text(nmOf(r.key)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: tot == 0 ? 0 : r.value / tot, color: gold, minHeight: 6, borderRadius: BorderRadius.circular(3))),
        trailing: Text(fm(r.value), style: const TextStyle(fontWeight: FontWeight.w600)))),
    ]);
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});
  Widget btn(Widget icon, String l, VoidCallback f) => Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(onPressed: f, icon: icon, label: Text(l)));
  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
        for (final a in st.ac) Card(elevation: 0, child: ListTile(
          leading: const CircleAvatar(child: Text('💵')), title: Text('${a['name']}'),
          trailing: Text('${st.cur} ${fm(_n(a['balance']))}', style: TextStyle(fontWeight: FontWeight.w600, color: _n(a['balance']) < 0 ? outC : null)),
          onTap: () => accDlg(c, a))),
        const SizedBox(height: 12),
        btn(const Icon(Icons.add), st.f('添加钱包', 'Add wallet'), () => accDlg(c, null)),
        btn(const Icon(Icons.ios_share), st.f('导出备份', 'Export backup'), exportData),
        btn(const Icon(Icons.file_open), st.f('导入备份', 'Import backup'), () => importData(c)),
      ]);
}

Future<void> accDlg(BuildContext c, Map<String, dynamic>? a) async {
  final nm = TextEditingController(text: a == null ? '' : '${a['name']}');
  final bl = TextEditingController(text: a == null ? '0' : '${a['balance']}');
  await showDialog<void>(context: c, builder: (d) => AlertDialog(
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: nm, decoration: InputDecoration(labelText: st.f('名称', 'Name'))),
      TextField(controller: bl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: st.t('balanceLabel'))),
    ]),
    actions: [
      if (a != null) TextButton(onPressed: () async { st.ac.remove(a); await st.save(); if (d.mounted) Navigator.pop(d); }, child: Text(st.t('delete'), style: const TextStyle(color: outC))),
      TextButton(onPressed: () => Navigator.pop(d), child: Text(st.t('cancel'))),
      FilledButton(onPressed: () async {
        final n = nm.text.trim();
        final v = double.tryParse(bl.text.replaceAll(',', '.')) ?? 0;
        if (n.isEmpty || st.ac.any((x) => x != a && x['name'] == n)) return;
        if (a != null) {
          for (final t in st.tx) { if (t['account'] == a['name']) t['account'] = n; if (t['toAccount'] == a['name']) t['toAccount'] = n; }
          a['name'] = n; a['balance'] = v;
        } else {
          st.ac.add({'id': 'asset_${DateTime.now().millisecondsSinceEpoch}', 'name': n, 'balance': v, 'type': '一般账户'});
        }
        await st.save();
        if (d.mounted) Navigator.pop(d);
      }, child: Text(st.t('save'))),
    ]));
}

Future<void> exportData() async {
  final j = jsonEncode({'version': 1, 'exportTime': DateTime.now().toIso8601String(), ...st.ex, 'items': st.tx, 'assets': st.ac, 'selectedCurrency': {'symbol': st.cur}, 'language': st.lang});
  final name = 'ledger_backup_${ymd(DateTime.now()).replaceAll('/', '')}.json';
  await Share.shareXFiles([XFile.fromData(Uint8List.fromList(utf8.encode(j)), mimeType: 'application/json', name: name)], fileNameOverrides: [name]);
}

Future<void> importData(BuildContext c) async {
  final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
  final bytes = r?.files.single.bytes;
  if (bytes == null || !c.mounted) return;
  try {
    final d = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final items = (d['items'] ?? d['transactions']) as List;
    final ass = d['assets'] as List;
    if (!await ask(c, st.f('导入会覆盖现有数据，继续吗？', 'Importing replaces your current data. Continue?'))) return;
    st.tx = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    st.ac = ass.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    var i = 0;
    for (final t in st.tx) { t['amount'] = _n(t['amount']); t['id'] ??= 'tx_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${i++}'; }
    for (final a in st.ac) { a['balance'] = _n(a['balance']); }
    const skip = ['items', 'transactions', 'assets', 'selectedCurrency', 'language', 'version', 'exportTime'];
    st.ex = {for (final k in d.keys) if (!skip.contains(k)) k: d[k]};
    final sym = (d['selectedCurrency'] as Map?)?['symbol'];
    if (sym != null) st.cur = '$sym';
    await st.save();
    if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(st.f('导入成功', 'Imported'))));
  } catch (_) {
    if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(st.f('文件格式不对', 'Unrecognized file'))));
  }
}
