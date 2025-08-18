import React, { useEffect, useMemo, useRef, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { AlertCircle, Bolt, Clock, Database, Download, Eye, Loader2, RefreshCw, Search, Shield, Terminal } from "lucide-react";
import { motion } from "framer-motion";
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip as ReTooltip, CartesianGrid } from "recharts";

// --- Helper types ---
interface IBMJobState {
  status: "Queued" | "Running" | "Completed" | "Cancelled" | "Failed" | string
  reason?: string
}

interface IBMJob {
  id: string
  backend: string
  status?: string // convenience mirror of state.status in some responses
  state?: IBMJobState
  created?: string
  program?: { id: string }
  usage?: { seconds?: number }
  tags?: string[]
  session_id?: string
  private?: boolean
  cost?: number
}

interface JobsResponse {
  jobs: IBMJob[]
  count: number
  limit: number
  offset: number
}

interface BackendSummary {
  name: string
  pending_jobs?: number
  operational?: boolean
}

// --- Small utilities ---
const fmtTime = (iso?: string) => (iso ? new Date(iso).toLocaleString() : "—");
const cls = (...xs: (string | false | undefined)[]) => xs.filter(Boolean).join(" ");

// Persist small secrets only in-memory; optionally in sessionStorage if the user opts in.
const useStickyState = <T,>(key: string, initial: T) => {
  const [val, setVal] = useState<T>(() => {
    try {
      const raw = sessionStorage.getItem(key);
      return raw ? (JSON.parse(raw) as T) : initial;
    } catch {
      return initial;
    }
  });
  useEffect(() => {
    try {
      sessionStorage.setItem(key, JSON.stringify(val));
    } catch {}
  }, [key, val]);
  return [val, setVal] as const;
};

export default function IBMQuantumLiveJobsDashboard() {
  const [apiKey, setApiKey] = useStickyState<string>("ibm_api_key", "");
  const [instanceCrn, setInstanceCrn] = useStickyState<string>("ibm_instance_crn", "");
  const [region, setRegion] = useStickyState<string>("ibm_region", "us-east");
  const [bearer, setBearer] = useState<string>("");
  const [loadingToken, setLoadingToken] = useState(false);

  const [jobsPending, setJobsPending] = useState<IBMJob[]>([]);
  const [jobsDone, setJobsDone] = useState<IBMJob[]>([]);
  const [backends, setBackends] = useState<BackendSummary[]>([]);
  const [pollMs, setPollMs] = useStickyState<number>("poll_ms", 15000);
  const [filterQuery, setFilterQuery] = useState("");
  const [backendFilter, setBackendFilter] = useState<string>("all");
  const [programFilter, setProgramFilter] = useState<string>("all");
  const timerRef = useRef<number | null>(null);

  const apiBase = "https://quantum.cloud.ibm.com/api/v1";

  const filteredPending = useMemo(() => {
    const q = filterQuery.trim().toLowerCase();
    return jobsPending.filter((j) =>
      (backendFilter === "all" || j.backend === backendFilter) &&
      (programFilter === "all" || j.program?.id === programFilter) &&
      (!q || j.id.toLowerCase().includes(q) || j.backend.toLowerCase().includes(q) || j.program?.id?.toLowerCase().includes(q))
    );
  }, [jobsPending, filterQuery, backendFilter, programFilter]);

  const filteredDone = useMemo(() => {
    const q = filterQuery.trim().toLowerCase();
    return jobsDone.filter((j) =>
      (backendFilter === "all" || j.backend === backendFilter) &&
      (programFilter === "all" || j.program?.id === programFilter) &&
      (!q || j.id.toLowerCase().includes(q) || j.backend.toLowerCase().includes(q) || j.program?.id?.toLowerCase().includes(q))
    );
  }, [jobsDone, filterQuery, backendFilter, programFilter]);

  const pendingByBackend = useMemo(() => {
    const map: Record<string, number> = {};
    jobsPending.forEach((j) => { map[j.backend] = (map[j.backend] || 0) + 1; });
    return Object.entries(map).map(([name, count]) => ({ name, count }));
  }, [jobsPending]);

  async function getBearer() {
    if (!apiKey) throw new Error("Enter your IBM Cloud API key");
    setLoadingToken(true);
    try {
      const body = new URLSearchParams({
        grant_type: "urn:ibm:params:oauth:grant-type:apikey",
        apikey: apiKey,
      });
      const res = await fetch("https://iam.cloud.ibm.com/identity/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body,
      });
      if (!res.ok) throw new Error(`IAM token error: ${res.status}`);
      const json = await res.json();
      setBearer(json.access_token);
      return json.access_token as string;
    } finally {
      setLoadingToken(false);
    }
  }

  async function ibmFetch(path: string, init?: RequestInit) {
    if (!bearer) await getBearer();
    const token = bearer || (await getBearer());
    const headers: HeadersInit = {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
      ...(instanceCrn ? { "Service-CRN": instanceCrn } : {}),
      ...init?.headers,
    };
    const res = await fetch(`${apiBase}${path}`, { ...init, headers });
    if (!res.ok) throw new Error(`${path} → ${res.status}`);
    return res.json();
  }

  async function loadJobs() {
    try {
      // Pending (Queued + Running)
      const pending: JobsResponse = await ibmFetch(`/jobs?pending=true&limit=200&sort=DESC`);
      // Completed, etc. (recent window)
      const done: JobsResponse = await ibmFetch(`/jobs?pending=false&limit=200&sort=DESC`);
      setJobsPending(pending.jobs || []);
      setJobsDone(done.jobs || []);
    } catch (e) {
      console.error(e);
    }
  }

  async function loadBackends() {
    try {
      const list = await ibmFetch(`/backends`);
      // list may be an array of names/objects depending on plan; fetch status per backend best-effort
      const names: string[] = (Array.isArray(list) ? list : list.backends || []).map((b: any) => (typeof b === "string" ? b : b.name)).filter(Boolean);
      const first = names.slice(0, 24); // constrain calls
      const statuses: BackendSummary[] = [];
      for (const name of first) {
        try {
          const s = await ibmFetch(`/backends/${encodeURIComponent(name)}/status`);
          statuses.push({ name, pending_jobs: s?.pending_jobs, operational: s?.operational });
        } catch {
          statuses.push({ name });
        }
      }
      setBackends(statuses);
    } catch (e) {
      console.error(e);
    }
  }

  function startPolling() {
    stopPolling();
    timerRef.current = window.setInterval(() => {
      loadJobs();
    }, Math.max(5000, pollMs));
  }
  function stopPolling() {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }

  useEffect(() => {
    if (apiKey && instanceCrn) {
      getBearer().then(() => {
        loadJobs();
        loadBackends();
        startPolling();
      });
    }
    return stopPolling;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const allBackends = useMemo(() => {
    const set = new Set<string>();
    [...jobsPending, ...jobsDone].forEach((j) => set.add(j.backend));
    backends.forEach((b) => set.add(b.name));
    return ["all", ...Array.from(set).sort()];
  }, [jobsPending, jobsDone, backends]);

  const allPrograms = useMemo(() => {
    const set = new Set<string>();
    [...jobsPending, ...jobsDone].forEach((j) => j.program?.id && set.add(j.program.id));
    return ["all", ...Array.from(set).sort()];
  }, [jobsPending, jobsDone]);

  const queueChartData = useMemo(() => {
    return backends
      .filter((b) => typeof b.pending_jobs === "number")
      .sort((a, b) => (b.pending_jobs || 0) - (a.pending_jobs || 0))
      .slice(0, 12)
      .map((b) => ({ name: b.name, count: b.pending_jobs! }));
  }, [backends]);

  const statusBadge = (s?: string) => {
    const label = s || "Unknown";
    const tone =
      label.startsWith("Run") ? "bg-emerald-600" :
      label.startsWith("Que") ? "bg-amber-600" :
      label.startsWith("Comp") ? "bg-sky-600" :
      label.startsWith("Fail") ? "bg-rose-600" :
      label.startsWith("Canc") ? "bg-slate-500" : "bg-zinc-600";
    return <Badge className={cls("text-white", tone)}>{label}</Badge>;
  };

  return (
    <div className="min-h-screen w-full bg-neutral-950 text-neutral-50 p-6">
      <div className="mx-auto max-w-7xl space-y-6">
        <motion.div initial={{ opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">IBM Quantum – Live Jobs Dashboard</h1>
            <p className="text-neutral-400">Monitor queued & running jobs in real time, plus recent results. Paste your IBM Cloud API key and Service CRN to begin.</p>
          </div>
          <div className="flex gap-2">
            <Button variant="secondary" onClick={() => { loadJobs(); }} title="Refresh jobs">
              <RefreshCw className="mr-2 h-4 w-4" /> Refresh
            </Button>
          </div>
        </motion.div>

        {/* Auth + Controls */}
        <Card className="bg-neutral-900 border-neutral-800">
          <CardHeader>
            <CardTitle className="flex items-center gap-2"><Shield className="h-5 w-5" /> Credentials</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid md:grid-cols-2 gap-3">
              <div>
                <label className="text-sm text-neutral-400">IBM Cloud API key</label>
                <Input type="password" placeholder="ibmcloud API key" value={apiKey} onChange={(e) => setApiKey(e.target.value)} />
              </div>
              <div>
                <label className="text-sm text-neutral-400">Service CRN (instance)</label>
                <Input placeholder="crn:v1:bluemix:public:quantum-computing:...:instance:..." value={instanceCrn} onChange={(e) => setInstanceCrn(e.target.value)} />
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <Button onClick={() => getBearer()} disabled={!apiKey || !instanceCrn || loadingToken}>
                {loadingToken ? <Loader2 className="mr-2 h-4 w-4 animate-spin"/> : <Bolt className="mr-2 h-4 w-4"/>}
                Get token
              </Button>
              {bearer && <Badge className="bg-emerald-600">Token ready</Badge>}
              <TooltipProvider>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Badge variant="outline" className="border-neutral-700 text-neutral-300"><Database className="h-3 w-3 mr-1"/> {region}</Badge>
                  </TooltipTrigger>
                  <TooltipContent>Tokens expire in ~1 hour. The dashboard will re-request as needed.</TooltipContent>
                </Tooltip>
              </TooltipProvider>
              <div className="ml-auto flex items-center gap-2">
                <div className="relative">
                  <Search className="h-4 w-4 absolute left-2 top-2.5 text-neutral-500" />
                  <Input className="pl-8 w-56" placeholder="Filter by id/backend/program" value={filterQuery} onChange={(e) => setFilterQuery(e.target.value)} />
                </div>
                <Select value={backendFilter} onValueChange={setBackendFilter}>
                  <SelectTrigger className="w-[180px]"><SelectValue placeholder="Backend"/></SelectTrigger>
                  <SelectContent>
                    {allBackends.map((b) => (<SelectItem key={b} value={b}>{b}</SelectItem>))}
                  </SelectContent>
                </Select>
                <Select value={programFilter} onValueChange={setProgramFilter}>
                  <SelectTrigger className="w-[200px]"><SelectValue placeholder="Program"/></SelectTrigger>
                  <SelectContent>
                    {allPrograms.map((p) => (<SelectItem key={p} value={p}>{p}</SelectItem>))}
                  </SelectContent>
                </Select>
                <Select value={String(pollMs)} onValueChange={(v) => setPollMs(parseInt(v))}>
                  <SelectTrigger className="w-[150px]"><SelectValue placeholder="Polling"/></SelectTrigger>
                  <SelectContent>
                    {[[5000,"5s"],[10000,"10s"],[15000,"15s"],[30000,"30s"],[60000,"60s"]].map(([v,l]) => (
                      <SelectItem key={v as number} value={String(v)}>{l}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Button variant="outline" onClick={() => { stopPolling(); startPolling(); }}><Clock className="h-4 w-4 mr-2"/>Apply interval</Button>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Overview */}
        <div className="grid md:grid-cols-3 gap-4">
          <Card className="bg-neutral-900 border-neutral-800">
            <CardHeader><CardTitle>Total Pending</CardTitle></CardHeader>
            <CardContent className="text-3xl font-semibold">{filteredPending.length}</CardContent>
          </Card>
          <Card className="bg-neutral-900 border-neutral-800">
            <CardHeader><CardTitle>Completed (recent)</CardTitle></CardHeader>
            <CardContent className="text-3xl font-semibold">{filteredDone.length}</CardContent>
          </Card>
          <Card className="bg-neutral-900 border-neutral-800">
            <CardHeader className="flex flex-row items-center justify-between"><CardTitle>Queues by backend</CardTitle><Terminal className="h-4 w-4 text-neutral-400"/></CardHeader>
            <CardContent className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={queueChartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" hide={false} tick={{ fontSize: 12 }} interval={0} angle={-30} textAnchor="end" height={60} />
                  <YAxis />
                  <ReTooltip />
                  <Bar dataKey="count" />
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </div>

        <Tabs defaultValue="pending" className="w-full">
          <TabsList>
            <TabsTrigger value="pending">Pending (Queued/Running)</TabsTrigger>
            <TabsTrigger value="done">Completed/Other</TabsTrigger>
          </TabsList>
          <TabsContent value="pending" className="space-y-3">
            {filteredPending.length === 0 ? (
              <EmptyState text="No pending jobs found. Submit or widen filters."/>
            ) : (
              <JobsTable jobs={filteredPending} />
            )}
          </TabsContent>
          <TabsContent value="done" className="space-y-3">
            {filteredDone.length === 0 ? (
              <EmptyState text="No recent completed jobs found."/>
            ) : (
              <JobsTable jobs={filteredDone} />
            )}
          </TabsContent>
        </Tabs>

        <Card className="bg-neutral-900 border-neutral-800">
          <CardHeader>
            <CardTitle className="flex items-center gap-2"><Eye className="h-5 w-5"/> Backend status (sample)</CardTitle>
          </CardHeader>
          <CardContent className="grid md:grid-cols-2 lg:grid-cols-3 gap-3">
            {backends.map((b) => (
              <div key={b.name} className="flex items-center justify-between bg-neutral-950 border border-neutral-800 rounded-2xl p-3">
                <div>
                  <div className="font-medium">{b.name}</div>
                  <div className="text-sm text-neutral-400">{typeof b.pending_jobs === "number" ? `${b.pending_jobs} pending` : "pending unknown"}</div>
                </div>
                <div>
                  {b.operational ? <Badge className="bg-emerald-600">Operational</Badge> : <Badge className="bg-rose-600">Down</Badge>}
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        <div className="text-xs text-neutral-500 flex items-center gap-2">
          <AlertCircle className="h-3.5 w-3.5"/>
          This dashboard reads only your account's jobs. IBM Quantum does not expose other users' jobs publicly. Use instance CRN like <code>ibm-q/open/main</code> (Service-CRN header) associated with your account/plan.
        </div>
      </div>
    </div>
  );
}

function EmptyState({ text }: { text: string }) {
  return (
    <div className="border border-neutral-800 bg-neutral-900 rounded-2xl p-8 text-center">
      <p className="text-neutral-300">{text}</p>
    </div>
  );
}

function JobsTable({ jobs }: { jobs: IBMJob[] }) {
  return (
    <div className="overflow-auto">
      <table className="min-w-full text-sm">
        <thead>
          <tr className="text-left text-neutral-400 border-b border-neutral-800">
            <th className="py-2 pr-4">ID</th>
            <th className="py-2 pr-4">Status</th>
            <th className="py-2 pr-4">Backend</th>
            <th className="py-2 pr-4">Program</th>
            <th className="py-2 pr-4">Created</th>
            <th className="py-2 pr-4">Usage (s)</th>
            <th className="py-2 pr-4">Tags</th>
            <th className="py-2 pr-4">Session</th>
            <th className="py-2 pr-4">Actions</th>
          </tr>
        </thead>
        <tbody>
          {jobs.map((j) => (
            <tr key={j.id} className="border-b border-neutral-900 hover:bg-neutral-900/60">
              <td className="py-2 pr-4 font-mono text-xs">{j.id}</td>
              <td className="py-2 pr-4">
                <Badge className="bg-neutral-700">
                  {(j.status || j.state?.status || "").toString()}
                </Badge>
              </td>
              <td className="py-2 pr-4">{j.backend}</td>
              <td className="py-2 pr-4">{j.program?.id || "—"}</td>
              <td className="py-2 pr-4">{fmtTime(j.created)}</td>
              <td className="py-2 pr-4">{j.usage?.seconds ?? "—"}</td>
              <td className="py-2 pr-4">{j.tags?.length ? j.tags.join(", ") : "—"}</td>
              <td className="py-2 pr-4">{j.session_id || "—"}</td>
              <td className="py-2 pr-4 flex gap-2">
                <a className="text-sky-400 hover:underline" href={`https://quantum-computing.ibm.com/jobs/${j.id}`} target="_blank" rel="noreferrer">View</a>
                <a className="text-neutral-400 hover:underline" href={`https://quantum.cloud.ibm.com/api/v1/jobs/${j.id}`} target="_blank" rel="noreferrer">API</a>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
