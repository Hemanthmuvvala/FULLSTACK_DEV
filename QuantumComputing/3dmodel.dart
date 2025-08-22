import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D Quantum Bloch Sphere Visualizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFF0A0E1A),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1A1F2E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: Color(0xFF1A1F2E),
          elevation: 8,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
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
  String selectedExample = 'bell';
  
  late AnimationController _globalRotationController;
  late AnimationController _pulseController;
  late AnimationController _vectorAnimationController;
  late Animation<double> _globalRotation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _vectorAnimation;
  
  final String baseUrl = "https://qiskitapi.onrender.com/examples";
  
  final Map<String, String> examples = {
    'bell': 'Bell State (Entangled)',
    'ground_states': 'Ground States |00⟩',
    'excited_states': 'Excited States |11⟩',
    'plus_states': 'Plus States |++⟩',
    'minus_states': 'Minus States |--⟩',
    'circular_states': 'Circular Polarization',
    'superposition_variety': 'Superposition Variety',
    'partial_mixed': 'Partially Mixed States',
    'ghz_state': 'GHZ State (3-qubit)',
    'pauli_gates': 'Pauli Gate Effects',
    'random_rotations': 'Random Rotations',
  };
  
  @override
  void initState() {
    super.initState();
    
    _globalRotationController = AnimationController(
      duration: Duration(seconds: 30),
      vsync: this,
    );
    _globalRotation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _globalRotationController,
      curve: Curves.linear,
    ));
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _vectorAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _vectorAnimation = CurvedAnimation(
      parent: _vectorAnimationController,
      curve: Curves.elasticOut,
    );
    
    _globalRotationController.repeat();
    _pulseController.repeat(reverse: true);
    
    fetchQuantumStates();
  }
  
  @override
  void dispose() {
    _globalRotationController.dispose();
    _pulseController.dispose();
    _vectorAnimationController.dispose();
    super.dispose();
  }

  Future<void> fetchQuantumStates() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$selectedExample'),
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
        
        _vectorAnimationController.reset();
        _vectorAnimationController.forward();
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = 'Connection error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isLoading ? Colors.orange : (error.isNotEmpty ? Colors.red : Colors.green),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12),
            Text('3D Quantum Bloch Sphere Visualizer'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchQuantumStates,
            tooltip: 'Refresh States',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 2.0,
            colors: [
              Color(0xFF1A1F2E),
              Color(0xFF0A0E1A),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildControlPanel(),
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

  Widget _buildControlPanel() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Color(0xFF2A2F3E), Color(0xFF1A1F2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree, color: Colors.cyan, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Quantum Circuit Examples',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                    ),
                    child: Text(
                      '${quantumStates.length} Qubits',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: DropdownButton<String>(
                  value: selectedExample,
                  isExpanded: true,
                  underline: SizedBox(),
                  dropdownColor: Color(0xFF1A1F2E),
                  style: TextStyle(color: Colors.white),
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.cyan),
                  items: examples.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          entry.value,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedExample = newValue;
                      });
                      fetchQuantumStates();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Computing Quantum States...',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'Performing partial trace operations',
            style: TextStyle(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Card(
        margin: EdgeInsets.all(32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Color(0xFF3A1F1F), Color(0xFF2A1F2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              SizedBox(height: 16),
              Text(
                'Quantum Connection Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: fetchQuantumStates,
                icon: Icon(Icons.refresh),
                label: Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          style: TextStyle(fontSize: 16, color: Colors.white60),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: quantumStates.length,
      itemBuilder: (context, index) {
        final entry = quantumStates.entries.elementAt(index);
        return _buildQubit3DCard(entry.key, entry.value, index);
      },
    );
  }

  Widget _buildQubit3DCard(String qubitName, List<double> blochVector, int index) {
    final x = blochVector[0];
    final y = blochVector[1];
    final z = blochVector[2];
    
    final r = math.sqrt(x*x + y*y + z*z);
    final theta = r > 0 ? math.acos(z / r) : 0.0;
    final phi = math.atan2(y, x);
    
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Card(
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Color(0xFF2A2F3E).withOpacity(0.9),
                Color(0xFF1A1F2E).withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _getQubitAccentColor(index).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildQubitHeader(qubitName, index),
              Container(
                height: 400,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _globalRotation,
                          _pulseAnimation,
                          _vectorAnimation,
                        ]),
                        builder: (context, child) {
                          return Container(
                            margin: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFF0A0E1A).withOpacity(0.5),
                                  Color(0xFF000000).withOpacity(0.8),
                                ],
                              ),
                              border: Border.all(
                                color: _getQubitAccentColor(index).withOpacity(0.2),
                              ),
                            ),
                            child: CustomPaint(
                              painter: Advanced3DBlochSpherePainter(
                                blochVector: blochVector,
                                globalRotation: _globalRotation.value,
                                pulseScale: _pulseAnimation.value,
                                vectorAnimation: _vectorAnimation.value,
                                accentColor: _getQubitAccentColor(index),
                              ),
                              size: Size.infinite,
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildQuantumStateInfo(x, y, z, r, theta, phi, index),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQubitHeader(String qubitName, int index) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        gradient: LinearGradient(
          colors: [
            _getQubitAccentColor(index).withOpacity(0.2),
            _getQubitAccentColor(index).withOpacity(0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: _getQubitAccentColor(index).withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getQubitAccentColor(index),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getQubitAccentColor(index).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              'Reduced Density Matrix',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getQubitAccentColor(int index) {
    final colors = [
      Colors.cyan,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.pink,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Widget _buildQuantumStateInfo(double x, double y, double z, double r, double theta, double phi, int index) {
    final stateInfo = _getStateInfo(x, y, z, r);
    
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'State Analysis',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          
          // State Type Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  stateInfo['color'].withOpacity(0.2),
                  stateInfo['color'].withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: stateInfo['color'].withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  child: CustomPaint(
                    painter: StateShapePainter(
                      shape: stateInfo['shape'],
                      color: stateInfo['color'],
                      size: 16,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    stateInfo['label'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: stateInfo['color'],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
          
          // Bloch Vector Components
          Text(
            'Bloch Vector',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 12),
          
          _buildVectorComponent('X', x, Colors.redAccent),
          SizedBox(height: 8),
          _buildVectorComponent('Y', y, Colors.greenAccent),
          SizedBox(height: 8),
          _buildVectorComponent('Z', z, Colors.blueAccent),
          
          SizedBox(height: 20),
          
          // Spherical Coordinates
          Text(
            'Spherical Coordinates',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 12),
          
          _buildStateProperty('|r|', r.toStringAsFixed(3), Colors.white),
          _buildStateProperty('θ', '${(theta * 180 / math.pi).toStringAsFixed(1)}°', Colors.white),
          _buildStateProperty('φ', '${(phi * 180 / math.pi).toStringAsFixed(1)}°', Colors.white),
          
          Spacer(),
          
          // Purity Indicator
          _buildPurityIndicator(r, _getQubitAccentColor(index)),
        ],
      ),
    );
  }

  Widget _buildVectorComponent(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
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
        SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.white10,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (value.abs() / 1.0).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: color,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Container(
          width: 60,
          child: Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildStateProperty(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurityIndicator(double magnitude, Color accentColor) {
    final purity = magnitude;
    final isPure = purity > 0.95;
    final isPartiallyMixed = purity > 0.1 && purity <= 0.95;
    final isMixed = purity <= 0.1;
    
    Color indicatorColor;
    String stateText;
    IconData iconData;
    
    if (isPure) {
      indicatorColor = Colors.green;
      stateText = 'Pure State';
      iconData = Icons.circle;
    } else if (isPartiallyMixed) {
      indicatorColor = Colors.orange;
      stateText = 'Partially Mixed';
      iconData = Icons.blur_on;
    } else {
      indicatorColor = Colors.red;
      stateText = 'Maximally Mixed';
      iconData = Icons.scatter_plot;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            indicatorColor.withOpacity(0.2),
            indicatorColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: indicatorColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 14,
            color: indicatorColor,
          ),
          SizedBox(width: 6),
          Text(
            stateText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: indicatorColor,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '(${(purity * 100).toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 10,
              color: indicatorColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStateInfo(double x, double y, double z, double magnitude) {
    final epsilon = 0.05;
    
    if (magnitude < epsilon) {
      return {'shape': 'mixed', 'color': Colors.grey[400]!, 'label': 'Maximally Mixed'};
    }
    if ((z > 1 - epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'ground', 'color': Colors.blue[400]!, 'label': '|0⟩ Ground State'};
    }
    if ((z < -1 + epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'excited', 'color': Colors.red[400]!, 'label': '|1⟩ Excited State'};
    }
    if ((z.abs() < epsilon) && (x > 1 - epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'plus', 'color': Colors.green[400]!, 'label': '|+⟩ Plus State'};
    }
    if ((z.abs() < epsilon) && (x < -1 + epsilon) && (y.abs() < epsilon)) {
      return {'shape': 'minus', 'color': Colors.orange[400]!, 'label': '|-⟩ Minus State'};
    }
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y > 1 - epsilon)) {
      return {'shape': 'right', 'color': Colors.teal[400]!, 'label': '|R⟩ Right Circular'};
    }
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y < -1 + epsilon)) {
      return {'shape': 'left', 'color': Colors.purple[400]!, 'label': '|L⟩ Left Circular'};
    }
    if (magnitude < 0.5) {
      return {'shape': 'partial_mixed', 'color': Colors.amber[400]!, 'label': 'Partially Mixed'};
    }
    if (magnitude > 0.8) {
      return {'shape': 'superposition', 'color': Colors.indigo[400]!, 'label': 'Superposition'};
    }
    return {'shape': 'general', 'color': Colors.deepPurple[400]!, 'label': 'General Quantum State'};
  }
}

class Advanced3DBlochSpherePainter extends CustomPainter {
  final List<double> blochVector;
  final double globalRotation;
  final double pulseScale;
  final double vectorAnimation;
  final Color accentColor;

  Advanced3DBlochSpherePainter({
    required this.blochVector,
    required this.globalRotation,
    required this.pulseScale,
    required this.vectorAnimation,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2 * 0.7;
    final radius = baseRadius * pulseScale;

    // Apply 3D transformation matrices
    final rotX = globalRotation * 0.3;
    final rotY = globalRotation;
    final rotZ = globalRotation * 0.7;

    // Draw background glow
    _drawBackgroundGlow(canvas, center, radius);
    
    // Draw 3D grid lines
    _draw3DGridLines(canvas, center, radius, rotX, rotY, rotZ);
    
    // Draw main sphere
    _draw3DSphere(canvas, center, radius, rotX, rotY, rotZ);
    
    // Draw coordinate axes
    _draw3DAxes(canvas, center, radius, rotX, rotY, rotZ);
    
    // Draw Bloch vector
    _draw3DBlochVector(canvas, center, radius, blochVector, rotX, rotY, rotZ);
    
    // Draw axis labels
    _drawAxisLabels(canvas, center, radius, rotX, rotY, rotZ);
  }

  void _drawBackgroundGlow(Canvas canvas, Offset center, double radius) {
    final glowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20)
      ..color = accentColor.withOpacity(0.1);
    
    canvas.drawCircle(center, radius * 1.2, glowPaint);
    
    final innerGlowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10)
      ..color = accentColor.withOpacity(0.05);
    
    canvas.drawCircle(center, radius * 0.8, innerGlowPaint);
  }

  void _draw3DGridLines(Canvas canvas, Offset center, double radius, double rotX, double rotY, double rotZ) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw latitude lines
    for (int i = 1; i < 6; i++) {
      final latRadius = radius * math.sin(i * math.pi / 6);
      final latY = radius * math.cos(i * math.pi / 6);
      
      final path = Path();
      for (int j = 0; j <= 50; j++) {
        final angle = j * 2 * math.pi / 50;
        final x = latRadius * math.cos(angle);
        final z = latRadius * math.sin(angle);
        
        final transformed = _transform3D(x, latY, z, rotX, rotY, rotZ);
        final projected = _project3D(transformed, center, radius);
        
        if (j == 0) {
          path.moveTo(projected.dx, projected.dy);
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // Draw longitude lines
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final path = Path();
      
      for (int j = 0; j <= 50; j++) {
        final phi = j * math.pi / 50;
        final x = radius * math.sin(phi) * math.cos(angle);
        final y = radius * math.cos(phi);
        final z = radius * math.sin(phi) * math.sin(angle);
        
        final transformed = _transform3D(x, y, z, rotX, rotY, rotZ);
        final projected = _project3D(transformed, center, radius);
        
        if (j == 0) {
          path.moveTo(projected.dx, projected.dy);
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }
  }

  void _draw3DSphere(Canvas canvas, Offset center, double radius, double rotX, double rotY, double rotZ) {
    // Main sphere outline
    final spherePaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius, spherePaint);

    // Inner sphere with gradient effect
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withOpacity(0.05),
          accentColor.withOpacity(0.02),
          Colors.transparent,
        ],
        stops: [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, gradientPaint);
  }

  void _draw3DAxes(Canvas canvas, Offset center, double radius, double rotX, double rotY, double rotZ) {
    // X-axis (red)
    final xAxisPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    final xStart = _project3D(_transform3D(-radius, 0, 0, rotX, rotY, rotZ), center, radius);
    final xEnd = _project3D(_transform3D(radius, 0, 0, rotX, rotY, rotZ), center, radius);
    canvas.drawLine(xStart, xEnd, xAxisPaint);
    
    // Y-axis (green)
    final yAxisPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    final yStart = _project3D(_transform3D(0, -radius, 0, rotX, rotY, rotZ), center, radius);
    final yEnd = _project3D(_transform3D(0, radius, 0, rotX, rotY, rotZ), center, radius);
    canvas.drawLine(yStart, yEnd, yAxisPaint);
    
    // Z-axis (blue)
    final zAxisPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    final zStart = _project3D(_transform3D(0, 0, -radius, rotX, rotY, rotZ), center, radius);
    final zEnd = _project3D(_transform3D(0, 0, radius, rotX, rotY, rotZ), center, radius);
    canvas.drawLine(zStart, zEnd, zAxisPaint);

    // Draw arrowheads for axes
    _drawArrowhead(canvas, xStart, xEnd, Colors.redAccent);
    _drawArrowhead(canvas, yStart, yEnd, Colors.greenAccent);
    _drawArrowhead(canvas, zStart, zEnd, Colors.blueAccent);
  }

  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final direction = Offset(end.dx - start.dx, end.dy - start.dy);
    final length = math.sqrt(direction.dx * direction.dx + direction.dy * direction.dy);
    
    if (length == 0) return;
    
    final unitDir = Offset(direction.dx / length, direction.dy / length);
    final arrowLength = 12.0;
    final arrowWidth = 6.0;
    
    final perp = Offset(-unitDir.dy, unitDir.dx);
    
    final tip = end;
    final left = Offset(
      tip.dx - arrowLength * unitDir.dx + arrowWidth * perp.dx,
      tip.dy - arrowLength * unitDir.dy + arrowWidth * perp.dy,
    );
    final right = Offset(
      tip.dx - arrowLength * unitDir.dx - arrowWidth * perp.dx,
      tip.dy - arrowLength * unitDir.dy - arrowWidth * perp.dy,
    );
    
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    
    canvas.drawPath(path, paint);
  }

  void _draw3DBlochVector(Canvas canvas, Offset center, double radius, List<double> vector, double rotX, double rotY, double rotZ) {
    if (vector.length < 3) return;

    final x = vector[0] * vectorAnimation;
    final y = vector[1] * vectorAnimation;
    final z = vector[2] * vectorAnimation;
    final magnitude = math.sqrt(x*x + y*y + z*z);

    if (magnitude < 0.001) {
      // Draw special indicator for mixed state at center
      _drawMixedStateIndicator(canvas, center);
      return;
    }

    // Transform and project vector endpoint
    final vectorEnd3D = _transform3D(x * radius, y * radius, z * radius, rotX, rotY, rotZ);
    final vectorEndProjected = _project3D(vectorEnd3D, center, radius);

    // Determine state info for coloring
    final stateInfo = _getStateVisualization(x, y, z, magnitude);

    // Draw vector trail effect
    _drawVectorTrail(canvas, center, vectorEndProjected, stateInfo['color']);

    // Draw main vector
    final vectorPaint = Paint()
      ..color = stateInfo['color']
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);

    canvas.drawLine(center, vectorEndProjected, vectorPaint);

    // Draw vector arrowhead
    _drawVectorArrowhead(canvas, center, vectorEndProjected, stateInfo['color']);

    // Draw pulsing endpoint with quantum state shape
    _drawQuantumStateShape(canvas, vectorEndProjected, stateInfo, pulseScale);

    // Draw magnitude indicator circle
    final magnitudeCirclePaint = Paint()
      ..color = stateInfo['color'].withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, magnitude * radius * vectorAnimation, magnitudeCirclePaint);
  }

  void _drawVectorTrail(Canvas canvas, Offset start, Offset end, Color color) {
    final trailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.1),
          color.withOpacity(0.3),
          color.withOpacity(0.1),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromPoints(start, end))
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, trailPaint);
  }

  void _drawVectorArrowhead(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
    
    final direction = Offset(end.dx - start.dx, end.dy - start.dy);
    final length = math.sqrt(direction.dx * direction.dx + direction.dy * direction.dy);
    
    if (length == 0) return;
    
    final unitDir = Offset(direction.dx / length, direction.dy / length);
    final arrowLength = 18.0;
    final arrowWidth = 9.0;
    
    final perp = Offset(-unitDir.dy, unitDir.dx);
    
    final tip = end;
    final left = Offset(
      tip.dx - arrowLength * unitDir.dx + arrowWidth * perp.dx,
      tip.dy - arrowLength * unitDir.dy + arrowWidth * perp.dy,
    );
    final right = Offset(
      tip.dx - arrowLength * unitDir.dx - arrowWidth * perp.dx,
      tip.dy - arrowLength * unitDir.dy - arrowWidth * perp.dy,
    );
    
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    
    canvas.drawPath(path, paint);
  }

  void _drawQuantumStateShape(Canvas canvas, Offset position, Map<String, dynamic> stateInfo, double scale) {
    final paint = Paint()
      ..color = stateInfo['color']
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
    
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final size = (stateInfo['size'] ?? 12.0) * scale;
    
    switch (stateInfo['shape']) {
      case 'mixed':
        _drawMixedStateIndicator(canvas, position);
        break;
      case 'ground':
        _drawTriangle(canvas, position, size, true, paint, outlinePaint);
        break;
      case 'excited':
        _drawTriangle(canvas, position, size, false, paint, outlinePaint);
        break;
      case 'plus':
        _drawPlusSign(canvas, position, size, paint);
        break;
      case 'minus':
        _drawMinusSign(canvas, position, size, paint);
        break;
      case 'right':
        _drawArrow(canvas, position, size, true, paint, outlinePaint);
        break;
      case 'left':
        _drawArrow(canvas, position, size, false, paint, outlinePaint);
        break;
      case 'partial_mixed':
        _drawDiamond(canvas, position, size, paint, outlinePaint);
        break;
      case 'superposition':
        _drawStar(canvas, position, size, paint, outlinePaint);
        break;
      default:
        canvas.drawCircle(position, size/2, paint);
        canvas.drawCircle(position, size/2, outlinePaint);
        break;
    }
  }

  void _drawMixedStateIndicator(Canvas canvas, Offset center) {
    final mixedPaint = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
    
    // Pulsing circle
    canvas.drawCircle(center, 15 * pulseScale, mixedPaint);
    
    // Cross pattern
    final crossSize = 10 * pulseScale;
    canvas.drawLine(
      Offset(center.dx - crossSize, center.dy - crossSize),
      Offset(center.dx + crossSize, center.dy + crossSize),
      mixedPaint,
    );
    canvas.drawLine(
      Offset(center.dx + crossSize, center.dy - crossSize),
      Offset(center.dx - crossSize, center.dy + crossSize),
      mixedPaint,
    );
  }

  void _drawTriangle(Canvas canvas, Offset center, double size, bool upward, Paint fillPaint, Paint outlinePaint) {
    final path = Path();
    if (upward) {
      path.moveTo(center.dx, center.dy - size/2);
      path.lineTo(center.dx - size/2, center.dy + size/2);
      path.lineTo(center.dx + size/2, center.dy + size/2);
    } else {
      path.moveTo(center.dx, center.dy + size/2);
      path.lineTo(center.dx - size/2, center.dy - size/2);
      path.lineTo(center.dx + size/2, center.dy - size/2);
    }
    path.close();
    
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawPlusSign(Canvas canvas, Offset center, double size, Paint paint) {
    final strokePaint = Paint()
      ..color = paint.color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
    
    canvas.drawLine(
      Offset(center.dx - size/2, center.dy),
      Offset(center.dx + size/2, center.dy),
      strokePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size/2),
      Offset(center.dx, center.dy + size/2),
      strokePaint,
    );
  }

  void _drawMinusSign(Canvas canvas, Offset center, double size, Paint paint) {
    final strokePaint = Paint()
      ..color = paint.color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
    
    canvas.drawLine(
      Offset(center.dx - size/2, center.dy),
      Offset(center.dx + size/2, center.dy),
      strokePaint,
    );
  }

  void _drawArrow(Canvas canvas, Offset center, double size, bool rightward, Paint fillPaint, Paint outlinePaint) {
    final path = Path();
    if (rightward) {
      path.moveTo(center.dx - size/2, center.dy - size/3);
      path.lineTo(center.dx + size/4, center.dy - size/3);
      path.lineTo(center.dx + size/4, center.dy - size/2);
      path.lineTo(center.dx + size/2, center.dy);
      path.lineTo(center.dx + size/4, center.dy + size/2);
      path.lineTo(center.dx + size/4, center.dy + size/3);
      path.lineTo(center.dx - size/2, center.dy + size/3);
    } else {
      path.moveTo(center.dx + size/2, center.dy - size/3);
      path.lineTo(center.dx - size/4, center.dy - size/3);
      path.lineTo(center.dx - size/4, center.dy - size/2);
      path.lineTo(center.dx - size/2, center.dy);
      path.lineTo(center.dx - size/4, center.dy + size/2);
      path.lineTo(center.dx - size/4, center.dy + size/3);
      path.lineTo(center.dx + size/2, center.dy + size/3);
    }
    path.close();
    
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint fillPaint, Paint outlinePaint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size/2);
    path.lineTo(center.dx + size/2, center.dy);
    path.lineTo(center.dx, center.dy + size/2);
    path.lineTo(center.dx - size/2, center.dy);
    path.close();
    
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint fillPaint, Paint outlinePaint) {
    final path = Path();
    final outerRadius = size / 2;
    final innerRadius = size / 4;
    
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
    
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawAxisLabels(Canvas canvas, Offset center, double radius, double rotX, double rotY, double rotZ) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.5),
          offset: Offset(1, 1),
          blurRadius: 2,
        ),
      ],
    );

    // X labels
    final xPos = _project3D(_transform3D(radius + 20, 0, 0, rotX, rotY, rotZ), center, radius);
    final xNeg = _project3D(_transform3D(-radius - 20, 0, 0, rotX, rotY, rotZ), center, radius);
    _drawText(canvas, '+X', xPos, textStyle.copyWith(color: Colors.redAccent));
    _drawText(canvas, '-X', xNeg, textStyle.copyWith(color: Colors.redAccent.withOpacity(0.7)));

    // Y labels  
    final yPos = _project3D(_transform3D(0, radius + 20, 0, rotX, rotY, rotZ), center, radius);
    final yNeg = _project3D(_transform3D(0, -radius - 20, 0, rotX, rotY, rotZ), center, radius);
    _drawText(canvas, '+Y', yPos, textStyle.copyWith(color: Colors.greenAccent));
    _drawText(canvas, '-Y', yNeg, textStyle.copyWith(color: Colors.greenAccent.withOpacity(0.7)));

    // Z labels (quantum state labels)
    final zPos = _project3D(_transform3D(0, 0, radius + 20, rotX, rotY, rotZ), center, radius);
    final zNeg = _project3D(_transform3D(0, 0, -radius - 20, rotX, rotY, rotZ), center, radius);
    _drawText(canvas, '|0⟩', zPos, textStyle.copyWith(color: Colors.blueAccent));
    _drawText(canvas, '|1⟩', zNeg, textStyle.copyWith(color: Colors.blueAccent.withOpacity(0.7)));
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final offset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, offset);
  }

  // 3D transformation helpers
  List<double> _transform3D(double x, double y, double z, double rotX, double rotY, double rotZ) {
    // Rotation around X axis
    final y1 = y * math.cos(rotX) - z * math.sin(rotX);
    final z1 = y * math.sin(rotX) + z * math.cos(rotX);
    
    // Rotation around Y axis  
    final x2 = x * math.cos(rotY) + z1 * math.sin(rotY);
    final z2 = -x * math.sin(rotY) + z1 * math.cos(rotY);
    
    // Rotation around Z axis
    final x3 = x2 * math.cos(rotZ) - y1 * math.sin(rotZ);
    final y3 = x2 * math.sin(rotZ) + y1 * math.cos(rotZ);
    
    return [x3, y3, z2];
  }

  Offset _project3D(List<double> point3D, Offset center, double radius) {
    // Simple orthographic projection with perspective hint
    final perspective = 1.0 / (1.0 + point3D[2] / (radius * 3));
    return Offset(
      center.dx + point3D[0] * perspective,
      center.dy - point3D[1] * perspective, // Flip Y for screen coordinates
    );
  }

  Map<String, dynamic> _getStateVisualization(double x, double y, double z, double magnitude) {
    final epsilon = 0.05;
    
    if (magnitude < epsilon) {
      return {
        'shape': 'mixed',
        'color': Colors.grey[500]!,
        'size': 20.0,
        'label': 'Mixed State'
      };
    }
    
    if ((z > 1 - epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'ground',
        'color': Colors.blue[400]!,
        'size': 16.0,
        'label': '|0⟩ Ground State'
      };
    }
    
    if ((z < -1 + epsilon) && (x.abs() < epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'excited',
        'color': Colors.red[400]!,
        'size': 16.0,
        'label': '|1⟩ Excited State'
      };
    }
    
    if ((z.abs() < epsilon) && (x > 1 - epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'plus',
        'color': Colors.green[400]!,
        'size': 16.0,
        'label': '|+⟩ Plus State'
      };
    }
    
    if ((z.abs() < epsilon) && (x < -1 + epsilon) && (y.abs() < epsilon)) {
      return {
        'shape': 'minus',
        'color': Colors.orange[400]!,
        'size': 16.0,
        'label': '|-⟩ Minus State'
      };
    }
    
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y > 1 - epsilon)) {
      return {
        'shape': 'right',
        'color': Colors.teal[400]!,
        'size': 16.0,
        'label': '|R⟩ Right Circular'
      };
    }
    
    if ((z.abs() < epsilon) && (x.abs() < epsilon) && (y < -1 + epsilon)) {
      return {
        'shape': 'left',
        'color': Colors.purple[400]!,
        'size': 16.0,
        'label': '|L⟩ Left Circular'
      };
    }
    
    if (magnitude < 0.5) {
      return {
        'shape': 'partial_mixed',
        'color': Colors.amber[400]!,
        'size': 12.0 + magnitude * 8,
        'label': 'Partially Mixed'
      };
    }
    
    if (magnitude > 0.8) {
      return {
        'shape': 'superposition',
        'color': Colors.indigo[400]!,
        'size': 14.0,
        'label': 'Superposition State'
      };
    }
    
    return {
      'shape': 'general',
      'color': Colors.deepPurple[400]!,
      'size': 12.0,
      'label': 'General Quantum State'
    };
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
}
