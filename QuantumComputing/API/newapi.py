from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Literal, Dict
from qiskit import QuantumCircuit
from qiskit.quantum_info import Statevector, DensityMatrix, partial_trace, Operator, Pauli
import numpy as np

app = FastAPI(title="Quantum State Visualizer API", version="0.1")

# Allow local Flutter dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- Models ----------
GateName = Literal[
    "h", "x", "y", "z", "rx", "ry", "rz", "sx", "t", "s", "cx", "cz"
]

class Gate(BaseModel):
    name: GateName
    target: int
    control: Optional[int] = None
    params: Optional[List[float]] = None  # e.g., angles for rx/ry/rz

class CircuitSpec(BaseModel):
    num_qubits: int
    gates: List[Gate]

# ---------- Helpers ----------
def build_circuit(spec: CircuitSpec) -> QuantumCircuit:
    qc = QuantumCircuit(spec.num_qubits)
    for g in spec.gates:
        name = g.name.lower()
        t = g.target
        c = g.control
        p = g.params or []
        
        if name == "h":
            qc.h(t)
        elif name == "x":
            qc.x(t)
        elif name == "y":
            qc.y(t)
        elif name == "z":
            qc.z(t)
        elif name == "sx":
            qc.sx(t)
        elif name == "s":
            qc.s(t)
        elif name == "t":
            qc.t(t)
        elif name == "rx":
            qc.rx(p[0], t)
        elif name == "ry":
            qc.ry(p[0], t)
        elif name == "rz":
            qc.rz(p[0], t)
        elif name == "cx":
            assert c is not None, "cx requires control"
            qc.cx(c, t)
        elif name == "cz":
            assert c is not None, "cz requires control"
            qc.cz(c, t)
        else:
            raise ValueError(f"Unsupported gate: {name}")
    return qc

def simulate_statevector(qc: QuantumCircuit) -> Statevector:
    sv = Statevector.from_instruction(qc)
    return sv

def reduced_dm_for_qubit(dm: DensityMatrix, qubit_index: int, num_qubits: int) -> DensityMatrix:
    # partial trace over all qubits except the one we want to keep
    trace_out = [i for i in range(num_qubits) if i != qubit_index]
    return partial_trace(dm, trace_out)

def bloch_vector_from_dm(dm1: DensityMatrix) -> List[float]:
    # For a single-qubit density matrix ρ, Bloch vector components are:
    # x = Tr(ρ X), y = Tr(ρ Y), z = Tr(ρ Z)
    X = Pauli("X").to_matrix()
    Y = Pauli("Y").to_matrix()
    Z = Pauli("Z").to_matrix()
    
    rho = np.array(dm1.data)
    x = float(np.real(np.trace(rho @ X)))
    y = float(np.real(np.trace(rho @ Y)))
    z = float(np.real(np.trace(rho @ Z)))
    
    # clamp for numeric stability
    def clamp(v):
        return max(-1.0, min(1.0, v))
    
    return [clamp(x), clamp(y), clamp(z)]

# ---------- Routes ----------
@app.get("/")
def root():
    return {"ok": True, "service": "quantum-state-visualizer", "version": "0.1"}

@app.post("/bloch_vectors")
def bloch_vectors(spec: CircuitSpec) -> Dict[str, List[float]]:
    qc = build_circuit(spec)
    sv = simulate_statevector(qc)
    dm_full = DensityMatrix(sv)
    
    out: Dict[str, List[float]] = {}
    for q in range(spec.num_qubits):
        dm1 = reduced_dm_for_qubit(dm_full, q, spec.num_qubits)
        out[f"q{q}"] = bloch_vector_from_dm(dm1)
    
    return out

# ---------- Example Endpoints ----------

@app.get("/examples/bell")
def example_bell():
    """Bell state - both qubits maximally mixed (gray cross shapes)"""
    spec = CircuitSpec(
        num_qubits=2,
        gates=[Gate(name="h", target=0), Gate(name="cx", control=0, target=1)]
    )
    return bloch_vectors(spec)

@app.get("/examples/ground_states")
def example_ground_states():
    """Ground states |00⟩ - blue downward triangles at north pole"""
    spec = CircuitSpec(
        num_qubits=2,
        gates=[]  # No gates = |00⟩ state
    )
    return bloch_vectors(spec)

@app.get("/examples/excited_states")
def example_excited_states():
    """Excited states |11⟩ - red upward triangles at south pole"""
    spec = CircuitSpec(
        num_qubits=2,
        gates=[Gate(name="x", target=0), Gate(name="x", target=1)]
    )
    return bloch_vectors(spec)

@app.get("/examples/mixed_states")
def example_mixed_states():
    """Mixed ground and excited - one triangle up, one down"""
    spec = CircuitSpec(
        num_qubits=2,
        gates=[Gate(name="x", target=1)]  # |01⟩ state
    )
    return bloch_vectors(spec)

@app.get("/examples/plus_states")
def example_plus_states():
    """Plus states |++⟩ - green plus signs on equator"""
    spec = CircuitSpec(
        num_qubits=2,
        gates=[Gate(name="h", target=0), Gate(name="h", target=1)]
    )
    return bloch_vectors(spec)

@app.get("/examples/minus_states")
def example_minus_states():
    """Minus states |--⟩ - orange minus signs on equator"""
    spec = CircuitSpec(
        num_qubits=2,
        gates=[
            Gate(name="h", target=0), Gate(name="z", target=0),
            Gate(name="h", target=1), Gate(name="z", target=1)
        ]
    )
    return bloch_vectors(spec)

@app.get("/examples/circular_states")
def example_circular_states():
    """Right and left circular - teal/purple arrows"""
    spec = CircuitSpec(
        num_qubits=2,
        gates=[
            Gate(name="h", target=0), Gate(name="s", target=0),  # |R⟩ for q0
            Gate(name="h", target=1), Gate(name="z", target=1), Gate(name="s", target=1)  # |L⟩ for q1
        ]
    )
    return bloch_vectors(spec)

@app.get("/examples/superposition_variety")
def example_superposition_variety():
    """Different superposition states - stars and shapes"""
    spec = CircuitSpec(
        num_qubits=3,
        gates=[
            Gate(name="ry", target=0, params=[np.pi/3]),    # Partial Y rotation
            Gate(name="rx", target=1, params=[np.pi/4]),    # Partial X rotation  
            Gate(name="rz", target=2, params=[np.pi/6])     # Partial Z rotation
        ]
    )
    return bloch_vectors(spec)

@app.get("/examples/partial_mixed")
def example_partial_mixed():
    """Partially mixed states - diamond shapes"""
    spec = CircuitSpec(
        num_qubits=3,
        gates=[
            Gate(name="h", target=0), 
            Gate(name="cx", control=0, target=1),  # Entangle q0-q1
            Gate(name="ry", target=2, params=[np.pi/6])  # q2 stays mostly pure
        ]
    )
    return bloch_vectors(spec)

@app.get("/examples/ghz_state")
def example_ghz_state():
    """GHZ state - all qubits maximally mixed"""
    spec = CircuitSpec(
        num_qubits=3,
        gates=[
            Gate(name="h", target=0),
            Gate(name="cx", control=0, target=1),
            Gate(name="cx", control=0, target=2)
        ]
    )
    return bloch_vectors(spec)

@app.get("/examples/w_state")
def example_w_state():
    """Approximation of W state"""
    spec = CircuitSpec(
        num_qubits=3,
        gates=[
            Gate(name="ry", target=0, params=[2*np.arccos(np.sqrt(2/3))]),
            Gate(name="cx", control=0, target=1),
            Gate(name="x", target=0),
            Gate(name="ry", target=0, params=[2*np.arccos(np.sqrt(1/2))]),
            Gate(name="cx", control=0, target=2),
            Gate(name="x", target=0)
        ]
    )
    return bloch_vectors(spec)

@app.get("/examples/random_rotations")
def example_random_rotations():
    """Random rotations showing various superposition states"""
    spec = CircuitSpec(
        num_qubits=4,
        gates=[
            Gate(name="ry", target=0, params=[0.7]),
            Gate(name="rx", target=1, params=[1.2]),  
            Gate(name="rz", target=2, params=[0.5]),
            Gate(name="ry", target=3, params=[2.1])
        ]
    )
    return bloch_vectors(spec)

@app.get("/examples/hadamard_test")
def example_hadamard_test():
    """Single Hadamard gate - perfect plus state"""
    spec = CircuitSpec(
        num_qubits=1,
        gates=[Gate(name="h", target=0)]
    )
    return bloch_vectors(spec)

@app.get("/examples/pauli_gates")
def example_pauli_gates():
    """Different Pauli gate effects"""
    spec = CircuitSpec(
        num_qubits=4,
        gates=[
            Gate(name="x", target=0),  # |1⟩ state (red triangle)
            Gate(name="h", target=1),  # |+⟩ state (green plus)
            Gate(name="h", target=2), Gate(name="z", target=2),  # |-⟩ state (orange minus)
            Gate(name="h", target=3), Gate(name="s", target=3)   # |R⟩ state (teal arrow)
        ]
    )
    return bloch_vectors(spec)

# ---------- Info Endpoints ----------

@app.get("/examples")
def list_examples():
    """List all available example endpoints"""
    examples = {
        "/examples/bell": "Bell state - maximally mixed qubits (gray crosses)",
        "/examples/ground_states": "Ground states |00⟩ (blue downward triangles)", 
        "/examples/excited_states": "Excited states |11⟩ (red upward triangles)",
        "/examples/mixed_states": "Mixed |01⟩ state (one up, one down triangle)",
        "/examples/plus_states": "Plus states |++⟩ (green plus signs)",
        "/examples/minus_states": "Minus states |--⟩ (orange minus signs)", 
        "/examples/circular_states": "Circular polarization states (teal/purple arrows)",
        "/examples/superposition_variety": "Various superposition states (stars/shapes)",
        "/examples/partial_mixed": "Partially mixed states (diamond shapes)",
        "/examples/ghz_state": "GHZ state - 3-qubit maximally entangled",
        "/examples/w_state": "W state approximation",
        "/examples/random_rotations": "Random rotation angles (4 qubits)",
        "/examples/hadamard_test": "Single qubit Hadamard (perfect plus state)",
        "/examples/pauli_gates": "Different Pauli gate effects on 4 qubits"
    }
    return {"available_examples": examples}

@app.get("/examples/shape_guide")
def shape_guide():
    """Guide to quantum state shapes and their meanings"""
    shapes = {
        "downward_triangle": {"state": "|0⟩ Ground", "color": "blue", "coordinates": "[0, 0, 1]"},
        "upward_triangle": {"state": "|1⟩ Excited", "color": "red", "coordinates": "[0, 0, -1]"},
        "plus_sign": {"state": "|+⟩ Plus", "color": "green", "coordinates": "[1, 0, 0]"},
        "minus_sign": {"state": "|-⟩ Minus", "color": "orange", "coordinates": "[-1, 0, 0]"},
        "right_arrow": {"state": "|R⟩ Right Circular", "color": "teal", "coordinates": "[0, 1, 0]"},
        "left_arrow": {"state": "|L⟩ Left Circular", "color": "purple", "coordinates": "[0, -1, 0]"},
        "hollow_circle_cross": {"state": "Maximally Mixed", "color": "gray", "coordinates": "[0, 0, 0]"},
        "diamond": {"state": "Partially Mixed", "color": "amber", "magnitude": "< 0.5"},
        "star": {"state": "General Superposition", "color": "indigo", "magnitude": "> 0.8"},
        "circle": {"state": "Other Quantum State", "color": "purple", "magnitude": "0.5-0.8"}
    }
    return {"shape_meanings": shapes}
