# direct-mapped-writeback-cache
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