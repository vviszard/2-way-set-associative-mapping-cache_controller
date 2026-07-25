# 2-Way Set-Associative Cache Controller

A fully functional 2-way set-associative cache controller implemented in Verilog RTL, simulated using ModelSim Intel FPGA Edition. Features LRU (Least Recently Used) replacement policy with write-back and dirty bit handling.

Built as part of the NPTEL course — Computer Architecture and Organisation by Prof. Indranil Sengupta, IIT Kharagpur.

> **Prerequisite:** [Direct Mapped Cache Controller](https://github.com/vviszard/direct-mapping-cache_controller) — build that first before studying this one. This design extends direct mapping with sets, ways, and LRU.

---

## Cache Specifications

| Parameter | Value |
|---|---|
| Cache Size | 1 KB |
| Block Size | 16 bytes (128 bits) |
| Number of Sets | 32 |
| Ways per Set | 2 |
| Total Cache Lines | 64 (32 sets × 2 ways) |
| Address Width | 32 bits |
| Mapping Policy | 2-Way Set-Associative |
| Write Policy | Write-back with dirty bit |
| Replacement Policy | LRU (1 bit per set) |
| Word Size | 32 bits (4 words per block) |

---

## Address Breakdown

```
| TAG (23 bits) | SET INDEX (5 bits) | OFFSET (4 bits) |
  addr[31:9]      addr[8:4]            addr[3:0]
```

Compared to direct mapped:
```
Direct Mapped:      TAG (22 bits) | INDEX (6 bits) | OFFSET (4 bits)
2-Way Set-Assoc:    TAG (23 bits) | INDEX (5 bits) | OFFSET (4 bits)
```

The index shrank by 1 bit because the number of sets halved (64 lines → 32 sets). The tag grew by 1 bit to compensate.

---

## Key Concept — What Changed From Direct Mapped

In direct mapped, every memory block maps to **exactly one cache line**. On a miss there is no choice — you always overwrite that one line.

In 2-way set-associative, every memory block maps to **exactly one set**, but can occupy **either way** within that set. This gives flexibility and reduces conflict misses.

```
Direct Mapped:
  addr → one specific line → always overwrite it

2-Way Set-Associative:
  addr → one specific set → two ways available
                          → on miss: evict LRU way
                          → on hit:  use whichever way matched
```

---

## LRU Replacement Policy

For 2-way, LRU is implemented with **1 bit per set:**

```
lru[set] = 0 → way 0 is Least Recently Used → evict way 0 on miss
lru[set] = 1 → way 1 is Least Recently Used → evict way 1 on miss
```

Update rule — after every access, point LRU away from the accessed way:

```
access way 0 → lru[set] <= 1  (way 1 is now LRU)
access way 1 → lru[set] <= 0  (way 0 is now LRU)
```

Simplified: `lru[set] <= ~accessed_way`

After reset, lru=0 for all sets → first miss always fills way 0, second fills way 1, then LRU kicks in from the third miss onwards.

---

## Architecture

Three modules with clear separation of responsibilities:

```
two_way_cache_top_module.v     (top level — connects everything)
├── cache_array.v              (dumb storage — 2D arrays + LRU + hit logic)
└── cache_controller.v         (FSM brain — same 4 states as direct mapped)
```

### Module Descriptions

**cache_array.v** — Storage module. Holds 2D arrays (2 ways × 32 sets) for valid, tag, data, and dirty. Also holds 1D LRU array (32 sets). Computes hit_way0, hit_way1, hit, hit_way, evict_way combinationally. Updates LRU on every access — store_in, wr_hit, and rd_hit all trigger LRU updates.

**cache_controller.v** — Moore FSM with four states. Identical state transitions to direct mapped. Only difference is Block 3 now asserts rd_hit on read hits (in addition to wr_hit on write hits) so the array can update LRU correctly.

**two_way_cache_top_module.v** — Top level wrapper. Instantiates and connects both submodules. Adds rd_hit wire. Word extraction logic identical to direct mapped.

---

## New Signals vs Direct Mapped

| Signal | Direction | Description |
|---|---|---|
| rd_hit | Controller → Array | Pulses high on read hit so array can update LRU |
| hit_way | Internal wire | Which way (0 or 1) contains the hit data |
| evict_way | Internal wire | Which way to evict on miss (= lru[index]) |

All other signals identical to direct mapped.

---

## FSM State Diagram

FSM is identical to direct mapped — same four states, same transitions:

```
            proc_req=0
  ┌──────────────────────────────┐
  ▼                              │
[IDLE] ──proc_req=1──► [COMPARE] ───hit=1──► IDLE
                           │
                         hit=0
                           │
                           ▼
[UPDATE] ◄─mem_ready=1─ [FETCH]
    │                      │
    │                 mem_ready=0
    └──────────────► COMPARE
```

| State | Active Signals | Description |
|---|---|---|
| IDLE | none | Waiting for processor request |
| COMPARE | proc_stall | Check valid+tag for both ways simultaneously. Hit → assert rd_hit or wr_hit, release stall. Miss → go FETCH. |
| FETCH | proc_stall, mem_req, mem_addr | Request block from main memory. Wait for mem_ready. |
| UPDATE | proc_stall, store_in, (mem_wr if dirty) | Write new block into evict_way. Writeback dirty line if needed. |

---

## Internal Array Structure

```
// 2D arrays — [way][set]
reg         valid_arr [1:0][31:0];   // 2 ways, 32 sets, 1 bit each
reg         dirty_arr [1:0][31:0];   // 2 ways, 32 sets, 1 bit each
reg [22:0]  tag_arr   [1:0][31:0];   // 2 ways, 32 sets, 23 bits each
reg [127:0] data_arr  [1:0][31:0];   // 2 ways, 32 sets, 128 bits each

// LRU — 1D array, one bit per set
reg lru [31:0];                      // 32 sets, 1 bit each
```

---

## Hit Logic (Combinational)

```verilog
// check both ways simultaneously — parallel comparison
assign hit_way0 = valid_arr[0][index_in] & (tag_arr[0][index_in] == tag_in);
assign hit_way1 = valid_arr[1][index_in] & (tag_arr[1][index_in] == tag_in);

assign hit      = hit_way0 | hit_way1;   // hit if either way matches
assign hit_way  = hit_way1;              // 0=way0 hit, 1=way1 hit
assign evict_way = lru[index_in];        // LRU points to way to evict
assign dirty    = dirty_arr[evict_way][index_in]; // dirty of evict way
```

---

## LRU Update Logic (Sequential)

```verilog
// on store_in: new block loaded into evict_way
lru[index_in] <= ~evict_way;  // other way is now LRU

// on wr_hit: processor wrote to hit_way
lru[index_in] <= ~hit_way;    // other way is now LRU

// on rd_hit: processor read from hit_way
lru[index_in] <= ~hit_way;    // other way is now LRU
```

---

## All Four Access Cases

```
Read  + Hit  → one cycle, rd_hit pulses, LRU updates, data served
Read  + Miss → FETCH → UPDATE(store in evict_way) → COMPARE(hit) → data served
Write + Hit  → one cycle, wr_hit pulses, word updated, dirty=1, LRU updates
Write + Miss → FETCH → UPDATE(store in evict_way) → COMPARE(wr_hit) → word updated
```

---

## Simulation Results

### ModelSim Interface
![ModelSim Interface](https://raw.githubusercontent.com/vviszard/2-way-set-associative-mapping-cache_controller/main/reports/modelsim_interface.png)

### Simulation Waveform
![Simulation Waveform](https://raw.githubusercontent.com/vviszard/2-way-set-associative-mapping-cache_controller/main/reports/simulation_waveform.png)

### Transcript Output
![Transcript Output](https://raw.githubusercontent.com/vviszard/2-way-set-associative-mapping-cache_controller/main/reports/transcript_output.png)

### Test Cases

| Test | Address | Operation | Expected | Result |
|---|---|---|---|---|
| 1 | 0x00000013 | Read Miss | FETCH, serve data | ✓ Pass |
| 2 | 0x00000013 | Read Hit | Immediate hit, no stall | ✓ Pass |
| 3 | 0x00000013 | Write Hit | Update word, dirty=1, LRU updates | ✓ Pass |
| 4 | 0x00001234 | Write Miss | Fetch block, write word | ✓ Pass |
| 5 | 0x0000FC10 | Miss, different set | Fetch, serve data | ✓ Pass |
| 6a | 0xABCDE1D0 | Miss 1, set 29 | Fills way 0 | ✓ Pass |
| 6b | 0xF12453D0 | Miss 2, set 29 | Fills way 1 | ✓ Pass |
| 6c | 0xB00C51D0 | Miss 3, set 29 | Evicts way 0 (LRU) | ✓ Pass |
| 6d | 0xF12453D0 | Read, set 29 | Hit — way 1 kept (MRU) | ✓ Pass |
| 6e | 0xABCDE1D0 | Read, set 29 | Miss — way 0 evicted (LRU) | ✓ Pass |

**LRU proof — Test 6d and 6e confirm LRU is working correctly.**

---

## How to Simulate (ModelSim)

### Requirements
- [ModelSim Intel FPGA Starter Edition](https://www.intel.com/content/www/us/en/software-kit/750666/modelsim-intel-fpga-starter-edition-software.html) — free

### Steps

```tcl
# 1. Open ModelSim and navigate to project folder
cd D:/path/to/2-way-set-associative-mapping-cache_controller

# 2. Create work library
vlib work

# 3. Compile source files
vlog src/cache_array.v
vlog src/cache_controller.v
vlog src/two_way_cache_top_module.v

# 4. Compile testbench
vlog testbench/two_way_cache_tb.v

# 5. Load simulation
vsim two_way_cache_tb

# 6. Add waveforms
add wave *
add wave dut/*
add wave dut/c_array/*
add wave dut/c_controller/*

# 7. Run simulation
run -all
```

### One-command run (save as run.do)

Create `run.do` in project root:

```tcl
vlib work
vlog src/cache_array.v
vlog src/cache_controller.v
vlog src/two_way_cache_top_module.v
vlog testbench/two_way_cache_tb.v
vsim two_way_cache_tb
add wave *
add wave dut/*
add wave dut/c_array/*
add wave dut/c_controller/*
run -all
```

Then just type:
```tcl
do run.do
```

### Recompile after edits

```tcl
vlog src/cache_array.v
vsim two_way_cache_tb
run -all
```

---

## Repository Structure

```
2-way-set-associative-mapping-cache_controller/
├── src/
│   ├── cache_array.v              — 2D storage arrays, LRU, hit logic
│   ├── cache_controller.v         — Moore FSM controller
│   └── two_way_cache_top_module.v — top level module
├── testbench/
│   └── two_way_cache_tb.v         — 10 test cases including LRU verification
├── reports/
│   ├── modelsim_interface.png     — ModelSim GUI screenshot
│   ├── simulation_waveform.png    — waveform output
│   └── transcript_output.png     — $monitor output
├── .gitignore
└── README.md
```

---

## Key RTL Concepts Demonstrated

- **2D array indexing** — `reg [22:0] tag_arr [1:0][31:0]` for way×set storage
- **Parallel tag comparison** — both ways checked simultaneously in combinational logic
- **1-bit LRU** — single bit per set, updated on every cache access
- **Three LRU update events** — store_in, wr_hit, rd_hit all update LRU
- **hit_way signal** — selects correct way for data output on hit
- **evict_way signal** — LRU bit directly selects way to evict on miss
- **Moore FSM design** — three always block style
- **Latch prevention** — default-then-override pattern
- **Write-back with dirty bit** — dirty eviction handled in UPDATE state

---

## Useful Concepts

**Address field sizing — why index shrank by 1 bit**

Moving from direct mapped to 2-way set-associative halves the number of addressable units — from 64 lines to 32 sets. Since index bits = log2(number of sets), this drops from 6 to 5 bits. The tag picks up that freed bit, growing from 22 to 23 bits. General rule: every time you double the associativity, you lose one index bit and gain one tag bit.

**LRU bit — two implementation choices**

There are two ways to implement the 1-bit LRU:

*Method A — track MRU (most recently used):*
Update is simple — write accessed way directly: `lru <= accessed_way`. But eviction needs an inverter: `evict_way = ~lru_bit`. The NOT gate sits on the miss critical path, which is the worst place for extra delay.

*Method B — track LRU (least recently used):*
Update needs an inverter: `lru <= ~accessed_way`. But eviction is direct: `evict_way = lru_bit` — zero extra gates on the critical path. Since cache misses are the timing-critical event, this is the better hardware choice.

**This project uses Method B.** On a miss the victim way is read directly from the LRU register with no extra logic — faster eviction, cleaner critical path. The extra NOT gate on the update side is acceptable since hits are far more frequent than misses and the update path is not timing-critical.

Power note — Method A saves a tiny amount of dynamic power on hits by avoiding the inversion before writing to the register. For ultra low-power designs this tradeoff can flip the decision.

**The +: indexed part-select operator**

Standard Verilog slice notation `[high:low]` requires both bounds to be constants. When the start position is a variable — like when you're selecting a word using the offset bits — you need `+:`:

```verilog
data[offset[3:2]*32 +: 32]
// means: start at bit (offset[3:2]*32), take 32 bits upward
```

The left operand is the variable start position, the right operand is the fixed width. This is synthesisable and maps directly to a multiplexer in hardware.

**Why rd_hit is a separate signal**

LRU must update on read hits, write hits, and store operations — any time a way is accessed. Write hits and stores happen inside the clocked always block naturally. But read data output is combinational (`always @(*)`) — you cannot update a register there without inferring a latch. The solution is a dedicated `rd_hit` pulse from the controller, which the sequential block uses to trigger the LRU update on read hits.

**evict_way vs hit_way for dirty check**

On a miss, the dirty signal must reflect the line you are about to evict, not the line you are searching for. The searched line is not in cache (it missed), so hit_way is meaningless. evict_way, pointed to by the LRU bit, is the correct source for the dirty check. This is why `assign dirty = dirty_arr[evict_way][index_in]` and not `dirty_arr[hit_way][index_in]`.

**Cold start and LRU initialisation**

After reset, lru=0 for all sets. This means evict_way=0 for every set on first access. The first miss to any set fills way 0, the second miss fills way 1, and from the third miss onwards true LRU eviction operates. No special cold start logic is needed — the reset value handles it automatically and correctly.

---

## Roadmap

- [x] Direct mapped cache controller
- [x] 2-way set-associative cache with LRU replacement
- [ ] N-way parameterised set-associative cache
- [ ] FPGA implementation on Xilinx board using BRAM
- [ ] Pipelined processor with cache integration

---

## References

- NPTEL — Computer Architecture and Organisation, Prof. Indranil Sengupta, IIT Kharagpur
- Patterson and Hennessy — Computer Organisation and Design
