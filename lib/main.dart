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
  double precioCompra = 1.00;
  int contratos = 1;
  double comision = 0.65;
  double gananciaPorc = 0.10; // slider objetivo ya corregido
  double stopPorc = 0.20;

  final int multiplicador = 100;

  double precioVenta = 0;
  double gananciaNeta = 0;
  double porcentajeReal = 0; // ya no se usa para mostrar
  double stopPrice = 0;
  double perdidaNeta = 0;

  void calcular() {
    double valorTotal = precioCompra * multiplicador * contratos;
    double comisionesTotales = comision * contratos * 2;

    // Precio de venta redondeado
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

  // --------- MINI GRAPH MODIFICADO ----------
  Widget miniGraph() {
    // Tomamos el máximo absoluto para escalar proporciones
    double maxValue = [
      stopPrice,
      precioCompra,
      precioVenta,
      gananciaNeta.abs(),
      perdidaNeta.abs()
    ].reduce((a, b) => a > b ? a : b);

    const double minHeight = 20; // altura mínima para que no desaparezcan

    // Función para escalar cada valor respetando la proporción pero con mínimo
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
              // Stop
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
              // Buy
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
              // Sale
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
              // Net Profit
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
              // Posible pérdida
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
              min: 0.20,
              max: 4.00,
              step: 0.05,
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
              max: 20,
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
            sliderControl(
              label: "Stop Loss:",
              value: stopPorc * 100,
              min: 0,
              max: 100,
              step: 1,
              suffix: "%",
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
            // Ahora mostramos el porcentaje EXACTO del slider
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
