-- Control Unit
--
-- The Control Unit for the Multicycle architecture is composed of an Instruction Decoder,
-- an ALU decoder and a Finite-State Machine.
--
-- To implement the FSM, we simply need a register to hold the current state; the state itself
-- is represented by an enum with all possible states. Then we do a simple switch-case statement
-- that implements the diagram from the README.
--
-- Control Unit:
--   Inputs:
--     clk (1 bit) => clock signal for FSM state transitions.
--     opcode (7 bits: instruction[6:0]) => specifies the instruction to be executed.
--     funct3 (3 bits: instruction[14:12]) => further specifies the instruction to be executed.
--     funct7 (7 bits: instruction[31:25) => even further specifies the instruction to be executed.
--     zero (1 bit: ALU zero) => whether the ALU operation result was zero.
--   Outputs:
--     PCWrite (1 bit) => enable PC register update.
--     AdrSrc (1 bit) => select address source (PC or ALUOut).
--     MemWrite (1 bit) => enable writing to the Memory.
--     IRWrite (1 bit) => enable Instruction Register update.
--     ResultSrc (2 bits) => selector for the multiplexer that sources data to be written to the Register File (ALUOut OR ALUResult OR Memory).
--     ALUControl (3 bits) => selector for the operation the ALU must perform (add OR sub OR and OR xor OR slt OR sll OR srl).
--     ALUSrcA (2 bits) => select ALU source A.
--     ALUSrcB (2 bits) => select ALU source B.
--     ImmSrc (2 bits) => selector for the Immediate Extension operation conditional on instruction type (I OR S OR B OR (J & U)).
--     RegWrite (1 bit) => enabler for writing to the Register File.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY control_unit IS
    PORT (
        clk : IN STD_LOGIC;
        opcode : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        zero : IN STD_LOGIC;
        pc_write : OUT STD_LOGIC;
        adr_src : OUT STD_LOGIC;
        mem_write : OUT STD_LOGIC;
        ir_write : OUT STD_LOGIC;
        result_src : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        alu_control : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        alu_src_a : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        alu_src_b : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        imm_src : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        reg_write : OUT STD_LOGIC
    );
END ENTITY control_unit;

ARCHITECTURE behavioral OF control_unit IS
    -- Enum type for FSM states
    -- S00: Fetch
    -- S01: Decode
    -- S02: MemAdr
    -- S03: MemRead
    -- S04: MemWB
    -- S05: MemWrite
    -- S06: ExecuteR
    -- S07: ALUWB
    -- S08: ExecuteI
    -- S09: JAL
    -- S10: BEQ
    TYPE fsm_state IS (S0_FETCH, S1_DECODE, S2_MEMADR,
        S3_MEMREAD, S4_MEMWB, S5_MEMWRITE,
        S6_EXECUTER, S7_ALUWB, S8_EXECUTEI,
        S9_JAL, S10_BEQ);

    SIGNAL current_state : fsm_state := S0_FETCH;
    SIGNAL next_state : fsm_state;

    SIGNAL alu_op : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL branch : STD_LOGIC;
    SIGNAL pc_update : STD_LOGIC;

BEGIN
    -- PC Write logic
    pc_write <= pc_update OR (branch AND zero);

    -- Instruction Decoder
    instruction_decoder : PROCESS (opcode)
    BEGIN
        CASE opcode IS
            WHEN "0000011" => imm_src <= "00"; -- I-type (lw)
            WHEN "0010011" => imm_src <= "00"; -- I-type ALU (addi, etc.)
            WHEN "1100111" => imm_src <= "00"; -- I-type (jalr)
            WHEN "0100011" => imm_src <= "01"; -- S-type (sw)
            WHEN "1100011" => imm_src <= "10"; -- B-type (beq)
            WHEN "1101111" => imm_src <= "11"; -- J-type (jal)
            WHEN "0010111" => imm_src <= "11"; -- U-type (auipc)
            WHEN "0110011" => imm_src <= "00"; -- R-type (add/sub/and/or/slt: Imm not used, don't care)
            WHEN OTHERS => imm_src <= "00";
        END CASE;
    END PROCESS;

    -- ALU Decoder
    alu_decoder : PROCESS (alu_op, funct3, funct7, opcode)
    BEGIN
        CASE alu_op IS
            WHEN "00" => -- Addition for address calculation
                alu_control <= "000";
            WHEN "01" => -- Subtraction for beq
                alu_control <= "001";
            WHEN "10" => -- R-type and I-type ALU operations
                CASE funct3 IS
                    WHEN "000" =>
                        IF opcode = "0110011" AND funct7(5) = '1' THEN
                            alu_control <= "001"; -- sub
                        ELSE
                            alu_control <= "000"; -- add/addi
                        END IF;
                    WHEN "010" => alu_control <= "101"; -- slt/slti
                    WHEN "110" => alu_control <= "011"; -- or/ori
                    WHEN "111" => alu_control <= "010"; -- and/andi
                    WHEN OTHERS => alu_control <= "000";
                END CASE;
            WHEN OTHERS => alu_control <= "000";
        END CASE;
    END PROCESS;

    -- FSM state register
    fsm_state_register : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            current_state <= next_state;
        END IF;
    END PROCESS;

    -- FSM state transition logic
    next_state_logic : PROCESS (current_state, opcode)
    BEGIN
        -- A fetch ALWAYS precedes a decode
        CASE current_state IS
            WHEN S0_FETCH => next_state <= S1_DECODE;

            WHEN S1_DECODE =>
                CASE opcode IS
                    WHEN "0000011" | "0100011" => -- lw / sw
                        next_state <= S2_MEMADR;
                    WHEN "0110011" => -- R-type
                        next_state <= S6_EXECUTER;
                    WHEN "0010011" => -- I-type ALU
                        next_state <= S8_EXECUTEI;
                    WHEN "1101111" => -- jal
                        next_state <= S9_JAL;
                    WHEN "1100011" => -- beq
                        next_state <= S10_BEQ;
                    WHEN OTHERS => -- Deafult to  `S0_FETCH`
                        next_state <= S0_FETCH;
                END CASE;

            WHEN S2_MEMADR =>
                IF opcode = "0000011" THEN -- lw
                    next_state <= S3_MEMREAD;
                ELSE -- sw
                    next_state <= S5_MEMWRITE;
                END IF;

            WHEN S3_MEMREAD =>
                next_state <= S4_MEMWB;

            WHEN S4_MEMWB =>
                next_state <= S0_FETCH;

            WHEN S5_MEMWRITE =>
                next_state <= S0_FETCH;

            WHEN S6_EXECUTER =>
                next_state <= S7_ALUWB;

            WHEN S8_EXECUTEI =>
                next_state <= S7_ALUWB;

            WHEN S7_ALUWB =>
                next_state <= S0_FETCH;

            WHEN S9_JAL =>
                next_state <= S7_ALUWB;

            WHEN S10_BEQ =>
                next_state <= S0_FETCH;

            WHEN OTHERS => -- Deafult to  `S0_FETCH`
                next_state <= S0_FETCH;
        END CASE;
    END PROCESS;

    -- FSM output logic
    output_logic : PROCESS (current_state)
    BEGIN
        adr_src <= '0';
        ir_write <= '0';
        alu_src_a <= "00";
        alu_src_b <= "00";
        alu_op <= "00";
        result_src <= "00";
        pc_update <= '0';
        reg_write <= '0';
        mem_write <= '0';
        branch <= '0';

        CASE current_state IS
            WHEN S0_FETCH =>
                adr_src <= '0';
                ir_write <= '1';
                alu_src_a <= "00";
                alu_src_b <= "10";
                alu_op <= "00";
                result_src <= "10";
                pc_update <= '1';

            WHEN S1_DECODE =>
                alu_src_a <= "01";
                alu_src_b <= "01";
                alu_op <= "00";

            WHEN S2_MEMADR =>
                alu_src_a <= "10";
                alu_src_b <= "01";
                alu_op <= "00";

            WHEN S3_MEMREAD =>
                result_src <= "00";
                adr_src <= '1';

            WHEN S4_MEMWB =>
                result_src <= "01";
                reg_write <= '1';

            WHEN S5_MEMWRITE =>
                result_src <= "00";
                adr_src <= '1';
                mem_write <= '1';

            WHEN S6_EXECUTER =>
                alu_src_a <= "10";
                alu_src_b <= "00";
                alu_op <= "10";

            WHEN S7_ALUWB =>
                result_src <= "00";
                reg_write <= '1';

            WHEN S8_EXECUTEI =>
                alu_src_a <= "10";
                alu_src_b <= "01";
                alu_op <= "10";

            WHEN S9_JAL =>
                alu_src_a <= "01";
                alu_src_b <= "10";
                alu_op <= "00";
                result_src <= "00";
                pc_update <= '1';

            WHEN S10_BEQ =>
                alu_src_a <= "10";
                alu_src_b <= "00";
                alu_op <= "01";
                result_src <= "00";
                branch <= '1';

            WHEN OTHERS =>
                NULL;
        END CASE;
    END PROCESS;
END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY control_unit_tb IS
END ENTITY control_unit_tb;

ARCHITECTURE testbench OF control_unit_tb IS
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL opcode : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL zero : STD_LOGIC;

    SIGNAL pc_write, adr_src, mem_write, ir_write, reg_write : STD_LOGIC;
    SIGNAL result_src, alu_src_a, alu_src_b, imm_src : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL alu_control : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL finished : BOOLEAN := false;

    COMPONENT control_unit IS
        PORT (
            clk : IN STD_LOGIC;
            opcode : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
            funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
            zero : IN STD_LOGIC;

            pc_write : OUT STD_LOGIC;
            adr_src : OUT STD_LOGIC;
            mem_write : OUT STD_LOGIC;
            ir_write : OUT STD_LOGIC;
            result_src : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            alu_control : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            alu_src_a : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            alu_src_b : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            imm_src : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            reg_write : OUT STD_LOGIC
        );
    END COMPONENT;

BEGIN
    clk <= NOT clk AFTER 5 ns WHEN NOT finished ELSE
        '0';

    uut : control_unit
    PORT MAP(
        clk => clk,
        opcode => opcode,
        funct3 => funct3,
        funct7 => funct7,
        zero => zero,

        pc_write => pc_write,
        adr_src => adr_src,
        mem_write => mem_write,
        ir_write => ir_write,
        result_src => result_src,
        alu_control => alu_control,
        alu_src_a => alu_src_a,
        alu_src_b => alu_src_b,
        imm_src => imm_src,
        reg_write => reg_write
    );

    stimulus : PROCESS
    BEGIN
        -- lw instruction sequence (set opcode first)
        opcode <= "0000011"; -- lw opcode
        funct3 <= "000";
        funct7(5) <= '0';
        zero <= '0';
        WAIT FOR 1 ns;

        -- Should be in initial Fetch state
        ASSERT ir_write = '1' REPORT "Fetch: IRWrite should be asserted" SEVERITY error;
        ASSERT pc_write = '1' REPORT "Fetch: PCWrite should be asserted" SEVERITY error;

        -- Decode state
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT imm_src = "00" REPORT "Decode: ImmSrc should be 00 for I-type" SEVERITY error;

        -- MemAdr state
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT alu_src_a = "10" REPORT "MemAdr: ALUSrcA should be 10" SEVERITY error;
        ASSERT alu_src_b = "01" REPORT "MemAdr: ALUSrcB should be 01" SEVERITY error;

        -- MemRead state
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT adr_src = '1' REPORT "MemRead: AdrSrc should be 1" SEVERITY error;

        -- MemWB state
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT reg_write = '1' REPORT "MemWB: RegWrite should be asserted" SEVERITY error;
        ASSERT result_src = "01" REPORT "MemWB: ResultSrc should be 01" SEVERITY error;

        -- `add` instruction (R-type)
        opcode <= "0110011"; -- R-type opcode
        funct3 <= "000";
        funct7(5) <= '0';

        -- Back to Fetch
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        -- Decode
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        -- ExecuteR
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT alu_src_a = "10" REPORT "ExecuteR: ALUSrcA should be 10" SEVERITY error;
        ASSERT alu_src_b = "00" REPORT "ExecuteR: ALUSrcB should be 00" SEVERITY error;
        ASSERT alu_control = "000" REPORT "ExecuteR: ALUControl should be 000 for add" SEVERITY error;

        -- ALUWB
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT reg_write = '1' REPORT "ALUWB: RegWrite should be asserted" SEVERITY error;
        ASSERT result_src = "00" REPORT "ALUWB: ResultSrc should be 00" SEVERITY error;

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;