import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class StateShapePainter extends CustomPainter {
  final String shape;
  final Color color;
  final double size;

  StateShapePainter({
    required this.shape,
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    switch (shape) {
      case 'mixed':
        final mixedPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, size/3, mixedPaint);
        canvas.drawLine(
          Offset(center.dx - size/4, center.dy - size/4),
          Offset(center.dx + size/4, center.dy + size/4),
          mixedPaint,
        );
        canvas.drawLine(
          Offset(center.dx + size/4, center.dy - size/4),
          Offset(center.dx - size/4, center.dy + size/4),
          mixedPaint,
        );
        break;
        
      case 'ground':
        final path = Path();
        path.moveTo(center.dx, center.dy - size/3);
        path.lineTo(center.dx - size/3, center.dy + size/4);
        path.lineTo(center.dx + size/3, center.dy + size/4);
        path.close();
        canvas.drawPath(path, paint);
        break;
        
      case 'excited':
        final path = Path();
        path.moveTo(center.dx, center.dy + size/3);
        path.lineTo(center.dx - size/3, center.dy - size/4);
        path.lineTo(center.dx + size/3, center.dy - size/4);
        path.close();
        canvas.drawPath(path, paint);
        break;
        
      case 'plus':
        final plusPaint = Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(center.dx - size/3, center.dy),
          Offset(center.dx + size/3, center.dy),
          plusPaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - size/3),
          Offset(center.dx, center.dy + size/3),
          plusPaint,
        );
        break;
        
      case 'minus':
        final minusPaint = Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(center.dx - size/3, center.dy),
          Offset(center.dx + size/3, center.dy),
          minusPaint,
        );
        break;
        
      case 'right':
        final path = Path();
        path.moveTo(center.dx - size/4, center.dy - size/4);
        path.lineTo(center.dx + size/6, center.dy - size/4);
        path.lineTo(center.dx + size/6, center.dy - size/3);
        path.lineTo(center.dx + size/3, center.dy);
        path.lineTo(center.dx + size/6, center.dy + size/3);
        path.lineTo(center.dx + size/6, center.dy + size/4);
        path.lineTo(center.dx - size/4, center.dy + size/4);
        path.close();
        canvas.drawPath(path, paint);
        break;
        
      case 'left':
        final path = Path();
        path.moveTo(center.dx + size/4, center.dy - size/4);
        path.lineTo(center.dx - size/6, center.dy - size/4);
        path.lineTo(center.dx - size/6, center.dy - size/3);
        path.lineTo(center.dx - size/3, center.dy);
        path.lineTo(center.dx - size/6, center.dy + size/3);
        path.lineTo(center.dx - size/6, center.dy + size/4);
        path.lineTo(center.dx + size/4, center.dy + size/4);
        path.close();
        canvas.drawPath(path, paint);
        break;
        
      case 'partial_mixed':
        final path = Path();
        path.moveTo(center.dx, center.dy - size/3);
        path.lineTo(center.dx + size/3, center.dy);
        path.lineTo(center.dx, center.dy + size/3);
        path.lineTo(center.dx - size/3, center.dy);
        path.close();
        canvas.drawPath(path, paint);
        break;
        
      case 'superposition':
        final path = Path();
        final outerRadius = size / 3;
        final innerRadius = size / 6;
        for (int i = 0; i < 5; i++) {
          final outerAngle = (i * 2 * math.pi / 5) - math.pi / 2;
          final innerAngle = ((i + 0.5) * 2 * math.pi / 5) - math.pi / 2;
          
          final outerX = center.dx + outerRadius * math.cos(outerAngle);
          final outerY = center.dy + outerRadius * math.sin(outerAngle);
          final innerX = center.dx + innerRadius * math.cos(innerAngle);
          final innerY = center.dy + innerRadius * math.sin(innerAngle);
          
          if (i == 0) {
            path.moveTo(outerX, outerY);
          } else {
            path.lineTo(outerX, outerY);
          }
          path.lineTo(innerX, innerY);
        }
        path.close();
        canvas.drawPath(path, paint);
        break;
        
      default:
        canvas.drawCircle(center, size/3, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantum Circuit Bloch Sphere Visualizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo[800],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: QuantumVisualizerScreen(),
    );
  }
}

class QuantumVisualizerScreen extends StatefulWidget {
  @override
  _QuantumVisualizerScreenState createState() => _QuantumVisualizerScreenState();
}

class _QuantumVisualizerScreenState extends State<QuantumVisualizerScreen>
    with TickerProviderStateMixin {
  
  Map<String, List<double>> quantumStates = {};
  bool isLoading = false;
  String error = '';
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  
  final String apiUrl = "https://quantum-visualizer.onrender.com/examples/bell";
  
  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);
    
    _rotationController.repeat();
    fetchQuantumStates();
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> fetchQuantumStates() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        setState(() {
          quantumStates = {};
          data.forEach((key, value) {
            if (value is List && value.length >= 3) {
              quantumStates[key] = [
                (value[0] as num).toDouble(),
                (value[1] as num).toDouble(),
                (value[2] as num).toDouble(),
              ];
            }
          });
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load quantum states: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quantum Circuit Bloch Sphere Visualizer'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchQuantumStates,
            tooltip: 'Refresh Quantum States',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo[50]!, Colors.blue[50]!],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: isLoading
                  ? _buildLoadingWidget()
                  : error.isNotEmpty
                      ? _buildErrorWidget()
                      : _buildQuantumStatesView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Multi-Qubit Quantum Circuit Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Visualizing reduced density matrices on Bloch spheres',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoChip('API Status', isLoading ? 'Loading' : 'Connected', Colors.green),
                  _buildInfoChip('Qubits', quantumStates.length.toString(), Colors.blue),
                  _buildInfoChip('Circuit', 'Bell State', Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Fetching quantum states from API...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Performing partial tracing on multi-qubit circuit',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              SizedBox(height: 16),
              Text(
                'Connection Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchQuantumStates,
                child: Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantumStatesView() {
    if (quantumStates.isEmpty) {
      return Center(
        child: Text(
          'No quantum states available',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: quantumStates.entries.map((entry) {
        return _buildQubitCard(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildQubitCard(String qubitName, List<double> blochVector) {
    final x = blochVector[0];
    final y = blochVector[1];
    final z = blochVector[2];
    
    // Calculate spherical coordinates
    final r = math.sqrt(x*x + y*y + z*z);
    final theta = r > 0 ? math.acos(z / r) : 0.0;
    final phi = math.atan2(y, x);
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 6,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo[600],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    qubitName.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  'Reduced Density Matrix',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Container(
                        height: 250,
                        child: CustomPaint(
                          painter: BlochSpherePainter(
                            blochVector: blochVector,
                            rotation: _rotationAnimation.value,
                          ),
                          size: Size.infinite,
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildQuantumStateInfo(x, y, z, r, theta, phi),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantumStateInfo(double x, double y, double z, double r, double theta, double phi) {
    final stateInfo = _getStateInfo(x, y, z, r);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bloch Vector',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.indigo[800],
          ),
        ),
        SizedBox(height: 8),
        // State type indicator
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: stateInfo['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: stateInfo['color'].withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                child: CustomPaint(
                  painter: StateShapePainter(
                    shape: stateInfo['shape'],
                    color: stateInfo['color'],
                    size: 12,
                  ),
                ),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  stateInfo['label'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: stateInfo['color'],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _buildVectorComponent('X', x, Colors.red),
        _buildVectorComponent('Y', y, Colors.green),
        _buildVectorComponent('Z', z, Colors.blue),
        SizedBox(height: 12),
        _buildStateProperty('Magnitude', r.toStringAsFixed(3)),
        _buildStateProperty('θ (polar)', '${(theta * 180 / math.pi).toStringAsFixed(1)}°'),
        _buildStateProperty('φ (azimuthal)', '${(phi * 180 / math.pi).toStringAsFixed(1)}°'),
        SizedBox(height: 12),
        _buildPurityIndicator(r),
      ],
    );
  }

  Map<String, dynamic> _getStateInfo(double x, double y, double z, double magnitude) {
    final epsilon = 0.05;
    
    if (magnitude < epsilon) {
      return {'shape': 'mixed', 'color': Colors.grey[600]!, 'label': 'Mixed State'};
    }
    if ((z > 1 - epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'ground', 'color': Colors.blue[700]!, 'label': '|0⟩ Ground'};
    }
    if ((z < -1 + epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'excited', 'color': Colors.red[600]!, 'label': '|1⟩ Excited'};
    }
    if ((z.abs() < epsilon) && (x > 1 - epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'plus', 'color': Colors.green[600]!, 'label': '|+⟩ Plus'};
    }
    if ((z.abs() < epsilon) && (x < -1 + epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'minus', 'color': Colors.orange[600]!, 'label': '|-⟩ Minus'};
    }
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y > 1 - epsilon)) {
      return {'shape': 'right', 'color': Colors.teal[600]!, 'label': '|R⟩ Right'};
    }
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y < -1 + epsilon)) {
      return {'shape': 'left', 'color': Colors.purple[600]!, 'label': '|L⟩ Left'};
    }
    if (magnitude < 0.5) {
      return {'shape': 'partial_mixed', 'color': Colors.amber[600]!, 'label': 'Partial Mixed'};
    }
    if (magnitude > 0.8) {
      return {'shape': 'superposition', 'color': Colors.indigo[600]!, 'label': 'Superposition'};
    }
    return {'shape': 'general', 'color': Colors.deepPurple[600]!, 'label': 'General State'};
  }

  Widget _buildVectorComponent(String label, double value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateProperty(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurityIndicator(double magnitude) {
    final purity = magnitude;
    final isPure = purity > 0.99;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPure ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPure ? Colors.green[300]! : Colors.orange[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPure ? Icons.circle : Icons.blur_on,
            size: 12,
            color: isPure ? Colors.green[700] : Colors.orange[700],
          ),
          SizedBox(width: 4),
          Text(
            isPure ? 'Pure State' : 'Mixed State',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isPure ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

class BlochSpherePainter extends CustomPainter {
  final List<double> blochVector;
  final double rotation;

  BlochSpherePainter({
    required this.blochVector,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;

    // Draw sphere outline
    final spherePaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius, spherePaint);

    // Draw coordinate axes
    _drawAxes(canvas, center, radius);

    // Draw latitude and longitude lines
    _drawGridLines(canvas, center, radius);

    // Draw Bloch vector
    _drawBlochVector(canvas, center, radius, blochVector);

    // Draw axis labels
    _drawAxisLabels(canvas, center, radius);
  }

  void _drawAxes(Canvas canvas, Offset center, double radius) {
    final axesPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.5;

    // X-axis (red)
    final xPaint = Paint()
      ..color = Colors.red[400]!
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      xPaint,
    );

    // Y-axis (green) - considering 3D projection
    final yPaint = Paint()
      ..color = Colors.green[400]!
      ..strokeWidth = 2.0;
    final yOffset = radius * 0.6; // 3D perspective
    canvas.drawLine(
      Offset(center.dx - yOffset, center.dy + yOffset * 0.5),
      Offset(center.dx + yOffset, center.dy - yOffset * 0.5),
      yPaint,
    );

    // Z-axis (blue)
    final zPaint = Paint()
      ..color = Colors.blue[400]!
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      zPaint,
    );
  }

  void _drawGridLines(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw latitude lines
    for (int i = 1; i < 4; i++) {
      final r = radius * i / 4;
      canvas.drawCircle(center, r, gridPaint);
    }

    // Draw longitude lines (simplified)
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final x1 = center.dx + radius * math.cos(angle);
      final y1 = center.dy + radius * math.sin(angle);
      final x2 = center.dx - radius * math.cos(angle);
      final y2 = center.dy - radius * math.sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), gridPaint);
    }
  }

  void _drawBlochVector(Canvas canvas, Offset center, double radius, List<double> vector) {
    if (vector.length < 3) return;

    final x = vector[0];
    final y = vector[1];
    final z = vector[2];

    // Project 3D coordinates to 2D (simple orthographic projection)
    final projectedX = center.dx + x * radius;
    final projectedY = center.dy - z * radius; // Z maps to vertical
    final projectedEnd = Offset(projectedX, projectedY);
    final magnitude = math.sqrt(x*x + y*y + z*z);

    // Determine shape and color based on quantum state
    final stateInfo = _getStateVisualization(x, y, z, magnitude);

    // Draw vector arrow
    final vectorPaint = Paint()
      ..color = stateInfo['color']
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, projectedEnd, vectorPaint);

    // Draw arrowhead
    final arrowLength = 15.0;
    final arrowAngle = math.pi / 6;
    final vectorAngle = math.atan2(projectedEnd.dy - center.dy, projectedEnd.dx - center.dx);

    final arrowPoint1 = Offset(
      projectedEnd.dx - arrowLength * math.cos(vectorAngle - arrowAngle),
      projectedEnd.dy - arrowLength * math.sin(vectorAngle - arrowAngle),
    );
    final arrowPoint2 = Offset(
      projectedEnd.dx - arrowLength * math.cos(vectorAngle + arrowAngle),
      projectedEnd.dy - arrowLength * math.sin(vectorAngle + arrowAngle),
    );

    canvas.drawLine(projectedEnd, arrowPoint1, vectorPaint);
    canvas.drawLine(projectedEnd, arrowPoint2, vectorPaint);

    // Draw state-specific shape at endpoint
    _drawStateShape(canvas, projectedEnd, stateInfo);

    // Draw magnitude circle indicator
    final magnitudePaint = Paint()
      ..color = stateInfo['color'].withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, magnitude * radius, magnitudePaint);
  }

  Map<String, dynamic> _getStateVisualization(double x, double y, double z, double magnitude) {
    // Determine state type and visualization
    final epsilon = 0.05; // Tolerance for state detection
    
    // Maximally mixed state (center of sphere)
    if (magnitude < epsilon) {
      return {
        'shape': 'mixed',
        'color': Colors.grey[600]!,
        'size': 12.0,
        'label': 'Mixed State'
      };
    }
    
    // Pure states (|0⟩ and |1⟩)
    if ((z > 1 - epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'ground',
        'color': Colors.blue[700]!,
        'size': 10.0,
        'label': '|0⟩ Ground State'
      };
    }
    
    if ((z < -1 + epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'excited',
        'color': Colors.red[600]!,
        'size': 10.0,
        'label': '|1⟩ Excited State'
      };
    }
    
    // Superposition states
    if ((z.abs() < epsilon) && (x > 1 - epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'plus',
        'color': Colors.green[600]!,
        'size': 10.0,
        'label': '|+⟩ Plus State'
      };
    }
    
    if ((z.abs() < epsilon) && (x < -1 + epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'minus',
        'color': Colors.orange[600]!,
        'size': 10.0,
        'label': '|-⟩ Minus State'
      };
    }
    
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y > 1 - epsilon)) {
      return {
        'shape': 'right',
        'color': Colors.teal[600]!,
        'size': 10.0,
        'label': '|R⟩ Right Circular'
      };
    }
    
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y < -1 + epsilon)) {
      return {
        'shape': 'left',
        'color': Colors.purple[600]!,
        'size': 10.0,
        'label': '|L⟩ Left Circular'
      };
    }
    
    // Partial mixed states (between center and surface)
    if (magnitude < 0.5) {
      return {
        'shape': 'partial_mixed',
        'color': Colors.amber[600]!,
        'size': 8.0 + magnitude * 4,
        'label': 'Partially Mixed'
      };
    }
    
    // General superposition states
    if (magnitude > 0.8) {
      return {
        'shape': 'superposition',
        'color': Colors.indigo[600]!,
        'size': 9.0,
        'label': 'Superposition State'
      };
    }
    
    // Default case
    return {
      'shape': 'general',
      'color': Colors.deepPurple[600]!,
      'size': 8.0,
      'label': 'General Quantum State'
    };
  }

  void _drawStateShape(Canvas canvas, Offset position, Map<String, dynamic> stateInfo) {
    final paint = Paint()
      ..color = stateInfo['color']
      ..style = PaintingStyle.fill;
    
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final size = stateInfo['size'];
    
    switch (stateInfo['shape']) {
      case 'mixed':
        // Draw a hollow circle for mixed state
        final mixedPaint = Paint()
          ..color = stateInfo['color']
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(position, size, mixedPaint);
        // Add cross pattern
        canvas.drawLine(
          Offset(position.dx - size/2, position.dy - size/2),
          Offset(position.dx + size/2, position.dy + size/2),
          mixedPaint,
        );
        canvas.drawLine(
          Offset(position.dx + size/2, position.dy - size/2),
          Offset(position.dx - size/2, position.dy + size/2),
          mixedPaint,
        );
        break;
        
      case 'ground':
        // Draw downward triangle for |0⟩
        final path = Path();
        path.moveTo(position.dx, position.dy - size/2);
        path.lineTo(position.dx - size/2, position.dy + size/2);
        path.lineTo(position.dx + size/2, position.dy + size/2);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        break;
        
      case 'excited':
        // Draw upward triangle for |1⟩
        final path = Path();
        path.moveTo(position.dx, position.dy + size/2);
        path.lineTo(position.dx - size/2, position.dy - size/2);
        path.lineTo(position.dx + size/2, position.dy - size/2);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        break;
        
      case 'plus':
        // Draw plus sign for |+⟩
        final lineWidth = 3.0;
        final plusPaint = Paint()
          ..color = stateInfo['color']
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(position.dx - size/2, position.dy),
          Offset(position.dx + size/2, position.dy),
          plusPaint,
        );
        canvas.drawLine(
          Offset(position.dx, position.dy - size/2),
          Offset(position.dx, position.dy + size/2),
          plusPaint,
        );
        break;
        
      case 'minus':
        // Draw minus sign for |-⟩
        final minusPaint = Paint()
          ..color = stateInfo['color']
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(position.dx - size/2, position.dy),
          Offset(position.dx + size/2, position.dy),
          minusPaint,
        );
        break;
        
      case 'right':
        // Draw right-pointing arrow for |R⟩
        final path = Path();
        path.moveTo(position.dx - size/2, position.dy - size/3);
        path.lineTo(position.dx + size/4, position.dy - size/3);
        path.lineTo(position.dx + size/4, position.dy - size/2);
        path.lineTo(position.dx + size/2, position.dy);
        path.lineTo(position.dx + size/4, position.dy + size/2);
        path.lineTo(position.dx + size/4, position.dy + size/3);
        path.lineTo(position.dx - size/2, position.dy + size/3);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        break;
        
      case 'left':
        // Draw left-pointing arrow for |L⟩
        final path = Path();
        path.moveTo(position.dx + size/2, position.dy - size/3);
        path.lineTo(position.dx - size/4, position.dy - size/3);
        path.lineTo(position.dx - size/4, position.dy - size/2);
        path.lineTo(position.dx - size/2, position.dy);
        path.lineTo(position.dx - size/4, position.dy + size/2);
        path.lineTo(position.dx - size/4, position.dy + size/3);
        path.lineTo(position.dx + size/2, position.dy + size/3);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        break;
        
      case 'partial_mixed':
        // Draw a diamond for partially mixed states
        final path = Path();
        path.moveTo(position.dx, position.dy - size/2);
        path.lineTo(position.dx + size/2, position.dy);
        path.lineTo(position.dx, position.dy + size/2);
        path.lineTo(position.dx - size/2, position.dy);
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        break;
        
      case 'superposition':
        // Draw a star for superposition states
        final path = Path();
        final outerRadius = size / 2;
        final innerRadius = size / 4;
        for (int i = 0; i < 5; i++) {
          final outerAngle = (i * 2 * math.pi / 5) - math.pi / 2;
          final innerAngle = ((i + 0.5) * 2 * math.pi / 5) - math.pi / 2;
          
          final outerX = position.dx + outerRadius * math.cos(outerAngle);
          final outerY = position.dy + outerRadius * math.sin(outerAngle);
          final innerX = position.dx + innerRadius * math.cos(innerAngle);
          final innerY = position.dy + innerRadius * math.sin(innerAngle);
          
          if (i == 0) {
            path.moveTo(outerX, outerY);
          } else {
            path.lineTo(outerX, outerY);
          }
          path.lineTo(innerX, innerY);
        }
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, outlinePaint);
        break;
        
      default:
        // Draw regular circle for general states
        canvas.drawCircle(position, size/2, paint);
        canvas.drawCircle(position, size/2, outlinePaint);
        break;
    }
  }

  void _drawAxisLabels(Canvas canvas, Offset center, double radius) {
    final textStyle = TextStyle(
      color: Colors.grey[700],
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    // X labels
    _drawText(canvas, '+X', Offset(center.dx + radius + 15, center.dy - 5), textStyle.copyWith(color: Colors.red[600]));
    _drawText(canvas, '-X', Offset(center.dx - radius - 25, center.dy - 5), textStyle.copyWith(color: Colors.red[600]));

    // Z labels (|0⟩ and |1⟩)
    _drawText(canvas, '|0⟩', Offset(center.dx + 10, center.dy - radius - 5), textStyle.copyWith(color: Colors.blue[600]));
    _drawText(canvas, '|1⟩', Offset(center.dx + 10, center.dy + radius + 15), textStyle.copyWith(color: Colors.blue[600]));

    // Y labels
    final yOffset = radius * 0.6;
    _drawText(canvas, '+Y', Offset(center.dx + yOffset + 10, center.dy - yOffset * 0.5 - 5), textStyle.copyWith(color: Colors.green[600]));
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
