# Subagent Flow Troubleshooting Report

**Date:** 2026-08-17 · **Env:** pi subagents + LM Studio (local, `http://localhost:1234/v1`)
**Task attempted:** delegate "streaming sourced items" implementation to `worker` subagent on the small model `qwen/qwen3.5-9b`, then a `reviewer` pass.

## Outcome
Subagent execution is unusable in this environment. Per plan, the main agent implemented the feature directly.

## Attempts & evidence

### Attempt 1 & 2 — child model `qwen/qwen3.5-9b` (also tried with `lmstudio/` prefix)
Both failed identically, before the child produced any output:

```
400: {"message":"Failed to load model \"qwen/qwen3.5-9b\". Error: Operation canceled.","type":"invalid_request_error","param":"model"}
```

Artifacts: `subagent-artifacts/8583eb31_worker_0_output.md`, `subagent-artifacts/62b53291_worker_0_output.md`
("Subagent run failed before producing output.")

**Root cause (confirmed via LM Studio API):** `curl http://localhost:1234/api/v0/models` shows
`qwen/qwen3.8-27b → state: "loaded"` (the model the parent session is running) and
`qwen/qwen3.5-9b → state: "not-loaded"`. LM Studio serves **one model at a time**; loading the
9b would have to evict the 27b that the live parent session depends on, so the load operation is
canceled and the provider returns 400. The model-ID format was *not* the problem (the error
strips the provider prefix and is a load failure, not an unknown-model error).

### Attempt 3 (control) — child inherits parent model `lmstudio/qwen/qwen3.8-27b`, trivial task
No model-load error, but the child never completed a single inference:

```
meta:  exitCode 143 (SIGTERM on timeout), usage {input:0, output:0, turns:0}, timeoutMs 120000
transcript: initial_prompt recorded, then nothing until kill
```

Artifacts: `subagent-artifacts/522a5389_worker_0_*`

**Interpretation:** while the parent session is holding the local model, a concurrent child
request stalls (serialized/never served) — 0 tokens in 120s. Even with the "right" model, the
child cannot get an inference to complete.

## Conclusion
With a single local model serving both parent and children, subagent fan-out in this setup
fails in two independent ways: (a) different model → load canceled (400), (b) same model →
child inference starves (hang until timeout).

## Workarounds / recommendations
1. **Run the small model standalone:** stop the parent session, load `qwen/qwen3.5-9b` in
   LM Studio, then start the pi session on it (subagent children inherit a loaded model).
2. **Two LM Studio servers on different ports** (one per model), with the subagent model
   configured against the second endpoint.
3. **Use a remote API model** (e.g. Anthropic) for the parent or for subagent children —
   no local single-model contention.
4. Raise `timeoutMs` alone would **not** fix attempt 3's stall class; the issue is model
   availability, not duration.
