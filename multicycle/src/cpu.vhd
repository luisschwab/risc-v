-- Multicycle RISC-V CPU
--
-- The finished product built from Adders, ALU, Control Unit, Unified Memory,
-- Immediate Extender, Multiplexers, Program Counter Register, Register File and
-- non-architectural registers.
--
-- The testbench will parse `.text` and `.data` MIFs at
-- `static/mif/{data,text}.mif` and load it to the unified memory.
--
-- At each cycle, it will show values for the PC, the current
-- instruction with assembly syntax, the Control Unit signals and the ALU operation.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY cpu IS
    GENERIC (
        ADDR_WIDTH : INTEGER := 12;
        DATA_WIDTH : INTEGER := 32;
        TEXT_MIF_FILE : STRING := "static/mif/text.mif";
        DATA_MIF_FILE : STRING := "static/mif/data.mif"
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        -- Debug outputs
        debug_pc : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_instr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_pc_write : OUT STD_LOGIC;
        debug_ir_write : OUT STD_LOGIC;
        debug_reg_write : OUT STD_LOGIC;
        debug_mem_write : OUT STD_LOGIC;
        debug_memory_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_adr_src : OUT STD_LOGIC;
        debug_result_src : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        debug_alu_src_a : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        debug_alu_src_b : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        debug_alu_control : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        debug_alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_alu_src_a_val : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_alu_src_b_val : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_zero : OUT STD_LOGIC
    );
END ENTITY cpu;

ARCHITECTURE structural OF cpu IS
    -- Internal signals
    SIGNAL pc_current : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL immediate_extended : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Register file signals
    SIGNAL reg_read_data1, reg_read_data2 : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- ALU signals
    SIGNAL alu_src_a, alu_src_b : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL alu_zero : STD_LOGIC;

    -- Memory signals
    SIGNAL memory_address : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL memory_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Non-architectural register signals
    SIGNAL old_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL reg_a, reg_b : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL alu_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL memory_data : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Control signals
    SIGNAL pc_write, adr_src, mem_write, ir_write, reg_write : STD_LOGIC;
    SIGNAL result_src, alu_src_a_sel, alu_src_b_sel, imm_src : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL alu_control : STD_LOGIC_VECTOR(2 DOWNTO 0);

    -- Multiplexer outputs
    SIGNAL result_mux_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL constant_4 : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000004";

BEGIN
    -- Debug outputs
    debug_pc <= pc_current;
    debug_instr <= instruction;
    debug_pc_write <= pc_write;
    debug_ir_write <= ir_write;
    debug_reg_write <= reg_write;
    debug_mem_write <= mem_write;
    debug_memory_address <= memory_address;
    debug_adr_src <= adr_src;
    debug_result_src <= result_src;
    debug_alu_src_a <= alu_src_a_sel;
    debug_alu_src_b <= alu_src_b_sel;
    debug_alu_control <= alu_control;
    debug_alu_result <= alu_result;
    debug_alu_src_a_val <= alu_src_a;
    debug_alu_src_b_val <= alu_src_b;
    debug_result <= result_mux_out;
    debug_zero <= alu_zero;

    -- Program Counter
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            pc_current <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF pc_write = '1' THEN
                CASE result_src IS
                    WHEN "00" => pc_current <= alu_out;
                    WHEN "01" => pc_current <= memory_data;
                    WHEN "10" => pc_current <= alu_result;
                    WHEN OTHERS => pc_current <= x"00000000";
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    -- Old PC Register
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            old_pc <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF ir_write = '1' THEN
                old_pc <= pc_current;
            END IF;
        END IF;
    END PROCESS;

    -- Instruction Register
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            instruction <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            IF ir_write = '1' THEN
                instruction <= memory_read_data;
            END IF;
        END IF;
    END PROCESS;

    -- A Register (stores rs1 data)
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            reg_a <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            reg_a <= reg_read_data1;
        END IF;
    END PROCESS;

    -- B Register (stores rs2 data)
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            reg_b <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            reg_b <= reg_read_data2;
        END IF;
    END PROCESS;

    -- ALU Output Register
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            alu_out <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            alu_out <= alu_result;
        END IF;
    END PROCESS;

    -- Memory Data Register
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            memory_data <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            memory_data <= memory_read_data;
        END IF;
    END PROCESS;

    -- Memory
    main_memory : ENTITY work.memory
        GENERIC MAP(
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH,
            TEXT_MIF_FILE => TEXT_MIF_FILE,
            DATA_MIF_FILE => DATA_MIF_FILE
        )
        PORT MAP(
            clk => clk,
            addr => memory_address,
            wr_data => reg_b,
            wr_en => mem_write,
            rd_data => memory_read_data
        );

    -- Register File
    reg_file : ENTITY work.register_file
        PORT MAP(
            clk => clk,
            reset => reset,
            we3 => reg_write,
            a1 => instruction(19 DOWNTO 15), -- rs1
            a2 => instruction(24 DOWNTO 20), -- rs2
            a3 => instruction(11 DOWNTO 7), -- rd
            wd3 => result_mux_out,
            rd1 => reg_read_data1,
            rd2 => reg_read_data2
        );

    -- ALU
    main_alu : ENTITY work.alu
        PORT MAP(
            src_a => alu_src_a,
            src_b => alu_src_b,
            alu_control => alu_control,
            alu_result => alu_result,
            zero => alu_zero
        );

    -- Control Unit
    control : ENTITY work.control_unit
        PORT MAP(
            clk => clk,
            opcode => instruction(6 DOWNTO 0),
            funct3 => instruction(14 DOWNTO 12),
            funct7 => instruction(31 DOWNTO 25),
            zero => alu_zero,
            pc_write => pc_write,
            adr_src => adr_src,
            mem_write => mem_write,
            ir_write => ir_write,
            result_src => result_src,
            alu_control => alu_control,
            alu_src_a => alu_src_a_sel,
            alu_src_b => alu_src_b_sel,
            imm_src => imm_src,
            reg_write => reg_write
        );

    -- Immediate Extender
    imm_ext : ENTITY work.immediate_extender
        PORT MAP(
            instr => instruction,
            imm_src => imm_src,
            imm_ext => immediate_extended
        );

    -- Memory Address Multiplexer
    memory_address <= pc_current WHEN adr_src = '0' ELSE
        alu_out;

    -- ALU Source A Multiplexer
    WITH alu_src_a_sel SELECT alu_src_a <=
        pc_current WHEN "00",
        old_pc WHEN "01",
        reg_a WHEN "10",
        x"00000000" WHEN OTHERS;

    -- ALU Source B Multiplexer
    WITH alu_src_b_sel SELECT alu_src_b <=
        reg_b WHEN "00",
        immediate_extended WHEN "01",
        constant_4 WHEN "10",
        x"00000000" WHEN OTHERS;

    -- Result Multiplexer
    PROCESS (result_src, alu_out, memory_data, alu_result)
    BEGIN
        CASE result_src IS
            WHEN "00" => result_mux_out <= alu_out;
            WHEN "01" => result_mux_out <= memory_data;
            WHEN "10" => result_mux_out <= alu_result;
            WHEN OTHERS => result_mux_out <= x"00000000";
        END CASE;
    END PROCESS;

END ARCHITECTURE structural;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY cpu_tb IS
END ENTITY cpu_tb;

ARCHITECTURE testbench OF cpu_tb IS
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    SIGNAL finished : BOOLEAN := false;

    SIGNAL debug_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_instr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_pc_write : STD_LOGIC;
    SIGNAL debug_ir_write : STD_LOGIC;
    SIGNAL debug_reg_write : STD_LOGIC;
    SIGNAL debug_mem_write : STD_LOGIC;
    SIGNAL debug_memory_address : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_adr_src : STD_LOGIC;
    SIGNAL debug_result_src : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL debug_alu_src_a : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL debug_alu_src_b : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL debug_alu_control : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL debug_alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_alu_src_a_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_alu_src_b_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_zero : STD_LOGIC;

    -- Decode ALU op from control signal
    FUNCTION decode_alu_op(alu_control : STD_LOGIC_VECTOR(2 DOWNTO 0)) RETURN STRING IS
    BEGIN
        CASE alu_control IS
            WHEN "000" => RETURN "+"; -- add
            WHEN "001" => RETURN "-"; -- sub
            WHEN "010" => RETURN "&"; -- and
            WHEN "011" => RETURN "|"; -- or
            WHEN "100" => RETURN "^"; -- xor
            WHEN "101" => RETURN "<"; -- slt
            WHEN "110" => RETURN "<<"; -- sll
            WHEN "111" => RETURN ">>"; -- srl
            WHEN OTHERS => RETURN "wtf";
        END CASE;
    END FUNCTION;

    -- Decode FSM state from control signals based on the complete FSM diagram
    FUNCTION decode_fsm_state(pc_write, ir_write, reg_write, mem_write : STD_LOGIC;
        adr_src : STD_LOGIC;
        result_src : STD_LOGIC_VECTOR(1 DOWNTO 0);
        alu_src_a, alu_src_b : STD_LOGIC_VECTOR(1 DOWNTO 0)) RETURN STRING IS
    BEGIN
        -- S0: Fetch - AdrSrc=0, IRWrite=1, ALUSrcA=00, ALUSrcB=10, ResultSrc=10, PCUpdate=1
        IF ir_write = '1' AND pc_write = '1' AND adr_src = '0' AND result_src = "10" AND
            alu_src_a = "00" AND alu_src_b = "10" THEN
            RETURN "S0_FETCH";

        -- S1: Decode - ALUSrcA=01, ALUSrcB=01, ALUOp=00 (all others default to 0)
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '0' AND mem_write = '0' AND
            adr_src = '0' AND result_src = "00" AND alu_src_a = "01" AND alu_src_b = "01" THEN
            RETURN "S1_DECODE";

        -- S2: MemAdr - ALUSrcA=10, ALUSrcB=01, ALUOp=00
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '0' AND mem_write = '0' AND
            adr_src = '0' AND result_src = "00" AND alu_src_a = "10" AND alu_src_b = "01" THEN
            RETURN "S2_MEMADR";

        -- S3: MemRead - ResultSrc=00, AdrSrc=1
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '0' AND mem_write = '0' AND
            adr_src = '1' AND result_src = "00" THEN
            RETURN "S3_MEMREAD";

        -- S4: MemWB - ResultSrc=01, RegWrite=1
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '1' AND mem_write = '0' AND
            result_src = "01" THEN
            RETURN "S4_MEMWB";

        -- S5: MemWrite - ResultSrc=00, AdrSrc=1, MemWrite=1
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '0' AND mem_write = '1' AND
            adr_src = '1' AND result_src = "00" THEN
            RETURN "S5_MEMWRITE";

        -- S6: ExecuteR - ALUSrcA=10, ALUSrcB=00, ALUOp=10
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '0' AND mem_write = '0' AND
            adr_src = '0' AND result_src = "00" AND alu_src_a = "10" AND alu_src_b = "00" THEN
            RETURN "S6_EXECUTER";

        -- S7: ALUWB - ResultSrc=00, RegWrite=1
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '1' AND mem_write = '0' AND
            adr_src = '0' AND result_src = "00" THEN
            RETURN "S7_ALUWB";

        -- S8: ExecuteI - ALUSrcA=10, ALUSrcB=01, ALUOp=10
        ELSIF pc_write = '0' AND ir_write = '0' AND reg_write = '0' AND mem_write = '0' AND
            adr_src = '0' AND result_src = "00" AND alu_src_a = "10" AND alu_src_b = "01" THEN
            RETURN "S8_EXECUTEI";

        -- S9: JAL - ALUSrcA=01, ALUSrcB=10, ALUOp=00, ResultSrc=00, PCUpdate=1
        ELSIF pc_write = '1' AND ir_write = '0' AND reg_write = '0' AND mem_write = '0' AND
            adr_src = '0' AND result_src = "00" AND alu_src_a = "01" AND alu_src_b = "10" THEN
            RETURN "S9_JAL";

        -- S10: BEQ - ALUSrcA=10, ALUSrcB=00, ALUOp=01, ResultSrc=00, Branch=1
        ELSIF ir_write = '0' AND reg_write = '0' AND mem_write = '0' AND
            adr_src = '0' AND result_src = "00" AND alu_src_a = "10" AND alu_src_b = "00" THEN
            RETURN "S10_BEQ";

        ELSE
            RETURN "S?_UNKNOWN";
        END IF;
    END FUNCTION;

    -- Decode instruction to RV32I syntax
    FUNCTION decode_instruction(instr : STD_LOGIC_VECTOR(31 DOWNTO 0)) RETURN STRING IS
        VARIABLE opcode : STD_LOGIC_VECTOR(6 DOWNTO 0);
        VARIABLE funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
        VARIABLE funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0);
        VARIABLE rs1, rs2, rd : INTEGER;
        VARIABLE imm_i, imm_s, imm_b : INTEGER;
        VARIABLE imm_u, imm_j : INTEGER;
    BEGIN
        opcode := instr(6 DOWNTO 0);
        funct3 := instr(14 DOWNTO 12);
        funct7 := instr(31 DOWNTO 25);

        -- Extract register fields
        rs1 := TO_INTEGER(UNSIGNED(instr(19 DOWNTO 15)));
        rs2 := TO_INTEGER(UNSIGNED(instr(24 DOWNTO 20)));
        rd := TO_INTEGER(UNSIGNED(instr(11 DOWNTO 7)));

        -- Extract immediate fields
        imm_i := TO_INTEGER(SIGNED(instr(31 DOWNTO 20)));
        imm_s := TO_INTEGER(SIGNED(instr(31 DOWNTO 25) & instr(11 DOWNTO 7)));
        imm_b := TO_INTEGER(SIGNED(instr(31) & instr(7) & instr(30 DOWNTO 25) & instr(11 DOWNTO 8) & '0'));
        imm_u := TO_INTEGER(SIGNED(instr(31 DOWNTO 12) & x"000"));
        imm_j := TO_INTEGER(SIGNED(instr(31) & instr(19 DOWNTO 12) & instr(20) & instr(30 DOWNTO 21) & '0'));

        CASE opcode IS
            WHEN "0110011" => -- R
                CASE funct3 IS
                    WHEN "000" =>
                        IF funct7(5) = '1' THEN
                            RETURN "sub x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                        ELSE
                            RETURN "add x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                        END IF;
                    WHEN "111" => RETURN "and x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                    WHEN "110" => RETURN "or x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                    WHEN "100" => RETURN "xor x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                    WHEN "010" => RETURN "slt x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                    WHEN "001" => RETURN "sll x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                    WHEN "101" => RETURN "srl x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                    WHEN OTHERS => RETURN "R-type x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2);
                END CASE;

            WHEN "0010011" => -- I
                CASE funct3 IS
                    WHEN "000" => RETURN "addi x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                    WHEN "111" => RETURN "andi x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                    WHEN "110" => RETURN "ori x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                    WHEN "100" => RETURN "xori x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                    WHEN "010" => RETURN "slti x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                    WHEN "001" => RETURN "slli x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                    WHEN "101" => RETURN "srli x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                    WHEN OTHERS => RETURN "I-arith x" & INTEGER'IMAGE(rd) & ", x" & INTEGER'IMAGE(rs1) & ", " & INTEGER'IMAGE(imm_i);
                END CASE;

            WHEN "0000011" => -- L
                CASE funct3 IS
                    WHEN "000" => RETURN "lb x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_i) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN "001" => RETURN "lh x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_i) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN "010" => RETURN "lw x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_i) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN "100" => RETURN "lbu x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_i) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN "101" => RETURN "lhu x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_i) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN OTHERS => RETURN "load x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_i) & "(x" & INTEGER'IMAGE(rs1) & ")";
                END CASE;

            WHEN "0100011" => -- S
                CASE funct3 IS
                    WHEN "000" => RETURN "sb x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_s) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN "001" => RETURN "sh x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_s) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN "010" => RETURN "sw x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_s) & "(x" & INTEGER'IMAGE(rs1) & ")";
                    WHEN OTHERS => RETURN "store x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_s) & "(x" & INTEGER'IMAGE(rs1) & ")";
                END CASE;

            WHEN "1100011" => -- B
                CASE funct3 IS
                    WHEN "000" => RETURN "beq x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_b);
                    WHEN "001" => RETURN "bne x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_b);
                    WHEN "100" => RETURN "blt x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_b);
                    WHEN "101" => RETURN "bge x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_b);
                    WHEN "110" => RETURN "bltu x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_b);
                    WHEN "111" => RETURN "bgeu x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_b);
                    WHEN OTHERS => RETURN "branch x" & INTEGER'IMAGE(rs1) & ", x" & INTEGER'IMAGE(rs2) & ", " & INTEGER'IMAGE(imm_b);
                END CASE;

            WHEN "1101111" => -- jal
                RETURN "jal x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_j);

            WHEN "1100111" => -- jalr
                RETURN "jalr x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_i) & "(x" & INTEGER'IMAGE(rs1) & ")";

            WHEN "0110111" => -- lui
                RETURN "lui x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_u / 4096);

            WHEN "0010111" => -- auipc
                RETURN "auipc x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_u / 4096);

            WHEN OTHERS =>
                RETURN "UNKNOWN";
        END CASE;
    END FUNCTION;

BEGIN
    -- TODO(@luisschwab): wtf? when the clock is >= 7ns, if fetches NOP
    clk <= NOT clk AFTER 5 ns WHEN NOT finished ELSE '0';

    uut : ENTITY work.cpu
        GENERIC MAP(
            ADDR_WIDTH => 10,
            DATA_WIDTH => 32,
            TEXT_MIF_FILE => "static/mif/text.mif",
            DATA_MIF_FILE => "static/mif/data.mif"
        )
        PORT MAP(
            clk => clk,
            reset => reset,
            debug_pc => debug_pc,
            debug_instr => debug_instr,
            debug_pc_write => debug_pc_write,
            debug_ir_write => debug_ir_write,
            debug_reg_write => debug_reg_write,
            debug_mem_write => debug_mem_write,
            debug_memory_address => debug_memory_address,
            debug_adr_src => debug_adr_src,
            debug_result_src => debug_result_src,
            debug_alu_src_a => debug_alu_src_a,
            debug_alu_src_b => debug_alu_src_b,
            debug_alu_control => debug_alu_control,
            debug_alu_result => debug_alu_result,
            debug_alu_src_a_val => debug_alu_src_a_val,
            debug_alu_src_b_val => debug_alu_src_b_val,
            debug_result => debug_result,
            debug_zero => debug_zero
        );

    monitor : PROCESS
        VARIABLE cycle_count : INTEGER := 0;
        VARIABLE max_simulation_cycles : INTEGER := 100;
        VARIABLE prev_pc : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
        VARIABLE same_pc_count : INTEGER := 0;
    BEGIN
        WAIT UNTIL reset = '0';
        WAIT UNTIL rising_edge(clk);

        cycle_count := cycle_count + 1;
        REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "PC: 0x" & to_hstring(debug_pc);
        REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "Instr: 0x" & to_hstring(debug_instr) & " (" & decode_instruction(debug_instr) & ")";
        REPORT "";

        LOOP
            WAIT UNTIL rising_edge(clk);
            cycle_count := cycle_count + 1;

            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "PC: 0x" & to_hstring(debug_pc);
            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "Instr: 0x" & to_hstring(debug_instr) & " (" & decode_instruction(debug_instr) & ")";

            -- Current FSM state and control signals
            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "FSM: " & decode_fsm_state(debug_pc_write, debug_ir_write, debug_reg_write, debug_mem_write, debug_adr_src, debug_result_src, debug_alu_src_a, debug_alu_src_b);
            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "CU: PCWrite=" & STD_LOGIC'IMAGE(debug_pc_write) & " IRWrite=" & STD_LOGIC'IMAGE(debug_ir_write) & " RegWrite=" & STD_LOGIC'IMAGE(debug_reg_write) & " MemWrite=" & STD_LOGIC'IMAGE(debug_mem_write);
            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "    AdrSrc=" & STD_LOGIC'IMAGE(debug_adr_src) & " ResultSrc=" & to_string(debug_result_src) & " ALUSrcA=" & to_string(debug_alu_src_a) & " ALUSrcB=" & to_string(debug_alu_src_b);

            -- Register writes
            IF debug_reg_write = '1' AND TO_INTEGER(UNSIGNED(debug_instr(11 DOWNTO 7))) /= 0 THEN
                REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "Write to x" & INTEGER'IMAGE(TO_INTEGER(UNSIGNED(debug_instr(11 DOWNTO 7)))) & ": 0x" & to_hstring(debug_result);
            END IF;

            -- ALU op
            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "ALU: 0x" & to_hstring(debug_alu_src_a_val) & " " & decode_alu_op(debug_alu_control) & " 0x" & to_hstring(debug_alu_src_b_val) & " = 0x" & to_hstring(debug_alu_result) & " (Zero=" & STD_LOGIC'IMAGE(debug_zero) & ")";

            -- IRs `Adr`
            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "IR: 0x" & to_hstring(debug_memory_address) & " (AdrSrc=" & STD_LOGIC'IMAGE(debug_adr_src) & ")";

            REPORT "";

            -- Multicycle PC changes
            IF debug_pc = prev_pc THEN
                same_pc_count := same_pc_count + 1;
            ELSE
                same_pc_count := 0;
                prev_pc := debug_pc;
            END IF;

            IF cycle_count >= max_simulation_cycles OR
                same_pc_count > 10 OR -- allow some trailling cycles to finish execution of the current instruction
                (debug_instr = x"00000000") THEN

                IF debug_instr = x"00000000" THEN
                    REPORT "EOE: fetched NOP/end instruction";
                ELSIF same_pc_count > 10 THEN
                    REPORT "EOE: PC stopped advancing (infinite loop: `jmp $`)";
                ELSE
                    REPORT "EOE: maximum simulation cycles reached: " & INTEGER'IMAGE(max_simulation_cycles);
                END IF;
                EXIT;
            END IF;
        END LOOP;

        finished <= true;
        WAIT;
    END PROCESS;

    stimulus : PROCESS
    BEGIN
        reset <= '1';
        WAIT FOR 20 ns;
        reset <= '0';

        WAIT UNTIL finished;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;
