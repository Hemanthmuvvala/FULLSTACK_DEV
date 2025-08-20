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
    allow_origins=[""],
    allow_credentials=True,
    allow_methods=[""],
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
@app.get("/examples/bell")
def example_bell():
    spec = CircuitSpec(
        num_qubits=2,
        gates=[Gate(name="h", target=0), Gate(name="cx", control=0, target=1)]
    )
    return bloch_vectors(spec)
