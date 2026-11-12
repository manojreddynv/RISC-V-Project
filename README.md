# RISC-V-Project
5-Stage Pipelined RISC-V RV32I Processor with IEEE-754 FPU, Dynamic ALU–FPU Selection, Operand Isolation, and Artix-7 FPGA Implementation.

## Project Overview
This project implements a 5-stage pipelined RISC-V processor with dynamic ALU–FPU selection.

## Architecture
The processor consists of five pipeline stages:
- Instruction Fetch (IF)
- Instruction Decode (ID)
- Execute (EX)
- Memory (MEM)
- Write Back (WB)

## Key Features
- 5-stage pipelined RISC-V processor
- Integer ALU operations
- IEEE-754 Single-Precision FPU
- FPU supports ADD, SUB, MUL, and DIV
- Dynamic ALU–FPU selection
- Operand isolation for inactive execution units

## Simulation
The processor is verified using Verilog testbench in Vivado.

- Testbench: `tb_core_verify`
- Simulation cycles: 80
- Register checks passed: 25/25

## Tools Used
- Verilog HDL
- Vivado

## Project Status
The processor design and simulation verification are completed. Further optimization and FPGA implementation are planned.

## Author
Manoj Reddy N V
