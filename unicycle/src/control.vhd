-- Control Unit
--
-- The Control Unit is responsible for computing control signals for most components of the CPU,
-- such as the ALU, Data Memory, Instruction Memory, Register File, Immediate Extender and various multiplexers.
--
-- Control Unit
--   Inputs:
--     opcode (7 bits: instruction[6:0]) => specifies the instruction to be executed.
--     funct3 (3 bits: instruction[14:12]) => further specifies the instruction to be executed.
--     funct7 (7 bits: instruction[31:25) => even further specifies the instruction to be executed.
--     zero (1 bit: ALU zero) => whether the ALU operation result was zero.
--   Outputs:
--     PCSrc (1 bit) => selector for the multiplexer that sources the next Program Couter value (PC+4 for sequential execution OR PCTarget for branches/jumps/calls).
--     ResultSrc (2 bits) => selector for the multiplexer that sources data to be written to the Register File (ALUResult OR Data Memory OR PCPlus4).
--     MemWrite (1 bit) => enabler for writing to the Data Memory.
--     ALUControl (3 bits) => selector for the operation the ALU must perform (add OR sub OR and OR xor OR slt OR sll OR srl).
--     ALUSrc (1 bit) => selector for the ALUSrcB multiplexer (ImmExt or RD2)
--     ImmSrc (2 bits) => selector for the Immediate Extension operation conditional on instruction type (I OR S OR B OR (J & U)).
--     RegWrite (1 bit) => enabler for writing to the Register File.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

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

ARCHITECTURE behavioral OF control_unit IS
    SIGNAL branch      : STD_LOGIC;
    SIGNAL jump        : STD_LOGIC;
    SIGNAL alu_op      : STD_LOGIC_VECTOR(1 DOWNTO 0);
BEGIN
    -- Decodes the `opcode` into the instruction type and subtype and sets the corresponding internal signals.
    main_decoder : PROCESS(opcode)
    BEGIN
        reg_write <= '0';
        imm_src <= "00";
        alu_src <= '0';
        mem_write <= '0';
        result_src <= "00";
        branch <= '0';
        alu_op <= "00";
        jump <= '0';

        CASE opcode IS
            WHEN "0110011" =>  -- 0x33 => R: Register-Register (add, sub, and, or, xor, sll, srl, sra, slt, sltu)
                reg_write <= '1';
                alu_op <= "10";

            WHEN "0010011" => -- 0x13 => I: Immediate Arithmetic (addi, andi, ori, xori, slti, sltiu, slli, srli, srai)
                reg_write <= '1';
                imm_src <= "00";
                alu_src <= '1';
                alu_op <= "10";

            WHEN "0000011" => -- 0x03 => I: Immediate Load (lw, lh, lb, lhu, lbu)
                reg_write <= '1';
                imm_src <= "00";
                alu_src <= '1';
                mem_write <= '0';
                result_src <= "01";
                alu_op <= "00";

            WHEN "1100111" => -- 0x67 => I: Immediate Jump (jalr)
                reg_write <= '1';
                imm_src <= "00";
                alu_src <= '1';
                jump <= '1';
                result_src <= "10";
                alu_op <= "00";

            WHEN "0100011" => -- 0x23 => S: Store (sw, sh, sb)
                imm_src <= "01";
                alu_src <= '1';
                mem_write <= '1';
                alu_op <= "00";

            WHEN "1100011" => -- 0x63 => B: Branch (beq, bne, blt, bltu, bgeu)
                imm_src <= "10";
                branch <= '1';
                alu_op <= "01";

            WHEN "1101111" => -- 0x6F => J: Jump (jal)
                reg_write <= '1';
                imm_src <= "11";
                jump <= '1';
                result_src <= "10";

            WHEN "0110111" => -- 0x37 => U: Upper Immediate (lui)
                reg_write <= '1';
                imm_src <= "11";
                result_src <= "11";

            WHEN "0010111" => -- 0x17 => U: Upper Immediate (auipc)
                reg_write <= '1';
                imm_src <= "11";
                alu_src <= '1';
                result_src <= "00";
                alu_op <= "00";

            WHEN OTHERS =>
                NULL;
        END CASE;
    END PROCESS;

    --- Decodes `alu_op`, `funct3` and `funct7` into `alu_control`, the operation the ALU must execute.
    alu_decoder : PROCESS(alu_op, funct3, funct7)
    BEGIN
        CASE alu_op IS
            WHEN "00" => -- add
                alu_control <= "000";

            WHEN "01" => -- sub
                alu_control <= "001";

            WHEN "10" => -- Operations that use `funct3` and `funct7`
                CASE funct3 IS
                    WHEN "000" => -- add/sub
                        IF funct7(5) = '1' THEN
                            alu_control <= "001"; -- sub
                        ELSE
                            alu_control <= "000"; -- add
                        END IF;

                    WHEN "111" => -- and
                        alu_control <= "010";

                    WHEN "110" => -- or
                        alu_control <= "011";

                    WHEN "100" => -- xor
                        alu_control <= "100";

                    WHEN "010" => -- slt
                        alu_control <= "101";

                    WHEN "001" => -- sll
                        alu_control <= "110";

                    WHEN "101" => -- srl/sra
                        alu_control <= "111";

                    WHEN OTHERS =>
                        alu_control <= "000";
                END CASE;

            WHEN OTHERS =>
                alu_control <= "000";
        END CASE;
    END PROCESS;

    pc_src <= (branch AND zero) OR jump;

END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY control_unit_tb IS
END ENTITY control_unit_tb;

ARCHITECTURE testbench OF control_unit_tb IS
    SIGNAL opcode      : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL funct3      : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL funct7      : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL zero        : STD_LOGIC;
    SIGNAL pc_src      : STD_LOGIC;
    SIGNAL result_src  : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL mem_write   : STD_LOGIC;
    SIGNAL alu_control : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL alu_src     : STD_LOGIC;
    SIGNAL imm_src     : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL reg_write   : STD_LOGIC;
    SIGNAL finished    : BOOLEAN := false;

    COMPONENT control_unit IS
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
    END COMPONENT;

BEGIN
    uut : control_unit
    PORT MAP(
        opcode      => opcode,
        funct3      => funct3,
        funct7      => funct7,
        zero        => zero,
        pc_src      => pc_src,
        result_src  => result_src,
        mem_write   => mem_write,
        alu_control => alu_control,
        alu_src     => alu_src,
        imm_src     => imm_src,
        reg_write   => reg_write
    );

    stimulus : PROCESS
    BEGIN
        opcode <= (OTHERS => '0');
        funct3 <= (OTHERS => '0');
        funct7 <= (OTHERS => '0');
        zero <= '0';
        WAIT FOR 10 ns;

        -- R (add)
        opcode <= "0110011";
        funct3 <= "000";
        funct7 <= "0000000";
        WAIT FOR 10 ns;
        REPORT "R (add): RegWrite=" & STD_LOGIC'IMAGE(reg_write) & " ALUControl=" & to_hstring(STD_LOGIC_VECTOR'("00000" & alu_control)) & " ALUSrc=" & STD_LOGIC'IMAGE(alu_src);
        ASSERT reg_write = '1' AND alu_control = "000" AND alu_src = '0' REPORT "R (add) failed" SEVERITY error;

        -- R (sub)
        opcode <= "0110011";
        funct3 <= "000";
        funct7 <= "0100000";
        WAIT FOR 10 ns;
        REPORT "R (sub): RegWrite=" & STD_LOGIC'IMAGE(reg_write) & " ALUControl=" & to_hstring(STD_LOGIC_VECTOR'("00000" & alu_control)) & " ALUSrc=" & STD_LOGIC'IMAGE(alu_src);
        ASSERT alu_control = "001" REPORT "R-type SUB failed" SEVERITY error;

        -- I (addi)
        opcode <= "0010011";
        funct3 <= "000";
        funct7 <= "0000000";
        WAIT FOR 10 ns;
        REPORT "I (addi) RegWrite=" & STD_LOGIC'IMAGE(reg_write) & " ALUSrc=" & STD_LOGIC'IMAGE(alu_src) & " ImmSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & imm_src));
        ASSERT reg_write = '1' AND alu_src = '1' AND imm_src = "00" REPORT "I (addi) failed" SEVERITY error;

        -- L (lw)
        opcode <= "0000011";
        funct3 <= "010";
        WAIT FOR 10 ns;
        REPORT "L (lw) ResultSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & result_src)) & " MemWrite=" & STD_LOGIC'IMAGE(mem_write);
        ASSERT result_src = "01" AND mem_write = '0' AND reg_write = '1' REPORT "L (lw) failed" SEVERITY error;

        -- S (sw)
        opcode <= "0100011";
        funct3 <= "010";
        WAIT FOR 10 ns;
        REPORT "S (sw) MemWrite=" & STD_LOGIC'IMAGE(mem_write) & " ImmSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & imm_src)) & " RegWrite=" & STD_LOGIC'IMAGE(reg_write);
        ASSERT mem_write = '1' AND imm_src = "01" AND reg_write = '0' REPORT "S (sw) failed" SEVERITY error;

        -- B (beq = true)
        opcode <= "1100011";
        funct3 <= "000";
        zero <= '1';
        WAIT FOR 10 ns;
        REPORT "B (beq = true) PCSrc=" & STD_LOGIC'IMAGE(pc_src) & " ImmSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & imm_src));
        ASSERT pc_src = '1' AND imm_src = "10" REPORT "B (beq = true) failed" SEVERITY error;

        -- B (beq = false)
        opcode <= "1100011";
        funct3 <= "000";
        zero <= '0';
        WAIT FOR 10 ns;
        REPORT "B (beq = false) PCSrc=" & STD_LOGIC'IMAGE(pc_src);
        ASSERT pc_src = '0' REPORT "B (beq = false) failed" SEVERITY error;

        -- J (jal)
        opcode <= "1101111";
        zero <= '0';
        WAIT FOR 10 ns;
        REPORT "J (jal) PCSrc=" & STD_LOGIC'IMAGE(pc_src) & " ResultSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & result_src)) & " ImmSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & imm_src));
        ASSERT pc_src = '1' AND result_src = "10" AND imm_src = "11" REPORT "J (jal) failed" SEVERITY error;

        -- U (lui)
        opcode <= "0110111";
        WAIT FOR 10 ns;
        REPORT "U (lui) ResultSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & result_src)) & " ImmSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & imm_src));
        ASSERT result_src = "11" AND imm_src = "11" REPORT "U (lui) failed" SEVERITY error;

        -- U (auipc)
        opcode <= "0010111";
        WAIT FOR 10 ns;
        REPORT "U (auipc) ALUSrc=" & STD_LOGIC'IMAGE(alu_src) & " ResultSrc=" & to_hstring(STD_LOGIC_VECTOR'("000000" & result_src));
        ASSERT alu_src = '1' AND result_src = "00" REPORT "U (auipc) failed" SEVERITY error;

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;