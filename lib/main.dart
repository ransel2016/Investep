import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' show parse;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ProCalculatorApp());
}

class ProCalculatorApp extends StatefulWidget {
  const ProCalculatorApp({super.key});

  @override
  State<ProCalculatorApp> createState() => _ProCalculatorAppState();
}

class _ProCalculatorAppState extends State<ProCalculatorApp> {
  bool darkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Options Calculator',
      theme: darkMode ? darkTheme : lightTheme,
      home: CalculatorPage(
        darkMode: darkMode,
        onToggleTheme: () => setState(() => darkMode = !darkMode),
      ),
    );
  }
}

/* ---------- THEMES ---------- */
final darkTheme = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: const Color(0xFF0B0F1A),
  primaryColor: Colors.blueAccent,
);

final lightTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: const Color(0xFFF5F7FB),
  primaryColor: Colors.blueAccent,
);

/* ---------- CALCULATOR ---------- */
class CalculatorPage extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;

  const CalculatorPage({
    super.key,
    required this.darkMode,
    required this.onToggleTheme,
  });

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  List<String> empresas = [];
  String? seleccionada;
  String? earningsTexto;
  int? earningsDays;
  DateTime? earningsFecha;
  bool isETF = false;
  bool loading = true;
  String? companyName;

  // ----- VALORES INICIALES -----
  final double initialComision = 0.65;
  final double initialGananciaPorc = 0.10;
  final double initialStopPorc = 0.20;
  final int initialContratos = 1;
  final int multiplicador = 100;

  // ----- VARIABLES DINÁMICAS -----
  double precioCompra = 0.01;
  int contratos = 1;
  double comision = 0.65;
  double gananciaPorc = 0.10;
  double stopPorc = 0.20;

  double precioVenta = 0;
  double gananciaNeta = 0;
  double stopPrice = 0;
  double perdidaNeta = 0;

  // ---- CHECKBOX ----
  bool disableCommission = true;
  bool disableProfitTarget = true;
  bool disableStopLoss = true;

  @override
  void initState() {
    super.initState();
    loadEmpresas();
  }

  Future<Map<String, String>?> fetchEarningsDate(String ticker) async {
    try {
      final url =
          "https://api.earningsapi.com/v1/earnings?symbol=${ticker.toUpperCase()}&apikey=lysmvjQgf6fgiADlLJLr";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        if (data.length < 2) return null;

        final today = DateTime.now();

        final first = data[0];
        final second = data[1];

        Map<String, dynamic> selected = first;

        final secondDate = DateTime.parse(second["date"]);

        // 🔹 Lógica de selección
        if (secondDate.year == today.year &&
            secondDate.month == today.month &&
            secondDate.day >= today.day) {
          selected = second;
        }

        final selectedDate = DateTime.parse(selected["date"]);
        final formatted =
            "${_monthName(selectedDate.month)} ${selectedDate.day}, ${selectedDate.year}";

        final isConfirmed =
            selected["time"] != null && selected["time"].toString().isNotEmpty;

        return {
          "company": selected["name"] ?? ticker,
          "earningText": isConfirmed
              ? "Next Earnings - $formatted"
              : "Estimated Earnings - $formatted",
        };
      }
    } catch (e) {
      print("Error fetching EarningsAPI: $e");
    }

    return null;
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  Future<Map<String, String>> getWeeklyCachedEarnings(String ticker) async {
    final prefs = await SharedPreferences.getInstance();
    final earningKey = "earning_$ticker";
    final dateKey = "earning_last_update_$ticker";

    final now = DateTime.now();

    String? cachedJson = prefs.getString(earningKey);
    final lastUpdateString = prefs.getString(dateKey);

    bool shouldUpdate = true;

    if (lastUpdateString != null) {
      final lastUpdate = DateTime.parse(lastUpdateString);
      final daysPassed = now.difference(lastUpdate).inDays;
      if (daysPassed < 7) {
        shouldUpdate = false; // aún no pasó una semana
      }
    }

    // Mostrar cache inmediato
    Map<String, String> display = cachedJson != null
        ? Map<String, String>.from(json.decode(cachedJson))
        : {"company": ticker, "earningText": "Loading..."};

    // Actualizar en background si ya pasó 1 semana
    if (shouldUpdate) {
      fetchEarningsDate(ticker).then((fresh) async {
        if (fresh != null) {
          await prefs.setString(earningKey, json.encode(fresh));
          await prefs.setString(dateKey, now.toIso8601String());

          if (ticker == seleccionada) {
            setState(() {
              earningsTexto = fresh["earningText"];
              companyName = fresh["company"];
            });
          }
        }
      });
    }

    return display;
  }

  Map<String, List<double>> rangosEmpresas = {};

  Future<void> loadEmpresas() async {
    final url =
        'https://docs.google.com/spreadsheets/d/1JH-nYSubRs6eznGMjl-gjCE3P6NEo_utrI2zPDci1LM/export?format=csv&gid=0';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<List<dynamic>> rows = const CsvToListConverter().convert(
          response.body,
        );

        List<String> loaded = [];

        for (int i = 1; i < rows.length; i++) {
          if (rows[i].length > 2) {
            var numero = rows[i][0];
            var ticker = rows[i][1];
            var rango = rows[i][2];

            bool numeroValido =
                numero != null &&
                numero.toString().trim().isNotEmpty &&
                int.tryParse(numero.toString()) != null;

            if (numeroValido) {
              String t = ticker.toString().trim();
              String r = rango.toString().trim();

              if (t.isNotEmpty) {
                loaded.add(t);

                String limpio = r
                    .replaceAll('[', '')
                    .replaceAll(']', '')
                    .replaceAll('\$', '')
                    .trim();

                List<String> partes = limpio.split('-');

                if (partes.length == 2) {
                  double? minRango = double.tryParse(partes[0].trim());
                  double? maxRango = double.tryParse(partes[1].trim());

                  if (minRango != null && maxRango != null) {
                    minRango = minRango / 100;
                    maxRango = maxRango / 100;

                    rangosEmpresas[t] = [minRango, maxRango];

                    // 🔥 SI ESTA EMPRESA YA ESTA SELECCIONADA
                    // actualizar automaticamente precioCompra
                    if (seleccionada == t) {
                      precioCompra = minRango;
                    }
                  }
                }
              }
            }
          }
        }

        setState(() {
          empresas = loaded;
          loading = false;
        });
      } else {
        print("Error HTTP: ${response.statusCode}");
        setState(() => loading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => loading = false);
    }
  }

  void calcular() {
    // 🔹 Valor total de la compra
    double valorTotal = precioCompra * multiplicador * contratos;

    // 🔹 Comisiones totales (ida y vuelta)
    double comisionesTotales = comision * contratos * 2;

    // 🔹 Precio de venta
    precioVenta =
        ((valorTotal + comisionesTotales) *
                (1 + gananciaPorc) /
                (contratos * multiplicador) *
                100)
            .ceilToDouble() /
        100;

    // 🔹 Stop price
    stopPrice = (precioCompra * (1 - stopPorc) * 100).ceilToDouble() / 100;

    // 🔹 Ganancia neta
    double ventaReal = precioVenta * contratos * multiplicador;
    gananciaNeta = ventaReal - valorTotal - comisionesTotales;

    // 🔹 Pérdida neta
    double stopReal = stopPrice * contratos * multiplicador;
    perdidaNeta = valorTotal - stopReal + comisionesTotales;
  }

  void resetValues() {
    setState(() {
      // 🔹 Precio de compra
      if (seleccionada != null && rangosEmpresas.containsKey(seleccionada)) {
        precioCompra = rangosEmpresas[seleccionada]![0]; // mínimo del rango
      } else {
        precioCompra = 0.01; // valor por defecto si no hay ticker
      }
      contratos = initialContratos;
      comision = initialComision;
      gananciaPorc = initialGananciaPorc;
      stopPorc = initialStopPorc;

      disableCommission = true;
      disableProfitTarget = true;
      disableStopLoss = true;
    });
  }

  Widget glassCard(Widget child) {
    final isDark = widget.darkMode;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)]
              : [Colors.white, Colors.grey.shade100],
        ),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: child,
    );
  }

  Widget sliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required Function(double) onChanged,
    String prefix = "",
    String suffix = "",
    bool enabled = true,
    bool showCheckbox = false,
  }) {
    final bool locked = !enabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: locked ? 0.55 : 1.0,
      child: glassCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$label  $prefix${label == "Quantity:" ? value.toInt() : value.toStringAsFixed(2)}$suffix",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: locked
                      ? const Text(
                          "LOCKED",
                          key: ValueKey("locked"),
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const SizedBox(key: ValueKey("unlocked")),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: enabled
                      ? () => onChanged((value - step).clamp(min, max))
                      : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: enabled
                          ? Colors.blueAccent
                          : Colors.grey,
                      inactiveTrackColor: Colors.grey.shade400,
                      thumbColor: enabled ? Colors.blueAccent : Colors.grey,
                    ),
                    child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: ((max - min) / step).round(),
                      onChanged: enabled ? onChanged : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: enabled
                      ? () => onChanged((value + step).clamp(min, max))
                      : null,
                ),
                if (showCheckbox)
                  Checkbox(
                    value: locked,
                    onChanged: (v) {
                      setState(() {
                        if (label.contains("Commission")) {
                          disableCommission = v!;
                        } else if (label.contains("Profit Target")) {
                          disableProfitTarget = v!;
                        } else if (label.contains("Stop Loss")) {
                          disableStopLoss = v!;
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget miniGraph() {
    double maxValue = [
      stopPrice,
      precioCompra,
      precioVenta,
      gananciaNeta.abs(),
      perdidaNeta.abs(),
    ].reduce((a, b) => a > b ? a : b);

    if (maxValue <= 0) maxValue = 1; // evita NaN

    const double minHeight = 20;
    double getBarHeight(double value) {
      double scaled = (value / maxValue) * 100;
      return scaled < minHeight ? minHeight : scaled;
    }

    return glassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Price Levels",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Container(
                    height: getBarHeight(precioCompra ?? 0),
                    width: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Buy\n\$${(precioCompra ?? 0).toStringAsFixed(2)}",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    height: getBarHeight(precioVenta),
                    width: 20,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Sale\n\$${precioVenta.toStringAsFixed(2)}",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    height: getBarHeight(stopPrice),
                    width: 20,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Stop\n\$${stopPrice.toStringAsFixed(2)}",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    height: getBarHeight(gananciaNeta.abs()),
                    width: 20,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Profit\n\$${gananciaNeta.toStringAsFixed(2)}",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    height: getBarHeight(perdidaNeta.abs()),
                    width: 20,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Loss\n-\$${perdidaNeta.toStringAsFixed(2)}",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget animatedResult(String label, String value, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), color.withOpacity(0.05)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Calculamos siempre usando el precio actual
    calcular();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Options Calculator",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(widget.darkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reset",
            onPressed: resetValues,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- BUSCADOR DE EMPRESAS ----------
            glassCard(
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🔹 Autocomplete o CircularProgress
                    loading
                        ? const Center(child: CircularProgressIndicator())
                        : Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  return empresas.where((String option) {
                                    return option.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase(),
                                    );
                                  });
                                },
                            onSelected: (String selection) async {
                              setState(() {
                                seleccionada = selection;
                                precioCompra = rangosEmpresas[selection]![0];
                                isETF = false;
                                earningsTexto = null; // limpiar antes de traer
                                companyName = null;
                              });

                              final data = await getWeeklyCachedEarnings(
                                selection,
                              );

                              setState(() {
                                earningsTexto = data["earningText"];
                                companyName = data["company"];
                              });
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onEditingComplete,
                                ) {
                                  final isDark =
                                      Theme.of(context).brightness ==
                                      Brightness.dark;
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: "Search Tickers...",
                                      labelStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.white,
                                    ),
                                  );
                                },
                            optionsViewBuilder: (context, onSelected, options) {
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    constraints: const BoxConstraints(
                                      maxHeight: 250,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: isDark
                                          ? const Color(0xFF1E1E1E)
                                          : Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        final rango = rangosEmpresas[option];

                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  option,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (rango != null)
                                                  Text(
                                                    "\$${(rango[0] * 100).toStringAsFixed(2)}"
                                                    " - "
                                                    "\$${(rango[1] * 100).toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black54,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                    // 🔹 Price Range y Earnings debajo
                    if (seleccionada != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (companyName != null)
                              Text(
                                companyName!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              "Price Range: "
                              "\$${(rangosEmpresas[seleccionada]![0] * 100).toStringAsFixed(2)}"
                              " - "
                              "\$${(rangosEmpresas[seleccionada]![1] * 100).toStringAsFixed(2)}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                Color color = Colors.grey;
                                String displayText = "";

                                if (isETF) {
                                  displayText = "No Earnings";
                                  color = Colors.grey;
                                } else if (earningsTexto != null &&
                                    earningsTexto!.isNotEmpty) {
                                  displayText = earningsTexto!;

                                  if (earningsTexto!.startsWith(
                                    "Next Earnings",
                                  )) {
                                    color = Colors.blueAccent; // 🔵 Confirmado
                                  } else if (earningsTexto!.startsWith(
                                    "Estimated Earnings",
                                  )) {
                                    color = Colors.orangeAccent; // 🟠 Estimado
                                  } else {
                                    color = Colors.grey;
                                  }
                                } else {
                                  displayText = "Earnings not available";
                                  color = Colors.grey;
                                }

                                return Text(
                                  displayText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ---------- SLIDERS ----------
            sliderControl(
              label: "Trade Price:",
              value: precioCompra,
              min: seleccionada != null
                  ? rangosEmpresas[seleccionada]![0]
                  : 0.01,
              max: seleccionada != null
                  ? rangosEmpresas[seleccionada]![1]
                  : 10.0,
              step: 0.01,
              prefix: "\$",
              onChanged: (v) => setState(() => precioCompra = v),
              showCheckbox: false,
            ),
            sliderControl(
              label: "Quantity:",
              value: contratos.toDouble(),
              min: 1,
              max: 1000,
              step: 1,
              onChanged: (v) => setState(() => contratos = v.toInt()),
              showCheckbox: false,
            ),
            sliderControl(
              label: "Commission:",
              value: comision,
              min: 0,
              max: 20,
              step: 0.05,
              prefix: "\$",
              enabled: !disableCommission,
              showCheckbox: true,
              onChanged: (v) => setState(() => comision = v),
            ),
            sliderControl(
              label: "Profit Target:",
              value: gananciaPorc * 100,
              min: 0,
              max: 100,
              step: 1,
              suffix: "%",
              enabled: !disableProfitTarget,
              showCheckbox: true,
              onChanged: (v) => setState(() => gananciaPorc = v / 100),
            ),
            sliderControl(
              label: "Stop Loss:",
              value: stopPorc * 100,
              min: 0,
              max: 100,
              step: 1,
              suffix: "%",
              enabled: !disableStopLoss,
              showCheckbox: true,
              onChanged: (v) => setState(() => stopPorc = v / 100),
            ),

            const SizedBox(height: 24),

            // ---------- MINI GRAPH ----------
            miniGraph(),

            const SizedBox(height: 24),

            // ---------- RESULTADOS ANIMADOS ----------
            animatedResult(
              "Sale Price",
              "\$${precioVenta.toStringAsFixed(2)}",
              Colors.blueAccent,
            ),
            animatedResult(
              "Stop Price",
              "\$${stopPrice.toStringAsFixed(2)}",
              Colors.orangeAccent,
            ),
            animatedResult(
              "Net Profit",
              "\$${gananciaNeta.toStringAsFixed(2)}",
              gananciaNeta >= 0
                  ? const Color.fromARGB(255, 4, 139, 74)
                  : Colors.redAccent,
            ),
            animatedResult(
              "Possible Loss",
              "-\$${perdidaNeta.toStringAsFixed(2)}",
              Colors.redAccent,
            ),

            const SizedBox(height: 12),
            const Text("Designed by: Ransel Ramos"),
            const Text("KEEP IT SIMPLE"),
          ],
        ),
      ),
    );
  }
}
