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

### Cache Capacity

```text
1024 cache lines × 128 bits per line
= 131,072 bits
= 16,384 bytes
= 16 KiB

### Address Decomposition

For a 32-bit byte address and a 128-bit cache line:

```text
128 bits = 16 bytes
1024 lines = 2^10

Therefore:
**Byte offset:** 4 bits
**Index:** 10 bits
**Tag:** 18 bits

```text
31                  14 13           4 3           0
┌─────────────────────┬──────────────┬──────────────┐
│         TAG         │    INDEX     │    OFFSET    │
│       18 bits       │   10 bits    │    4 bits    │
└─────────────────────┴──────────────┴──────────────┘

The address fields are used as follows:
**Tag [31:14]**
Identifies which memory block is currently stored in the selected cache line.
**Index [13:4]**
Selects one of the 1024 cache lines.
**Block Offset [3:0]**
Selects the byte within the 16-byte cache line.

---

### Cache Organization

The cache contains three primary storage structures:

```text
32-bit Address
                              │
                              ▼
                    ┌───────────────────┐
                    │ Address Decoder   │
                    └─────────┬─────────┘
                              │
               ┌──────────────┼──────────────┐
               │              │              │
               ▼              ▼              ▼
          ┌─────────┐   ┌──────────┐   ┌──────────┐
          │   TAG   │   │  INDEX   │   │  OFFSET  │
          │ 18 bits │   │ 10 bits  │   │  4 bits  │
          └────┬────┘   └────┬─────┘   └────┬─────┘
               │             │              │
               │             ▼              │
               │      ┌──────────────┐      │
               │      │ Cache Line   │      │
               │      │   0 - 1023   │      │
               │      └──────┬───────┘      │
               │             │              │
               ▼             ▼              ▼
        ┌─────────────────────────────────────────┐
        │              Cache Metadata             │
        │                                         │
        │       Tag + Valid + Dirty               │
        └──────────────────┬──────────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ Tag Compare  │
                    └──────┬───────┘
                           │
                      Hit / Miss
                           │
                           ▼
                  ┌──────────────────┐
                  │ Cache Controller │
                  │       FSM        │
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │   128-bit Data   │
                  │      Array       │
                  └────────┬─────────┘
                           │
                           ▼
                       CPU / Memory

The RTL is divided into separate modules for **cache data storage, tag/metadata storage and cache control**, keeping the implementation modular and easier to debug and extend.