import 'package:flutter/material.dart';

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
  // ----- Tickers y rangos -----
  final Map<String, List<double>> tickers = {
    "AMZN": [0.65, 1.30],
    "AAPL": [0.45, 0.95],
    "GOOG": [0.60, 1.40],
    "META": [0.50, 1.70],
    "MSFT": [0.70, 1.55],
    "NFLX": [0.55, 0.85],
    "TSLA": [2.20, 3.60],
    "AMD": [0.65, 1.40],
    "NVDA": [0.80, 1.70],
    "QQQ": [0.30, 0.60],
    "SPY": [0.30, 0.45],
    "CCL": [0.25, 0.45],
    "RCL": [0.80, 1.40],
  };

  String selectedTicker = "AMZN";

  // ----- VALORES INICIALES -----
  final double initialComision = 0.65;
  final double initialGananciaPorc = 0.10;
  final double initialStopPorc = 0.20;
  final int initialContratos = 1;

  // ----- VARIABLES DINÁMICAS -----
  double precioCompra = 0.65; // inicializa con el mínimo de AMZN
  int contratos = 1;
  double comision = 0.65;
  double gananciaPorc = 0.10;
  double stopPorc = 0.20;

  final int multiplicador = 100;

  double precioVenta = 0;
  double gananciaNeta = 0;
  double stopPrice = 0;
  double perdidaNeta = 0;

  // ---- CHECKBOX ----
  bool disableCommission = true;
  bool disableProfitTarget = true;
  bool disableStopLoss = true;

  void calcular() {
    double valorTotal = precioCompra * multiplicador * contratos;
    double comisionesTotales = comision * contratos * 2;

    // Precio de venta
    double precioVentaExacto =
        (valorTotal + comisionesTotales) * (1 + gananciaPorc) / (contratos * multiplicador);
    precioVenta = (precioVentaExacto * 100).ceilToDouble() / 100;

    // Stop Loss
    stopPrice = (precioCompra * (1 - stopPorc) * 100).ceilToDouble() / 100;

    // Ganancia neta real
    double ventaReal = precioVenta * contratos * multiplicador;
    gananciaNeta = ventaReal - valorTotal - comisionesTotales;

    // Pérdida neta si se llega al stop
    double stopReal = stopPrice * contratos * multiplicador;
    perdidaNeta = valorTotal - stopReal + comisionesTotales;
  }

  // ----- GLASS CARD -----
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
            : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: child,
    );
  }

  // ----- SLIDER CONTROL -----
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      activeTrackColor: enabled ? Colors.blueAccent : Colors.grey,
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

  // ----- MINI GRAPH -----
  Widget miniGraph() {
    double maxValue = [
      stopPrice,
      precioCompra,
      precioVenta,
      gananciaNeta.abs(),
      perdidaNeta.abs()
    ].reduce((a, b) => a > b ? a : b);

    const double minHeight = 20;
    double getBarHeight(double value) {
      double scaled = (value / maxValue) * 100;
      return scaled < minHeight ? minHeight : scaled;
    }

    return glassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Price Levels",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Container(
                      height: getBarHeight(precioCompra),
                      width: 20,
                      color: Colors.grey),
                  const SizedBox(height: 4),
                  Text("Buy\n\$${precioCompra.toStringAsFixed(2)}",
                      textAlign: TextAlign.center),
                ],
              ),
              Column(
                children: [
                  Container(
                      height: getBarHeight(precioVenta),
                      width: 20,
                      color: Colors.blueAccent),
                  const SizedBox(height: 4),
                  Text("Sale\n\$${precioVenta.toStringAsFixed(2)}",
                      textAlign: TextAlign.center),
                ],
              ),
              Column(
                children: [
                  Container(
                      height: getBarHeight(stopPrice),
                      width: 20,
                      color: Colors.orangeAccent),
                  const SizedBox(height: 4),
                  Text("Stop\n\$${stopPrice.toStringAsFixed(2)}",
                      textAlign: TextAlign.center),
                ],
              ),
              Column(
                children: [
                  Container(
                      height: getBarHeight(gananciaNeta.abs()),
                      width: 20,
                      color: Colors.greenAccent),
                  const SizedBox(height: 4),
                  Text("Profit\n\$${gananciaNeta.toStringAsFixed(2)}",
                      textAlign: TextAlign.center),
                ],
              ),
              Column(
                children: [
                  Container(
                      height: getBarHeight(perdidaNeta.abs()),
                      width: 20,
                      color: Colors.redAccent),
                  const SizedBox(height: 4),
                  Text("Loss\n-\$${perdidaNeta.toStringAsFixed(2)}",
                      textAlign: TextAlign.center),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----- ANIMATED RESULT -----
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
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ----- RESET FUNCTION -----
  void resetValues() {
    setState(() {
      // Reset sliders al inicio
      precioCompra = tickers[selectedTicker]![0]; // al mínimo del ticker
      contratos = initialContratos;
      comision = initialComision;
      gananciaPorc = initialGananciaPorc;
      stopPorc = initialStopPorc;

      disableCommission = true;
      disableProfitTarget = true;
      disableStopLoss = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    calcular();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Options Calculator",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
            // ---------- BOTÓN TICKERS ESTILIZADO ----------
            glassCard(
              GestureDetector(
                onTap: () async {
                  String? result = await showModalBottomSheet<String>(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        height: 400,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Select a Ticker",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView(
                                children: tickers.keys.map((ticker) {
                                  return ListTile(
                                    title: Text(
                                      ticker,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context, ticker);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  if (result != null) {
                    setState(() {
                      selectedTicker = result;
                      precioCompra = tickers[selectedTicker]![0];
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: widget.darkMode
                          ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)]
                          : [Colors.blue.shade100, Colors.blue.shade50],
                    ),
                    border: Border.all(
                        color: widget.darkMode ? Colors.white24 : Colors.blueAccent),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedTicker,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: widget.darkMode ? Colors.white : Colors.black),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 30),
                    ],
                  ),
                ),
              ),
            ),

            // ---------- SLIDERS ----------
            sliderControl(
              label: "Trade Price:",
              value: precioCompra,
              min: tickers[selectedTicker]![0],
              max: tickers[selectedTicker]![1],
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
            miniGraph(),

            const SizedBox(height: 24),
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
              gananciaNeta >= 0 ? Colors.greenAccent : Colors.redAccent,
            ),
            animatedResult(
              "Possible Loss",
              "-\$${perdidaNeta.toStringAsFixed(2)}",
              Colors.redAccent,
            ),
            animatedResult(
              "Percentage",
              "${(gananciaPorc * 100).toStringAsFixed(2)}%",
              gananciaNeta >= 0 ? Colors.greenAccent : Colors.redAccent,
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
