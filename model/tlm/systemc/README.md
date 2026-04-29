# packet_scheduler SystemC TLM

This directory is the SystemC landing area for the structural OPQ/time-merger
TLM. The intent is to keep the first model transaction-level but RTL-shaped:
explicit hit identity, FIFOs, credits, arbiters, allocation, merger-stage
queues, and ordered delivery.

The Python structural TLM remains the fast reference while this path is brought
up. The SystemC target should first match the Python TLM standalone, then run
under Questa mixed simulation with RTL modules for packet/hit identity checks.

Evidence rules:

- preserve hit metadata from generation through drop or delivery;
- classify loss as controlled, asserted, inferred, or mixed;
- keep delivered hit ordering exact even when cycle timing is approximate;
- use mixed SystemC+RTL only after the standalone SystemC model matches the
  same CSV cases as the Python model.

Run the local smoke check with:

```sh
make -C packet_scheduler/model/tlm/systemc smoke
```

Current QuestaOne status on this host:

- `sccom`, SystemC headers, and SystemC libraries are installed.
- `sccom` needs the local `/usr/bin/g++` plus a generated predefined-macro
  file because the bundled supported GCC package is not installed.
- Compile and link complete with `-nodebug`, but mixed elaboration is still
  `DEBUG`: `vsim/vopt` does not yet find the exported SystemC `top`. Treat this
  as tool bring-up work before relying on mixed SystemC+RTL evidence.
