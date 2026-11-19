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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await st.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'SnapLedger', debugShowCheckedModeBanner: false, themeMode: ThemeMode.light,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2F6FFF), scaffoldBackgroundColor: pageBg),
        home: const Home());
}

Future<bool> ask(BuildContext c, String m) async => await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(content: Text(m), actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(st.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(st.f('确定', 'OK'))),
        ])) ?? false;

const pageBg = Color(0xFFF5F5F5);
String money(num n) => '${st.cur} ${fm(n)}';
String wd(DateTime d) => st.lang == 'zh' ? '星期${'一二三四五六日'[d.weekday - 1]}' : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d.weekday - 1];
String ym(DateTime d) => st.lang == 'zh' ? '${d.year}年${d.month}月' : '${d.year}/${d.month}';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext c) => ListenableBuilder(listenable: st, builder: (c, _) {
        double inc = 0, exp = 0;
        for (final t in st.tx) { if (t['type'] == '收入') inc += _n(t['amount']); if (t['type'] == '支出') exp += _n(t['amount']); }
        final total = st.ac.fold<double>(0, (s, a) => s + _n(a['balance']));
        final pages = [TxPage(), CalPage(), StatsPage(), WalletPage()];
        const bgs = [pageBg, Color(0xFF12121F), Color(0xFFFFF8E7), pageBg];
        return Scaffold(
          body: Column(children: [
            Container(height: MediaQuery.of(c).padding.top, color: const Color(0xFFF8F8F8)),
            Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B2CBF), Color(0xFF2F6FFF)])),
              child: Row(children: [
                const Text('💰', style: TextStyle(fontSize: 30)), const SizedBox(width: 8),
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${st.f('余额', 'Balance')}: ${money(total)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  TextSpan(text: '  +${fm(inc)}  -${fm(exp)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
                ]), style: const TextStyle(color: Colors.white)))),
              ])),
            Expanded(child: ColoredBox(color: bgs[i], child: pages[i])),
          ]),
          floatingActionButton: i == 1 || i == 2 ? FloatingActionButton.extended(backgroundColor: gold, foregroundColor: const Color(0xFF2A2000), onPressed: () => txSheet(c, null), icon: const Icon(Icons.add), label: Text(st.t('addTransaction'))) : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: i, type: BottomNavigationBarType.fixed, backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF2196F3), unselectedItemColor: Colors.grey, onTap: (v) => setState(() => i = v),
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.swap_horiz), label: st.t('tabTransaction')),
              BottomNavigationBarItem(icon: const Icon(Icons.calendar_month), label: st.t('tabCalendar')),
              BottomNavigationBarItem(icon: const Icon(Icons.trending_up), label: st.t('tabStatistics')),
              BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet), label: st.t('tabWallet')),
            ]),
        );
      });
}

Widget txRow(BuildContext c, Map<String, dynamic> t, {bool dark = false}) {
  final ty = '${t['type']}';
  final col = ty == '支出' ? const Color(0xFFE91E63) : ty == '收入' ? const Color(0xFF2ECC71) : const Color(0xFF2196F3);
  final rm = '${t['remark'] ?? ''}';
  final title = (ty == '转账' ? '${t['toAccount'] ?? t['category']}' : '${t['category']}') + (rm.isEmpty ? '' : ' · $rm');
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: dark ? const Color(0xFF1E2A3E) : Colors.white, borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      onTap: () => txSheet(c, t),
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col, width: 2.5)), child: Icon(ty == '支出' ? Icons.remove : ty == '收入' ? Icons.add : Icons.swap_horiz, color: col)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: dark ? Colors.white : const Color(0xFF222222))),
      subtitle: Text('${t['time'] ?? ''} · ${t['account']}', style: TextStyle(color: dark ? Colors.white54 : Colors.black45)),
      trailing: Text('${ty == '支出' ? '-' : '+'}${money(_n(t['amount']))}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: col))));
}

class TxPage extends StatefulWidget {
  const TxPage({super.key});
  @override
  State<TxPage> createState() => _TxPageState();
}

class _TxPageState extends State<TxPage> {
  int f = 1;
  bool keep(DateTime d) {
    final n = DateTime.now(), td = DateTime(n.year, n.month, n.day);
    switch (f) {
      case 0: return !d.isBefore(td.subtract(Duration(days: td.weekday % 7)));
      case 1: return d.year == n.year && d.month == n.month;
      case 2: return !d.isBefore(DateTime(n.year, n.month - 2, 1));
      case 3: return !d.isBefore(DateTime(n.year, n.month - 5, 1));
      default: return true;
    }
  }
  Widget ov(String l, double v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        Text(money(v), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
      ]);
  @override
  Widget build(BuildContext c) {
    final td = ymd(DateTime.now());
    double e = 0, n = 0;
    for (final t in st.tx) { if (t['fullDate'] == td) { if (t['type'] == '支出') e += _n(t['amount']); if (t['type'] == '收入') n += _n(t['amount']); } }
    final l = st.tx.where((t) => keep(pd('${t['fullDate']}'))).toList()..sort((a, b) => ts(b).compareTo(ts(a)));
    final dayExp = <String, double>{};
    for (final t in l) { if (t['type'] == '支出') { final k = '${t['fullDate']}'; dayExp[k] = (dayExp[k] ?? 0) + _n(t['amount']); } }
    final labels = st.lang == 'zh' ? ['本周', '本月', '近3个月', '近6个月', '全部'] : ['Week', 'Month', '3 months', '6 months', 'All'];
    final w = <Widget>[
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF19B5FE), Color(0xFFC2306E)]), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 6))]),
        child: Column(children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.f('今日概览', 'Daily Overview'), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              if (st.lang == 'zh') const Text('Daily Overview', style: TextStyle(color: Colors.white70)),
            ]),
            const Spacer(),
            FilledButton(onPressed: () => txSheet(c, null), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6A2B), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)), child: Text('＋ ${st.t('addTransaction')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          const Divider(color: Colors.white38, height: 34),
          Row(children: [Expanded(child: ov(st.t('todayExpense'), e)), Expanded(child: ov(st.t('todayIncome'), n))]),
        ])),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))]),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (var i = 0; i < labels.length; i++) Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(
            label: Text(labels[i]), selected: f == i, showCheckmark: false, side: BorderSide.none, backgroundColor: Colors.transparent, selectedColor: const Color(0xFFE3F2FD),
            labelStyle: TextStyle(fontSize: 16, color: f == i ? const Color(0xFF2196F3) : Colors.black54, fontWeight: f == i ? FontWeight.w700 : FontWeight.w400),
            onSelected: (_) => setState(() => f = i))),
        ])),
      ),
    ];
    String d = '';
    for (final t in l) {
      final k = '${t['fullDate']}';
      if (k != d) {
        d = k;
        final dt = pd(k);
        w.add(Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 10), child: Row(children: [
          Text('${dt.day}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(wd(dt), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
            Text(ym(dt), style: const TextStyle(color: Colors.black45, fontSize: 13)),
          ]),
          const Spacer(),
          if ((dayExp[k] ?? 0) > 0) Text('-${money(dayExp[k]!)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ])));
      }
      w.add(txRow(c, t));
    }
    if (l.isEmpty) w.add(Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(st.f('还没有记录，点“记一笔”开始', 'Nothing yet. Tap Add to start.'), style: const TextStyle(color: Colors.grey)))));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 24), children: w);
  }
}

class CalPage extends StatefulWidget {
  const CalPage({super.key});
  @override
  State<CalPage> createState() => _CalState();
}

class _CalState extends State<CalPage> {
  static final _now = DateTime.now();
  DateTime mo = DateTime(_now.year, _now.month), sel = DateTime(_now.year, _now.month, _now.day);
  Widget arrow(IconData i, VoidCallback f) => InkWell(onTap: f, customBorder: const CircleBorder(), child: Container(width: 54, height: 54, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34344A)), child: Icon(i, color: const Color(0xFF8AB4F8), size: 32)));
  @override
  Widget build(BuildContext c) {
    final ex = <String, double>{}, inc = <String, double>{};
    for (final t in st.tx) {
      final k = '${t['fullDate']}';
      if (t['type'] == '支出') ex[k] = (ex[k] ?? 0) + _n(t['amount']);
      if (t['type'] == '收入') inc[k] = (inc[k] ?? 0) + _n(t['amount']);
    }
    final first = DateTime(mo.year, mo.month, 1);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final cells = <Widget>[];
    for (var i = 0; i < 42; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final k = ymd(d), inM = d.month == mo.month, s = d == sel;
      cells.add(GestureDetector(
        onTap: () => setState(() { sel = d; if (!inM) mo = DateTime(d.year, d.month); }),
        child: Container(
          decoration: BoxDecoration(color: s ? const Color(0xFF8AB4F8) : null, borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${d.day}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: s ? const Color(0xFF10131F) : inM ? Colors.white : Colors.white38)),
            if (!s && ex[k] != null) Text('-${ex[k]!.round()}', style: const TextStyle(fontSize: 10, color: Color(0xFFFF6B6B))),
            if (!s && inc[k] != null) Text('+${inc[k]!.round()}', style: const TextStyle(fontSize: 10, color: Color(0xFF4ADE80))),
          ]))));
    }
    final sk = ymd(sel);
    final dl = st.tx.where((t) => '${t['fullDate']}' == sk).toList()..sort((a, b) => ts(b).compareTo(ts(a)));
    final days = st.lang == 'zh' ? ['日', '一', '二', '三', '四', '五', '六'] : ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF22222F), borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0x22FFFFFF))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            arrow(Icons.arrow_left, () => setState(() => mo = DateTime(mo.year, mo.month - 1))),
            Text(ym(mo), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            arrow(Icons.arrow_right, () => setState(() => mo = DateTime(mo.year, mo.month + 1))),
          ]),
          const SizedBox(height: 14),
          Row(children: [for (final x in days) Expanded(child: Center(child: Text(x, style: const TextStyle(color: Colors.white54, fontSize: 16))))]),
          const SizedBox(height: 6),
          GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.8, children: cells),
        ])),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(28)),
        child: Column(children: [
          Row(children: [
            Text(sk, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), const Spacer(),
            Flexible(child: Text('${st.f('收入', 'Income')}: ${money(inc[sk] ?? 0)} | ${st.f('支出', 'Expense')}: ${money(ex[sk] ?? 0)}', style: const TextStyle(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ]),
          const Divider(color: Colors.white24),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('💰 ${st.t('totalIncomeLabel')}', style: const TextStyle(color: Color(0xFF4ADE80))), Text(money(inc[sk] ?? 0), style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 30, fontWeight: FontWeight.w800))])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('💸 ${st.t('totalExpenseLabel')}', style: const TextStyle(color: Color(0xFFFF6B6B))), Text(money(ex[sk] ?? 0), style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 30, fontWeight: FontWeight.w800))])),
          ]),
        ])),
      Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 10), child: Text('📋 ${st.f('交易记录', 'Transactions')}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
      if (dl.isEmpty) Container(height: 140, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)), child: Text(st.f('该日暂无交易记录', 'No transactions that day'), style: const TextStyle(color: Colors.white54, fontSize: 17)))
      else ...[for (final t in dl) txRow(c, t, dark: true)],
    ]);
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

const grads = [[0xFF2DD4BF, 0xFF3B0764], [0xFF3A3A3A, 0xFF000000], [0xFFF6D365, 0xFFFDA085], [0xFF8E2DE2, 0xFF4A00E0], [0xFF4FACFE, 0xFF1565C0], [0xFF74B9FF, 0xFF2FB5F5], [0xFFF78CA2, 0xFFF9748F]];

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});
  Widget card(BuildContext c, Map<String, dynamic> a, int i) {
    final g = grads[i % grads.length], lim = _n(a['creditLimit']), bal = _n(a['balance']);
    const wh = TextStyle(color: Colors.white);
    return GestureDetector(
      onTap: () => accDlg(c, a),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(g[0]), Color(g[1])]), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 58, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(18)), child: const Text('💵', style: TextStyle(fontSize: 28))),
          const SizedBox(height: 8),
          Text('${a['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: wh.copyWith(color: Colors.white70, fontSize: 17)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(lim > 0 ? '${st.f('可用', 'Available')} ${money(lim + bal)}' : money(bal), style: wh.copyWith(fontSize: 26, fontWeight: FontWeight.w800))),
          if (lim > 0) Text('${st.f('额度', 'Limit')} ${st.cur} ${lim.toStringAsFixed(0)}', style: wh.copyWith(color: Colors.white70, fontSize: 13)),
        ])));
  }
  Widget btn(Widget icon, String l, VoidCallback f) => Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(onPressed: f, icon: icon, label: Text(l)));
  @override
  Widget build(BuildContext c) {
    final total = st.ac.fold<double>(0, (s, a) => s + _n(a['balance']));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 16, 14, 24), children: [
      Row(children: [Text(st.t('tabWallet'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)), const Spacer(), Text('${st.f('管理', 'Manage')}(${st.ac.length})', style: const TextStyle(color: Color(0xFF2196F3), fontSize: 18))]),
      const SizedBox(height: 14),
      GridView.count(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [
        for (var i = 0; i < st.ac.length; i++) card(c, st.ac[i], i),
        GestureDetector(onTap: () => accDlg(c, null), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFCBD5E1), width: 2)), child: const Icon(Icons.add, size: 48, color: Color(0xFF94A3B8)))),
      ]),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [Text(st.t('totalAssets'), style: const TextStyle(color: Colors.black54, fontSize: 18)), const Spacer(), Text(money(total), style: const TextStyle(color: Color(0xFF1565C0), fontSize: 30, fontWeight: FontWeight.w800))])),
      const SizedBox(height: 12),
      btn(const Icon(Icons.ios_share), st.f('导出备份', 'Export backup'), exportData),
      btn(const Icon(Icons.file_open), st.f('导入备份', 'Import backup'), () => importData(c)),
    ]);
  }
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
