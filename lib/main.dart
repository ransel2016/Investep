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
  double precioCompra = 0.50;
  int contratos = 1;
  double comision = 0.65;
  double gananciaPorc = 0.10;
  final int multiplicador = 100;

  double precioVenta = 0;
  double gananciaNeta = 0;
  double porcentajeReal = 0;

  void calcular() {
    double valorTotal = precioCompra * multiplicador * contratos;
    double comisionesTotales = comision * contratos * 2;
    double objetivoNeto = (valorTotal + comisionesTotales) * (1 + gananciaPorc);

    precioVenta = (objetivoNeto / (contratos * multiplicador) * 100).ceilToDouble() / 100;
    gananciaNeta = objetivoNeto - valorTotal - comisionesTotales;
    porcentajeReal = (gananciaNeta / (valorTotal + comisionesTotales)) * 100;
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
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                )
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
  }) {
    return glassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label  $prefix${value.toStringAsFixed(2)}$suffix",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => onChanged((value - step).clamp(min, max)),
              ),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: ((max - min) / step).round(),
                  onChanged: onChanged,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => onChanged((value + step).clamp(min, max)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget intSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required Function(int) onChanged,
  }) {
    return glassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label  $value",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => onChanged((value - 1).clamp(min, max)),
              ),
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  onChanged: (v) => onChanged(v.toInt()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => onChanged((value + 1).clamp(min, max)),
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
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
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
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            sliderControl(
              label: "Trade Price:",
              value: precioCompra,
              min: 0.01,
              max: 100,
              step: 0.01,
              prefix: "\$",
              onChanged: (v) => setState(() => precioCompra = v),
            ),
            intSlider(
              label: "Quantity:",
              value: contratos,
              min: 1,
              max: 1000,
              onChanged: (v) => setState(() => contratos = v),
            ),
            sliderControl(
              label: "Commission:",
              value: comision,
              min: 0,
              max: 10,
              step: 0.05,
              prefix: "\$",
              onChanged: (v) => setState(() => comision = v),
            ),
            sliderControl(
              label: "Profit Target:",
              value: gananciaPorc * 100,
              min: 0,
              max: 100,
              step: 1,
              suffix: "%",
              onChanged: (v) => setState(() => gananciaPorc = v / 100),
            ),
            const SizedBox(height: 24),
            animatedResult(
              "Sale Price",
              "\$${precioVenta.toStringAsFixed(2)}",
              Colors.blueAccent,
            ),
            animatedResult(
              "Net Profit",
              "\$${gananciaNeta.toInt()}",
              gananciaNeta >= 0 ? Colors.greenAccent : Colors.redAccent,
            ),
            animatedResult(
              "Percentage",
              "${porcentajeReal.toStringAsFixed(2)}%",
              porcentajeReal >= gananciaPorc * 100
                  ? Colors.greenAccent
                  : Colors.redAccent,
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
