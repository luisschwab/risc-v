-- CPU
--
-- The finished product built from adders, ALU, Control Unit, Data Memory,
-- Instruction Memory, Immediate Extender, multiplexers, Program Counter Register and Register File.
--
-- The testbench will parse `.text` and `.data` MIFs at `static/mif/{data,text}.mif`.
-- At each cycle, it will show values for the PC, the instruction with assembly syntax,
-- the Control Unit signals and the ALU operation.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY cpu IS
    GENERIC (
        TEXT_MIF_FILE : STRING := "static/mif/text.mif";
        DATA_MIF_FILE : STRING := "static/mif/data.mif"
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        -- Debug outputs
        debug_pc : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_instr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_reg_write : OUT STD_LOGIC;
        debug_mem_write : OUT STD_LOGIC;
        debug_pc_src : OUT STD_LOGIC;
        debug_alu_src : OUT STD_LOGIC;
        debug_alu_control : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        debug_alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_alu_src_a : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_alu_src_b : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        debug_zero : OUT STD_LOGIC
    );
END ENTITY cpu;

ARCHITECTURE structural OF cpu IS
    -- Internal signals
    SIGNAL pc, pc_next, pc_plus4, pc_target : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL instr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL imm_ext : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL alu_result, alu_src_a, alu_src_b : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL read_data, write_data, result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL rd1, rd2 : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Control signals
    SIGNAL pc_src : STD_LOGIC;
    SIGNAL result_src : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL mem_write : STD_LOGIC;
    SIGNAL alu_control : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL alu_src : STD_LOGIC;
    SIGNAL imm_src : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL reg_write : STD_LOGIC;
    SIGNAL zero_alu : STD_LOGIC;

    COMPONENT alu IS
        PORT (
            src_a : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            src_b : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            alu_control : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            zero : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT control_unit IS
        PORT (
            opcode : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
            funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
            zero : IN STD_LOGIC;
            pc_src : OUT STD_LOGIC;
            result_src : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            mem_write : OUT STD_LOGIC;
            alu_control : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            alu_src : OUT STD_LOGIC;
            imm_src : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            reg_write : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT data_memory IS
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
    END COMPONENT;

    COMPONENT instruction_memory IS
        GENERIC (
            ADDR_WIDTH : INTEGER := 10;
            DATA_WIDTH : INTEGER := 32;
            MIF_FILE : STRING := "static/mif/instr.mif"
        );
        PORT (
            addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT immediate_extender IS
        PORT (
            instr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            imm_src : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            imm_ext : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT register_file IS
        PORT (
            clk : IN STD_LOGIC;
            reset : IN STD_LOGIC;
            we3 : IN STD_LOGIC;
            a1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            a2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            a3 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            wd3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;
BEGIN
    -- Program Counter
    pc_reg : PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            pc <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            pc <= pc_next;
        END IF;
    END PROCESS;
    pc_plus4 <= STD_LOGIC_VECTOR(UNSIGNED(pc) + 4);
    pc_target <= STD_LOGIC_VECTOR(UNSIGNED(pc) + UNSIGNED(imm_ext));
    pc_next <= pc_target WHEN pc_src = '1' ELSE
        pc_plus4;

    -- Instruction Memory
    imem : instruction_memory
    GENERIC MAP(
        ADDR_WIDTH => 10,
        DATA_WIDTH => 32,
        MIF_FILE => TEXT_MIF_FILE
    )
    PORT MAP(
        addr => pc,
        rd => instr
    );

    -- Control Unit
    control : control_unit
    PORT MAP(
        opcode => instr(6 DOWNTO 0),
        funct3 => instr(14 DOWNTO 12),
        funct7 => instr(31 DOWNTO 25),
        zero => zero_alu, -- Connect internal zero_alu signal to zero port
        pc_src => pc_src,
        result_src => result_src,
        mem_write => mem_write,
        alu_control => alu_control,
        alu_src => alu_src,
        imm_src => imm_src,
        reg_write => reg_write
    );

    -- Register File
    regfile : register_file
    PORT MAP(
        clk => clk,
        reset => reset,
        we3 => reg_write,
        a1 => instr(19 DOWNTO 15), -- rs1
        a2 => instr(24 DOWNTO 20), -- rs2
        a3 => instr(11 DOWNTO 7), -- rd
        wd3 => result,
        rd1 => rd1,
        rd2 => rd2
    );

    -- Immediate Extender
    immext_unit : immediate_extender
    PORT MAP(
        instr => instr,
        imm_src => imm_src,
        imm_ext => imm_ext
    );

    -- ALU
    alu_src_a <= rd1;
    alu_src_b <= imm_ext WHEN alu_src = '1' ELSE
        rd2;
    alu_unit : alu
    PORT MAP(
        src_a => alu_src_a,
        src_b => alu_src_b,
        alu_control => alu_control,
        alu_result => alu_result,
        zero => zero_alu
    );

    -- Data Memory
    dmem : data_memory
    GENERIC MAP(
        ADDR_WIDTH => 10,
        DATA_WIDTH => 32,
        MIF_FILE => DATA_MIF_FILE
    )
    PORT MAP(
        clk => clk,
        addr => alu_result,
        wr_data => rd2,
        wr_en => mem_write,
        rd_data => read_data
    );

    -- Result source multiplexer
    result <= alu_result WHEN result_src = "00" ELSE
        read_data WHEN result_src = "01" ELSE
        pc_plus4 WHEN result_src = "10" ELSE
        imm_ext; -- result_src = "11"

    -- Debug outputs
    debug_pc <= pc;
    debug_instr <= instr;
    debug_reg_write <= reg_write;
    debug_mem_write <= mem_write;
    debug_alu_src <= alu_src;
    debug_pc_src <= pc_src;
    debug_alu_result <= alu_result;
    debug_alu_control <= alu_control;
    debug_alu_src_a <= alu_src_a;
    debug_alu_src_b <= alu_src_b;
    debug_result <= result;
    debug_zero <= zero_alu;

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

    -- Debug signals
    SIGNAL debug_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_instr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_reg_write : STD_LOGIC;
    SIGNAL debug_mem_write : STD_LOGIC;
    SIGNAL debug_alu_src : STD_LOGIC;
    SIGNAL debug_pc_src : STD_LOGIC;
    SIGNAL debug_alu_control : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL debug_alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_alu_src_a : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_alu_src_b : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL debug_zero : STD_LOGIC;

    COMPONENT cpu IS
        GENERIC (
            TEXT_MIF_FILE : STRING := "text.mif";
            DATA_MIF_FILE : STRING := "data.mif"
        );
        PORT (
            clk : IN STD_LOGIC;
            reset : IN STD_LOGIC;

            -- Debug outputs
            debug_pc : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            debug_instr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            debug_reg_write : OUT STD_LOGIC;
            debug_mem_write : OUT STD_LOGIC;
            debug_alu_src : OUT STD_LOGIC;
            debug_pc_src : OUT STD_LOGIC;
            debug_alu_control : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            debug_alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            debug_alu_src_a : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            debug_alu_src_b : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            debug_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            debug_zero : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Decode ALU operation from control signal
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
            WHEN OTHERS => RETURN "wtf"; -- wtf
        END CASE;
    END FUNCTION;

    -- Decode instruction to assembly syntax
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
                RETURN "lui x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_u / 4096); -- Show upper 20 bits

            WHEN "0010111" => -- auipc
                RETURN "auipc x" & INTEGER'IMAGE(rd) & ", " & INTEGER'IMAGE(imm_u / 4096); -- Show upper 20 bits

            WHEN OTHERS =>
                RETURN "UNKNOWN";
        END CASE;
    END FUNCTION;

BEGIN
    clk <= NOT clk AFTER 5 ns WHEN NOT finished ELSE
        '0';

    uut : cpu
    GENERIC MAP(
        TEXT_MIF_FILE => "static/mif/text.mif",
        DATA_MIF_FILE => "static/mif/data.mif"
    )
    PORT MAP(
        clk => clk,
        reset => reset,
        debug_pc => debug_pc,
        debug_instr => debug_instr,
        debug_reg_write => debug_reg_write,
        debug_mem_write => debug_mem_write,
        debug_alu_src => debug_alu_src,
        debug_pc_src => debug_pc_src,
        debug_alu_control => debug_alu_control,
        debug_alu_result => debug_alu_result,
        debug_alu_src_a => debug_alu_src_a,
        debug_alu_src_b => debug_alu_src_b,
        debug_result => debug_result,
        debug_zero => debug_zero
    );

    monitor : PROCESS
        VARIABLE cycle_count : INTEGER := 0;
        VARIABLE prev_pc : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
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

            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "CU: RegWrite=" & STD_LOGIC'IMAGE(debug_reg_write) & " MemWrite=" & STD_LOGIC'IMAGE(debug_mem_write) & " ALUSrc=" & STD_LOGIC'IMAGE(debug_alu_src) & " PCSrc=" & STD_LOGIC'IMAGE(debug_pc_src);

            IF debug_reg_write = '1' AND TO_INTEGER(UNSIGNED(debug_instr(11 DOWNTO 7))) /= 0 THEN
                REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "Write to x" & INTEGER'IMAGE(TO_INTEGER(UNSIGNED(debug_instr(11 DOWNTO 7)))) & ": 0x" & to_hstring(debug_result);
            END IF;

            REPORT "[" & INTEGER'IMAGE(cycle_count) & "] " & "ALU: 0x" & to_hstring(debug_alu_src_a) & " " & decode_alu_op(debug_alu_control) & " 0x" & to_hstring(debug_alu_src_b) & " = 0x" & to_hstring(debug_alu_result) & " (Zero=" & STD_LOGIC'IMAGE(debug_zero) & ")";
            REPORT "";

            -- Stop execution
            IF cycle_count >= 10 OR
                (cycle_count > 1 AND debug_pc = prev_pc) OR
                (debug_instr = x"00000000") THEN

                IF debug_instr = x"00000000" THEN -- null instruction
                    REPORT "Program ended: fetched NOP/end instruction";
                ELSIF debug_pc = prev_pc THEN -- infinite loop
                    REPORT "Program ended: PC stopped advancing (infinite loop detected)";
                ELSE -- max cycles
                    REPORT "Program ended: maximum cycles reached";
                END IF;
                EXIT;
            END IF;

            prev_pc := debug_pc;
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