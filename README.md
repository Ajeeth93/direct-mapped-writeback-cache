# Direct-Mapped Write-Back Cache — SystemVerilog RTL

A **32-bit direct-mapped write-back cache** designed and implemented in **SystemVerilog RTL**, based on the memory hierarchy concepts presented in *Computer Organization and Design: The Hardware/Software Interface, RISC-V Edition* by **David A. Patterson and John L. Hennessy**.

The project implements a **16 KiB cache with 1024 cache lines and 128-bit (16-byte) cache blocks**, including tag storage, valid and dirty bits, cache hit/miss detection, cache-line allocation, and write-back handling through an FSM-based controller.

The primary goal of this project is to demonstrate practical skills in **RTL design, SystemVerilog, computer architecture, memory systems, finite-state machines, and hardware verification**.

---

## Architecture Specifications

| Parameter | Specification |
| --- | --- |
| Address Width | **32 bits** |
| Addressing | **Byte-addressable** |
| Cache Organization | **Direct-Mapped** |
| Number of Cache Lines | **1024** |
| Cache Line Size | **128 bits / 16 bytes** |
| Total Data Capacity | **16 KiB** |
| Write Policy | **Write-Back** |
| Allocation | **Write-Allocate** |
| Tag Width | **18 bits** |
| Index Width | **10 bits** |
| Block Offset | **4 bits** |
| RTL Language | **SystemVerilog** |

Cache Capacity
1024 cache lines × 128 bits per line
= 131,072 bits
= 16,384 bytes
= 16 KiB
Address Decomposition

For a 32-bit byte address and a 128-bit cache line:

128 bits = 16 bytes = 2^4 bytes
1024 lines = 2^10 lines

Therefore:

Byte Offset = 4 bits
Index       = 10 bits
Tag         = 18 bits
Address Format

31                  14 13           4 3           0
┌─────────────────────┬──────────────┬──────────────┐
│         TAG         │    INDEX     │ BYTE OFFSET  │
│       18 bits       │   10 bits    │    4 bits    │
└─────────────────────┴──────────────┴──────────────┘
Address Fields
Tag [31:14]

The 18-bit tag identifies which memory block is currently stored in the selected cache line.

Index [13:4]

The 10-bit index selects one of the 1024 cache lines.

Byte Offset [3:0]

The 4-bit byte offset selects a byte within the 16-byte cache line.

Cache Organization

The cache contains three primary storage structures:

Data Array — stores the 128-bit cache-line data.
Tag/Metadata Array — stores the tag, valid bit, and dirty bit.
Cache Controller — controls cache hits, misses, write-backs, and memory operations using an FSM.
Cache Architecture
                           32-bit Address
                                │
                                ▼
                     ┌─────────────────────┐
                     │   Address Decoder   │
                     └──────────┬──────────┘
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
          ┌──────────┐    ┌──────────┐    ┌──────────┐
          │   TAG    │    │  INDEX   │    │  OFFSET  │
          │ 18 bits  │    │ 10 bits  │    │  4 bits  │
          └────┬─────┘    └────┬─────┘    └────┬─────┘
               │               │               │
               │               ▼               │
               │       ┌────────────────┐      │
               │       │   Cache Line   │      │
               │       │    0 - 1023    │      │
               │       └───────┬────────┘      │
               │               │               │
               ▼               ▼               ▼
        ┌────────────────────────────────────────────┐
        │             Cache Metadata                 │
        │                                            │
        │             Tag + Valid + Dirty            │
        └─────────────────────┬──────────────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │ Tag Compare  │
                       └──────┬───────┘
                              │
                         Hit / Miss
                              │
                              ▼
                    ┌───────────────────┐
                    │ Cache Controller  │
                    │       FSM         │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │   128-bit Data    │
                    │      Array        │
                    └─────────┬─────────┘
                              │
                              ▼
                         CPU / Memory
Cache Parameters
Parameter	Value
Address Width	32 bits
Cache Capacity	16 KiB
Number of Cache Lines	1024
Cache Line Size	128 bits
Cache Line Size	16 bytes
Tag Width	18 bits
Index Width	10 bits
Byte Offset Width	4 bits
Cache Organization	Direct-Mapped
Write Policy	Write-Back
Cache Line Structure

Each cache line contains:

┌────────────────────────────────────────────────────┐
│                     DATA                           │
│                    128 bits                        │
└────────────────────────────────────────────────────┘

┌──────────────────┬─────────┬─────────┐
│       TAG        │  VALID  │  DIRTY  │
│     18 bits      │  1 bit  │  1 bit  │
└──────────────────┴─────────┴─────────┘

The data array stores the actual cache-line contents, while the metadata array stores the tag and status information.

Read Operation

For a CPU read request:

The CPU provides a 32-bit address.
The address is divided into tag, index, and byte offset.
The index selects one of the 1024 cache lines.
The stored tag is compared with the requested tag.
The valid bit is checked.
If the tag matches and the line is valid, a cache hit occurs.
The requested byte is selected using the byte offset.
Data is returned to the CPU.
CPU Read
   │
   ▼
32-bit Address
   │
   ▼
┌─────────────────────────┐
│ Tag / Index / Offset    │
└────────────┬────────────┘
             │
             ▼
       Select Cache Line
             │
             ▼
        Compare Tags
             │
       ┌─────┴─────┐
       │           │
      HIT         MISS
       │           │
       ▼           ▼
 Select Data    Cache FSM
       │           │
       ▼           ▼
      CPU       Memory Access
Write Operation

This cache uses a write-back policy.

When a write hits in the cache:

The cache line is selected using the index.
The tag is compared.
If the tag matches and the valid bit is set, a write hit occurs.
The cache data is updated.
The dirty bit is set to 1.
Main memory is not immediately updated.
CPU Write
    │
    ▼
Cache Line Selected
    │
    ▼
Tag Match?
    │
    ▼
   YES
    │
    ▼
Update Cache Data
    │
    ▼
Dirty Bit = 1
Write-Back Operation

When a dirty cache line must be replaced, the existing data must first be written back to main memory.

             Cache Miss
                 │
                 ▼
          Check Valid Bit
                 │
                 ▼
          Check Dirty Bit
                 │
        ┌────────┴────────┐
        │                 │
    Dirty = 0         Dirty = 1
        │                 │
        │                 ▼
        │          Write Cache Line
        │            to Memory
        │                 │
        └────────┬────────┘
                 ▼
          Fetch New Line
             from Memory
                 │
                 ▼
          Update Cache Line
                 │
                 ▼
           Complete Request
Cache Miss Handling

When a cache miss occurs, the controller performs the following operations:

1. Detect cache miss
2. Check existing cache line
3. Check valid bit
4. Check dirty bit
5. Write back old line if dirty
6. Read requested line from memory
7. Store new line in cache
8. Update tag
9. Set valid bit
10. Clear dirty bit
11. Complete CPU request
Cache Controller FSM

The cache controller manages the cache operations using a finite state machine.

A typical state sequence is:

                    ┌──────────────┐
                    │     IDLE     │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │  TAG CHECK   │
                    └──────┬───────┘
                           │
                  ┌────────┴────────┐
                  │                 │
                  ▼                 ▼
                HIT               MISS
                  │                 │
                  ▼                 ▼
            ┌───────────┐     ┌──────────────┐
            │ COMPLETE  │     │ CHECK DIRTY  │
            └───────────┘     └──────┬───────┘
                                     │
                            ┌────────┴────────┐
                            │                 │
                            ▼                 ▼
                         CLEAN             DIRTY
                            │                 │
                            │                 ▼
                            │          ┌─────────────┐
                            │          │  WRITEBACK  │
                            │          └──────┬──────┘
                            │                 │
                            └────────┬────────┘
                                     ▼
                              ┌─────────────┐
                              │    REFILL   │
                              └──────┬──────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │    UPDATE   │
                              │   METADATA  │
                              └──────┬──────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │  COMPLETE   │
                              └─────────────┘
RTL Modules

The RTL is divided into separate SystemVerilog modules to keep the design modular and easier to debug.

rtl/
├── cache_top.sv
├── cache_controller.sv
├── cache_data.sv
└── cache_tag.sv
cache_top.sv

Top-level module that connects the cache data array, tag/metadata array, controller, CPU interface, and memory interface.

cache_controller.sv

Implements the cache controller FSM and manages:

Cache hit detection
Cache miss handling
Write-back operations
Memory refill
Metadata updates
cache_data.sv

Implements the 128-bit × 1024 cache data storage.

cache_tag.sv

Implements the tag and metadata storage:

Tag   = 18 bits
Valid = 1 bit
Dirty = 1 bit
Design Summary
Cache Type       : Direct-Mapped
Capacity         : 16 KiB
Address Width    : 32 bits
Cache Lines      : 1024
Line Size        : 16 bytes
Line Data Width  : 128 bits
Tag Width        : 18 bits
Index Width      : 10 bits
Offset Width     : 4 bits
Write Policy     : Write-Back
Language         : SystemVerilog
Repository Structure
direct-mapped-writeback-cache/
│
├── README.md
│
├── rtl/
│   ├── cache_top.sv
│   ├── cache_controller.sv
│   ├── cache_data.sv
│   └── cache_tag.sv
│
└── tb/
    └── cache_tb.sv
Author

Ajeeth93