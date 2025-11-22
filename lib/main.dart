import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'transaction_model.dart';
import 'notification_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(const WalletMitraApp());
}

class WalletMitraApp extends StatelessWidget {
  const WalletMitraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Mitra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F7FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 255, 255, 255),
          brightness: Brightness.light,
        ),
      ),
      home: const WalletHomePage(),
    );
  }
}

class WalletHomePage extends StatefulWidget {
  const WalletHomePage({Key? key}) : super(key: key);

  @override
  State<WalletHomePage> createState() => _WalletHomePageState();
}

class _WalletHomePageState extends State<WalletHomePage>
    with WidgetsBindingObserver {
  // ❌ REMOVED: static const smsStream = EventChannel(...)

  List<TransactionModel> transactions = [];
  bool isListening = false;
  String searchQuery = '';
  String filterType = 'all';
  DateTime? selectedMonth;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    NotificationService().initialize();
    selectedMonth = DateTime.now();
    loadTransactions();
    requestSmsPermission();

    _initializeDailyReminder();

    // ✅ RELOAD EVERY 1 SECOND to catch new SMS transactions saved by SmsReceiver
    _reloadTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      print('🔄 Reloading transactions (checking for SMS)...');
      loadTransactions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloadTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - checking permissions');
      _checkPermissions();
      loadTransactions();
    }
  }

  Future<void> _checkPermissions() async {
    print('🔐 Checking permissions...');

    final smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      print('❌ SMS permission not granted');
      await Permission.sms.request();
    } else {
      print('✅ SMS permission granted');
    }

    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      print('❌ Notification permission not granted');
      final result = await Permission.notification.request();
      if (result.isGranted) {
        print('✅ Notification permission granted');
      } else {
        print('❌ Notification permission denied');
        _showPermissionDialog();
      }
    } else {
      print('✅ Notification permission granted');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
          'Please enable notification permission to receive transaction alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> isSmsReceiverRegistered() async {
    try {
      // Try to check if receiver is enabled
      // This is a workaround - the real test is sending SMS
      return true;
    } catch (e) {
      return false;
    }
  }

  // ✅ SIMPLE permission request
  Future<void> requestSmsPermission() async {
    await Permission.sms.request();
    setState(() {
      isListening = true; // Just mark as listening
    });
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder(
        future: _getDebugInfo(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading debug info...'),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('🐛 Debug Info'),
            content: SingleChildScrollView(
              child: Text(
                snapshot.data as String,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  loadTransactions(); // Refresh
                  Navigator.pop(context);
                },
                child: const Text('Refresh'),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  setState(() {
                    transactions.clear();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ All data cleared!')),
                  );
                },
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _getDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get raw data - using EXACT same key
      final rawTransactions = prefs.getString('transactions') ?? '';

      print('🔍 SharedPreferences keys: ${prefs.getKeys()}');
      print('🔍 Looking for "transactions" key');
      print(
        '🔍 Found: ${rawTransactions.isNotEmpty ? "YES - ${rawTransactions.length} chars" : "NO"}',
      );

      // Parse transactions
      List<String> parsedItems = [];
      int parseErrors = 0;

      if (rawTransactions.isNotEmpty) {
        final items = rawTransactions.split('|||');
        for (int i = 0; i < items.length; i++) {
          try {
            final json = jsonDecode(items[i]);
            final amount = json['amount'];
            final type = json['type'];
            parsedItems.add('✅ #$i: ₹$amount ($type)');
          } catch (e) {
            parseErrors++;
            parsedItems.add('❌ #$i: Error - ${items[i].substring(0, 20)}...');
          }
        }
      }

      // Get permissions
      final smsStatus = await Permission.sms.status;
      final notifStatus = await Permission.notification.status;

      // Build report
      String report = '';

      report += '╔═══════════════════════════════════╗\n';
      report += '║    📱 WALLET MITRA - DEBUG    ║\n';
      report += '╚═══════════════════════════════════╝\n\n';

      report += '🔐 PERMISSIONS\n';
      report += '─────────────────────────────\n';
      report += 'SMS: ${smsStatus.isGranted ? "✅" : "❌"}\n';
      report += 'Notifications: ${notifStatus.isGranted ? "✅" : "❌"}\n';
      report += 'Listening: ${isListening ? "✅" : "❌"}\n\n';

      report += '💾 PREFS FILE\n';
      report += '─────────────────────────────\n';
      report += 'File: FlutterSharedPreferences\n';
      report += 'Key: "transactions"\n';
      report += 'Exists: ${rawTransactions.isNotEmpty ? "✅ YES" : "❌ NO"}\n';
      report += 'Size: ${rawTransactions.length} chars\n';
      report +=
          'Items: ${rawTransactions.isEmpty ? 0 : rawTransactions.split('|||').length}\n\n';

      report += '📊 PARSED DATA\n';
      report += '─────────────────────────────\n';
      report += 'In Memory: ${transactions.length} total\n';
      report +=
          'Credits: ${transactions.where((t) => t.type == 'credit').length}\n';
      report +=
          'Debits: ${transactions.where((t) => t.type == 'debit').length}\n';
      report += 'Parse errors: $parseErrors\n\n';

      if (parsedItems.isNotEmpty) {
        report += '✅ ITEMS FROM STORAGE\n';
        report += '─────────────────────────────\n';
        for (var item in parsedItems.take(10)) {
          report += '$item\n';
        }
        if (parsedItems.length > 10) {
          report += '... and ${parsedItems.length - 10} more\n';
        }
      }

      return report;
    } catch (e) {
      return '❌ Error: $e';
    }
  }

  // ✅ NEW METHOD - Schedule reminder ONLY ONCE
  void _initializeDailyReminder() {
    final totalSpent = transactions
        .where((t) => t.type == 'debit')
        .fold(0.0, (sum, t) => sum + t.amount);

    NotificationService().scheduleDailyReminder(totalSpent);
    print('✅ Daily reminder scheduled for 9 PM');
  }

  // In main.dart, update loadTransactions() to THIS:
  Future<void> loadTransactions() async {
    try {
      print('🔄 Loading transactions...');

      List<TransactionModel> allTransactions = [];

      // ✅ LOAD FROM FILE (SMS data)
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final smsFile = File(
          '${appDocDir.parent.path}/app_wallet_data/sms_transactions.txt',
        );

        if (smsFile.existsSync()) {
          final content = smsFile.readAsStringSync();
          print('📂 SMS File: ${content.length} chars');

          if (content.isNotEmpty) {
            for (var item in content.split('|||')) {
              try {
                if (item.trim().isNotEmpty) {
                  final json = jsonDecode(item.trim());
                  final t = TransactionModel.fromJson(json);
                  allTransactions.add(t);
                  print('✅ SMS: ₹${t.amount} ${t.type}');
                }
              } catch (e) {
                print('❌ SMS parse error: $e');
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ No SMS file: $e');
      }

      // ✅ LOAD FROM PREFS (manual entries)
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedData = prefs.getString('transactions') ?? '';
        print('💾 Prefs: ${savedData.length} chars');

        if (savedData.isNotEmpty) {
          for (var item in savedData.split('|||')) {
            try {
              if (item.trim().isNotEmpty) {
                final json = jsonDecode(item.trim());
                final t = TransactionModel.fromJson(json);
                // Avoid duplicates by ID
                if (!allTransactions.any((x) => x.id == t.id)) {
                  allTransactions.add(t);
                  print('✅ Prefs: ₹${t.amount} ${t.type}');
                }
              }
            } catch (e) {
              print('❌ Prefs parse error: $e');
            }
          }
        }
      } catch (e) {
        print('⚠️ Prefs error: $e');
      }

      print('📊 Total: ${allTransactions.length}');

      setState(() {
        transactions = allTransactions;
        transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      }); 
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  Future<void> saveTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = transactions
          .map((t) => jsonEncode(t.toJson()))
          .toList();

      await prefs.setString('transactions', transactionsJson.join('|||'));
      print('✅ Saved ${transactions.length} transactions');
    } catch (e) {
      print('❌ Error saving: $e');
    }
  }

  void addManualTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        onAdd: (transaction) {
          setState(() {
            transactions.insert(0, transaction);
          });
          saveTransactions();
        },
      ),
    );
  }

  void editTransactionName(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditNameSheet(
        currentName: transaction.name ?? '',
        onSave: (newName) {
          setState(() {
            final index = transactions.indexWhere(
              (t) => t.id == transaction.id,
            );
            if (index != -1) {
              transactions[index] = transaction.copyWith(name: newName);
            }
          });
          saveTransactions();
        },
      ),
    );
  }

  void deleteTransaction(TransactionModel transaction) {
    setState(() {
      transactions.removeWhere((t) => t.id == transaction.id);
    });
    saveTransactions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              transactions.add(transaction);
              transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            });
            saveTransactions();
          },
        ),
      ),
    );
  }

  void showMonthPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => YearMonthPickerSheet(
        selectedMonth: selectedMonth ?? DateTime.now(),
        onMonthSelected: (month) {
          setState(() {
            selectedMonth = month;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  double get totalSpent {
    return filteredTransactions
        .where((t) => t.type == 'debit')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get totalReceived {
    return filteredTransactions
        .where((t) => t.type == 'credit')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get balance {
    return totalReceived - totalSpent;
  }

  List<TransactionModel> get filteredTransactions {
    var filtered = transactions;

    if (selectedMonth != null) {
      filtered = filtered.where((t) {
        return t.dateTime.year == selectedMonth!.year &&
            t.dateTime.month == selectedMonth!.month;
      }).toList();
    }

    if (filterType != 'all') {
      filtered = filtered.where((t) => t.type == filterType).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        return (t.name?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                false) ||
            t.amount.toString().contains(searchQuery) ||
            (t.smsBody?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Wallet Mitra',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.bug_report, color: Colors.orange),
                  onPressed: _showDebugInfo,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: addManualTransaction,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purple, Colors.purpleAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        'Balance',
                        '₹${balance.toStringAsFixed(2)}',
                        Icons.account_balance_wallet,
                        const LinearGradient(
                          colors: [Colors.purple, Colors.purpleAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGlassCard(
                        'Spent',
                        '₹${totalSpent.toStringAsFixed(2)}',
                        Icons.trending_up,
                        LinearGradient(
                          colors: [Colors.red.shade400, Colors.redAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.08),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.purple.shade300,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: showMonthPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedMonth != null
                                        ? DateFormat(
                                            'MMM yyyy',
                                          ).format(selectedMonth!)
                                        : 'Month',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: Colors.purple.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          onSelected: (value) {
                            setState(() {
                              filterType = value;
                            });
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'all',
                              child: Row(
                                children: [
                                  Icon(Icons.all_inclusive, size: 18),
                                  SizedBox(width: 8),
                                  Text('All'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'credit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Received'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'debit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_upward,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Spent'),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.2),
                              ),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              color: Colors.purple.shade600,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (filteredTransactions.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final transaction = filteredTransactions[index];
                    return _buildTransactionCard(transaction);
                  }, childCount: filteredTransactions.length),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard(
    String title,
    String value,
    IconData icon,
    Gradient gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final isCredit = transaction.type == 'credit';

    return Dismissible(
      key: Key(transaction.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        deleteTransaction(transaction);
      },
      child: GestureDetector(
        onTap: () => editTransactionName(transaction),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCredit
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.name ?? 'Add name...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: transaction.name == null
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(transaction.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isCredit ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== BOTTOM SHEETS (Keep existing code) ==========
class AddTransactionSheet extends StatefulWidget {
  final Function(TransactionModel) onAdd;

  const AddTransactionSheet({Key? key, required this.onAdd}) : super(key: key);

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  String _type = 'debit';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F7FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Transaction',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildInputField(
                'Amount',
                _amountController,
                TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildInputField('Transaction Name', _nameController),
              const SizedBox(height: 16),
              _buildTypeSelector(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _addTransaction,
                  child: const Text(
                    'Add Transaction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildInputField(
    String label,
    TextEditingController controller, [
    TextInputType keyboardType = TextInputType.text,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.purple.withOpacity(0.2)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(child: _typeButton('Spent', 'debit')),
        const SizedBox(width: 12),
        Expanded(child: _typeButton('Received', 'credit')),
      ],
    );
  }

  Widget _typeButton(String label, String type) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.purple.withOpacity(isSelected ? 0 : 0.2),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _addTransaction() {
    final amount = double.tryParse(_amountController.text);
    if (amount != null && _nameController.text.isNotEmpty) {
      widget.onAdd(
        TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
          type: _type,
          name: _nameController.text,
          dateTime: DateTime.now(),
        ),
      );
      Navigator.pop(context);
    }
  }
}

class EditNameSheet extends StatefulWidget {
  final String currentName;
  final Function(String) onSave;

  const EditNameSheet({
    Key? key,
    required this.currentName,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<EditNameSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F7FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Transaction Name',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'E.g., Grocery, Fuel, Salary',
                filled: true,
                fillColor: Colors.white.withOpacity(0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.purple.withOpacity(0.2)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    widget.onSave(_controller.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YearMonthPickerSheet extends StatefulWidget {
  final DateTime selectedMonth;
  final Function(DateTime) onMonthSelected;

  const YearMonthPickerSheet({
    Key? key,
    required this.selectedMonth,
    required this.onMonthSelected,
  }) : super(key: key);

  @override
  State<YearMonthPickerSheet> createState() => _YearMonthPickerSheetState();
}

class _YearMonthPickerSheetState extends State<YearMonthPickerSheet> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.selectedMonth.year;
    selectedMonth = widget.selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final currentYear = DateTime.now().year;
    final years = List.generate(5, (index) => currentYear - index);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F7FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Month',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButton<int>(
              value: selectedYear,
              isExpanded: true,
              items: years.map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedYear = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = month == selectedMonth;

                return GestureDetector(
                  onTap: () {
                    widget.onMonthSelected(DateTime(selectedYear, month));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.purple
                          : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        months[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
