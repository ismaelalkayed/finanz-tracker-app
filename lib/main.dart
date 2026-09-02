import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const FinanzTrackerApp());
}

class FinanzTrackerApp extends StatelessWidget {
  const FinanzTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanz-Tracker',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const ExpenseListScreen(),
    );
  }
}

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  List<dynamic> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchExpenses();
  }

  Future<void> fetchExpenses() async {
    setState(() => isLoading = true);
    final response = await http.get(Uri.parse('http://127.0.0.1:8000/expenses'));
    if (response.statusCode == 200) {
      setState(() {
        expenses = jsonDecode(response.body);
        isLoading = false;
      });
    }
  }

  Future<void> deleteExpense(int id) async {
    await http.delete(Uri.parse('http://127.0.0.1:8000/expenses/$id'));
  }

  double calculateTotal() {
    return expenses.fold(0.0, (sum, e) => sum + (e['betrag'] as num).toDouble());
  }

  Map<String, double> calculateCategorySums() {
    final Map<String, double> sums = {};
    for (var expense in expenses) {
      final kategorie = expense['kategorie'] as String;
      final betrag = (expense['betrag'] as num).toDouble();
      sums[kategorie] = (sums[kategorie] ?? 0) + betrag;
    }
    return sums;
  }

  Widget buildSummaryCard() {
    final total = calculateTotal();
    final categorySums = calculateCategorySums();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gesamt: ${total.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...categorySums.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text('${entry.value.toStringAsFixed(2)} €'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Ausgaben')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                buildSummaryCard(),
                Expanded(
                  child: ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return Dismissible(
                        key: Key(expense['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          final removedExpense = expenses[index];
                          setState(() {
                            expenses.removeAt(index);
                          });
                          deleteExpense(removedExpense['id']);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${removedExpense['kategorie']} gelöscht')),
                          );
                        },
                        child: ListTile(
                          title: Text(expense['kategorie']),
                          subtitle: Text(expense['notiz'] ?? ''),
                          trailing: Text('${expense['betrag']} €'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          if (result == true) {
            fetchExpenses();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final betragController = TextEditingController();
  final kategorieController = TextEditingController();
  final notizController = TextEditingController();

  Future<void> submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'betrag': double.parse(betragController.text),
        'kategorie': kategorieController.text,
        'datum': DateTime.now().toIso8601String().substring(0, 10),
        'notiz': notizController.text,
      }),
    );

    if (response.statusCode == 200 && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neue Ausgabe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: betragController,
                decoration: const InputDecoration(labelText: 'Betrag'),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.isEmpty ? 'Bitte Betrag eingeben' : null,
              ),
              TextFormField(
                controller: kategorieController,
                decoration: const InputDecoration(labelText: 'Kategorie'),
                validator: (value) => value == null || value.isEmpty ? 'Bitte Kategorie eingeben' : null,
              ),
              TextFormField(
                controller: notizController,
                decoration: const InputDecoration(labelText: 'Notiz (optional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitExpense,
                child: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}