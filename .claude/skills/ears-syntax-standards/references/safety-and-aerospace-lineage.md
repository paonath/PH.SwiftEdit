# Aerospace Lineage: DO-178C, FADEC, and AI Spec-Driven Engineering

## Origins in Jet Engine Control
EARS was created by Alistair Mavin and colleagues at Rolls-Royce PLC while developing requirements for the Full Authority Digital Engine Control (FADEC). FADEC is dual-channel, operates without mechanical backup, and requires strict certification under FAA/EASA **DO-178C**.

## DO-178C Core Principles
1. **Traceability**: Every requirement traces to design and code; every line of code traces to a requirement. Dead code is eliminated.
2. **Determinism**: Ambiguity is intolerable when physical safety is at stake.
3. **Proof Before Completion**: Testing verifies requirements, and requirements guide test generation.

## Application to AI Coding Agents
In modern software engineering, coding agents (LLMs) tend to hallucinate or fill gaps with "common sense" when requirements are vague. EARS provides the exact level of syntactic constraint needed to anchor AI generation to verifiable facts.
