# RISC-V Unicycle Processor

This project implements the Unicycle (referred as Single Cycle) Processor from _Digital Design and Computer Architecture: RISC-V Edition_ from Chapter 7.3.

<p align="center">
  <img src="static/image/unicycle.png" width="80%">
</p>

## Usage

### Dependencies

This project depends on [`just`](https://github.com/casey/just) for command running, [`ghdl`](https://github.com/ghdl/ghdl) for VHDL compilation and [`gtkwave`](https://github.com/gtkwave/gtkwave) for visualization. To install them on Debian-based distros:

```shell
~$ apt install just ghdl gtkwave
```

### Running

To list available recipes:
```shell
~$ just
Available recipes:
    clean                      # Delete artifacts from work directory
    test component="component" # Test individual components: cpu, adder, alu, control, dmem, imem, immext, mux, pc, regfile
    test-all                   # Test all components
    wave component="component" # Test and view waveforms for components: cpu, adder, alu, control, dmem, imem, immext, mux, pc, regfile (press CTRL+0 to adjust the zoom)
```

`just test cpu` will run the CPU against the default program defined on `static/mif/text.mif` and `static/mif/data.mif`; a simple program that loads 1 into `t0` and doubles it forever:
```asm
.data
.word 1

.text
	#li gp,0x10010000
	lw t0,0(gp)
LOOP: 	add t0,t0,t0
	j LOOP
```
If you want to run something else, create a hex dumps for `.data` and `.text` using [`RARS`](https://github.com/TheThirdOne/rars/) and place them under `static/mif`.

To see the signals for a component the CPU, run `just wave cpu` and press `CTRL+0` to resize the zoom.

## Architectural State and Instruction Set

A computer architecture is defined by its Architectural State (**AS**) and Instruction Set (**IS**). For the RISC-V processor, the **AS** consists of the Program Counter (**PC**) and the 32 32-bit Registers (Register File / Register Bank). Based on the current **AS**, the processor executes some instruction with some data to produce another **AS**.

The [`Program Counter`](#program-counter-register), [`Register File`](#register-file) and [`Data Memory`](#data-memory) are read _combinationally_: if the address changes, the new data appears after some propagation delay, but they are only written to on the rising edge of CLK. In this way, a processor can be viwed as a [Finite State Machine](https://en.wikipedia.org/wiki/Finite-state_machine).

The Unicycle architecture executes a single instruction per cycle, so has no need for _non-architectural_ state, but the cycle time is limited by the slowest instruction, and also needs to have separate instruction and data memory.


## Design Process

The microarchitecture is divided in two: the _datapath_ and the _control unit_.

The datapath (DP) operates on words (32 bits, in this case) using memory, registers, ALUs and multiplexers. The Control Unit (CU) receives the current instruction from the datapath and tells it how to execute them by producing multiplexer select, register enable and memory write signals to control the flow of the datapath.

We start with hardware that contains state and then add blocks of combinational logic between them to compute the next state. We use 4 state elements: a Program Counter (PC), a Register File (RF), Instruction Memory and Data Memory.

## Components

### Adder

Simple generic width adder without overflow and underflow detection.

```vhdl
ENTITY adder IS
    GENERIC (
        WIDTH : INTEGER := 32
    );
    PORT (
        a : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        b : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        result : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
    );
END ENTITY adder;
```

### Arithmetic Logic Unit (ALU)

The ALU is responsible for executing arithmetic operations over two inputs and a control signal that determines which operation it must perform. Outputs the result and a zero flag useful for branching operations (beq, bne, blt, bge).

```vhdl
ENTITY alu IS
    PORT (
        src_a      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        src_b      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        alu_control: IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        zero       : OUT STD_LOGIC
    );
END ENTITY alu;
```

### Control Unit

The Control Unit is responsible for computing control signals for most components of the CPU, such as the ALU, Data Memory, Instruction Memory, Register File, Immediate Extender and a few multiplexers.

```vhdl
ENTITY control_unit IS
    PORT (
        opcode      : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        funct3      : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        funct7      : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        zero        : IN STD_LOGIC;
        pc_src      : OUT STD_LOGIC;
        result_src  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        mem_write   : OUT STD_LOGIC;
        alu_control : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        alu_src     : OUT STD_LOGIC;
        imm_src     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        reg_write   : OUT STD_LOGIC
    );
END ENTITY control_unit;
```

### Data Memory

The Data Memory is the RAM of the CPU, responsible for storing the `.data` segment, the heap and the stack. This implementation supports generic address and data widths.

```vhdl
ENTITY data_memory IS
    GENERIC (
        ADDR_WIDTH : INTEGER := 10;
        DATA_WIDTH : INTEGER := 32;
        MIF_FILE : STRING := "static/mif/data.mif"
    );
    PORT (
        clk : IN STD_LOGIC;
        addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        wr_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY data_memory;
```

### Instruction Memory

The Instruction Memory is the ROM of the CPU, responsible for storing the `.text` segment: the program itself.

```vhdl
ENTITY instruction_memory IS
    GENERIC (
        ADDR_WIDTH : INTEGER := 10;
        DATA_WIDTH : INTEGER := 32;
        MIF_FILE : STRING := "static/mif/text.mif"
    );
    PORT (
        addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        rd : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY instruction_memory;
```

### Immediate Extender

Extends the immediate to the full 32 bits using sign extension (left pad with the sign bit until 32 bits). The values of `ImmSrc` we're chosen arbitrarly and are generated by the [Control Unit](#control-unit).

```vhdl
ENTITY immediate_extender IS
    PORT (
        instr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        imm_src : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        imm_ext : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY immediate_extender;
```

### Multiplexers

Basic 2-input and 4-input multiplexers, used for signal selection.

```vhdl
ENTITY mux2 IS
    GENERIC (
        WIDTH : INTEGER := 32
    );
    PORT (
        d0 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        d1 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        sel : IN STD_LOGIC;
        y : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
    );
END ENTITY mux2;

ENTITY mux4 IS
    GENERIC (
        WIDTH : INTEGER := 32
    );
    PORT (
        d0 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        d1 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        d2 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        d3 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        sel : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        y : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
    );
END ENTITY mux4;
```

### Program Counter Register

The Program Counter stores the address of the instruction to be executed. On the rising edge of the clock signal, PC = PCNext.

```vhdl
ENTITY pc_register IS
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        pc_next : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY pc_register;
```

### Register File

32 32-bit registers, used to fast temporary data storage. Loading and storing to a register is much faster than loading and storing to Data Memory (same-cycle acess).

```vhdl
ENTITY register_file IS
    PORT (
        clk : IN STD_LOGIC;
        reset: IN STD_LOGIC;
        we3 : IN STD_LOGIC;
        a1  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
        a2  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
        a3  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
        wd3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        rd1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        rd2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY register_file;
```
