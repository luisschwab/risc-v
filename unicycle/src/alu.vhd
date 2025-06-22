LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY alu IS
    PORT (
        src_a      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        src_b      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        alu_control: IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        zero       : OUT STD_LOGIC
    );
END ENTITY alu;

ARCHITECTURE behavioral OF alu IS
    SIGNAL result_internal : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL src_a_signed : SIGNED(31 DOWNTO 0);
    SIGNAL src_b_signed : SIGNED(31 DOWNTO 0);

BEGIN
    src_a_signed <= SIGNED(src_a);
    src_b_signed <= SIGNED(src_b);

    alu_proc : PROCESS(src_a, src_b, alu_control, src_a_signed, src_b_signed)
    BEGIN
        CASE alu_control IS
            WHEN "000" => -- ADD
                result_internal <= STD_LOGIC_VECTOR(src_a_signed + src_b_signed);

            WHEN "001" => -- SUB
                result_internal <= STD_LOGIC_VECTOR(src_a_signed - src_b_signed);

            WHEN "010" => -- AND
                result_internal <= src_a AND src_b;

            WHEN "011" => -- OR
                result_internal <= src_a OR src_b;

            WHEN "100" => -- XOR
                result_internal <= src_a XOR src_b;

            WHEN "101" => -- SLT (Set Less Than)
                IF src_a_signed < src_b_signed THEN
                    result_internal <= x"00000001";
                ELSE
                    result_internal <= x"00000000";
                END IF;

            WHEN "110" => -- SLL (Shift Left Logical)
                result_internal <= STD_LOGIC_VECTOR(SHIFT_LEFT(UNSIGNED(src_a), TO_INTEGER(UNSIGNED(src_b(4 DOWNTO 0)))));

            WHEN "111" => -- SRL (Shift Right Logical)
                result_internal <= STD_LOGIC_VECTOR(SHIFT_RIGHT(UNSIGNED(src_a), TO_INTEGER(UNSIGNED(src_b(4 DOWNTO 0)))));

            WHEN OTHERS =>
                result_internal <= (OTHERS => '0');
        END CASE;
    END PROCESS;

    alu_result <= result_internal;
    zero <= '1' WHEN result_internal = x"00000000" ELSE '0';

END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY alu_tb IS
END ENTITY alu_tb;

ARCHITECTURE testbench OF alu_tb IS
    SIGNAL src_a      : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL src_b      : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL alu_control: STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL zero       : STD_LOGIC;
    SIGNAL finished   : BOOLEAN := false;

    COMPONENT alu IS
        PORT (
            src_a      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            src_b      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            alu_control: IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            zero       : OUT STD_LOGIC
        );
    END COMPONENT;

BEGIN
    uut : alu
    PORT MAP(
        src_a       => src_a,
        src_b       => src_b,
        alu_control => alu_control,
        alu_result  => alu_result,
        zero        => zero
    );

    stimulus : PROCESS
    BEGIN
        src_a <= (OTHERS => '0');
        src_b <= (OTHERS => '0');
        alu_control <= (OTHERS => '0');

        WAIT FOR 10 ns;

        -- ADD
        src_a <= x"00000010";  -- 16
        src_b <= x"00000020";  -- 32
        alu_control <= "000";  -- ADD
        WAIT FOR 10 ns;
        REPORT "ADD: 0x" & to_hstring(src_a) & " + 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000030" REPORT "ADD failed" SEVERITY error;
        ASSERT zero = '0' REPORT "Zero flag incorrect for ADD" SEVERITY error;

        -- SUB
        src_a <= x"00000050";  -- 80
        src_b <= x"00000020";  -- 32
        alu_control <= "001";  -- SUB
        WAIT FOR 10 ns;
        REPORT "SUB: 0x" & to_hstring(src_a) & " - 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000030" REPORT "SUB failed" SEVERITY error;
        ASSERT zero = '0' REPORT "Zero flag incorrect for SUB" SEVERITY error;

        -- SUB (zero)
        src_a <= x"12345678";
        src_b <= x"12345678";
        alu_control <= "001";  -- SUB
        WAIT FOR 10 ns;
        REPORT "SUB (zero): 0x" & to_hstring(src_a) & " - 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000000" REPORT "SUB zero failed" SEVERITY error;
        ASSERT zero = '1' REPORT "Zero flag not set" SEVERITY error;

        -- AND
        src_a <= x"F0F0F0F0";
        src_b <= x"0F0F0F0F";
        alu_control <= "010";  -- AND
        WAIT FOR 10 ns;
        REPORT "AND: 0x" & to_hstring(src_a) & " & 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000000" REPORT "AND failed" SEVERITY error;
        ASSERT zero = '1' REPORT "Zero flag incorrect for AND" SEVERITY error;

        -- OR
        src_a <= x"F0F0F0F0";
        src_b <= x"0F0F0F0F";
        alu_control <= "011";  -- OR
        WAIT FOR 10 ns;
        REPORT "OR: 0x" & to_hstring(src_a) & " | 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"FFFFFFFF" REPORT "OR failed" SEVERITY error;
        ASSERT zero = '0' REPORT "Zero flag incorrect for OR" SEVERITY error;

        -- XOR
        src_a <= x"AAAAAAAA";
        src_b <= x"55555555";
        alu_control <= "100";  -- XOR
        WAIT FOR 10 ns;
        REPORT "XOR: 0x" & to_hstring(src_a) & " ^ 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"FFFFFFFF" REPORT "XOR failed" SEVERITY error;
        ASSERT zero = '0' REPORT "Zero flag incorrect for XOR" SEVERITY error;

        -- SLT (true)
        src_a <= x"00000005";  -- 5
        src_b <= x"00000010";  -- 16
        alu_control <= "101";  -- SLT
        WAIT FOR 10 ns;
        REPORT "SLT (true): 0x" & to_hstring(src_a) & " < 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000001" REPORT "SLT (true) failed" SEVERITY error;
        ASSERT zero = '0' REPORT "Zero flag incorrect for SLT (true)" SEVERITY error;

        -- SLT (false)
        src_a <= x"00000020";  -- 32
        src_b <= x"00000010";  -- 16
        alu_control <= "101";  -- SLT
        WAIT FOR 10 ns;
        REPORT "SLT (false): 0x" & to_hstring(src_a) & " < 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000000" REPORT "SLT (false) failed" SEVERITY error;
        ASSERT zero = '1' REPORT "Zero flag incorrect for SLT (false)" SEVERITY error;

        -- SLT (negative operands)
        src_a <= x"FFFFFFFE";  -- -2
        src_b <= x"00000001";  -- 1
        alu_control <= "101";  -- SLT
        WAIT FOR 10 ns;
        REPORT "SLT: 0x" & to_hstring(src_a) & " < 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000001" REPORT "SLT negative failed" SEVERITY error;

        -- SLL
        src_a <= x"00000001";  -- 1
        src_b <= x"00000004";  -- Shift by 4
        alu_control <= "110";  -- SLL
        WAIT FOR 10 ns;
        REPORT "SLL: 0x" & to_hstring(src_a) & " << 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000010" REPORT "SLL failed" SEVERITY error;

        -- SLL (edge)
        src_a <= x"FFFFFFFF";
        src_b <= x"00000020";  -- Shift by 32 (should only use lower 5 bits = 0 (0000 0000 0000 0000 0000 0000 0010 0000))
        alu_control <= "110";  -- SLL
        WAIT FOR 10 ns;
        REPORT "SLL (edge): 0x" & to_hstring(src_a) & " << 0x" & to_hstring(src_b) & " = 0x" & to_hstring(alu_result) & " (shift by 0 since 5 lower bits = 0)";
        ASSERT alu_result = x"FFFFFFFF" REPORT "SLL (edge) failed" SEVERITY error;

        -- SRL
        src_a <= x"00000080";  -- 128
        src_b <= x"00000003";  -- Shift by 3
        alu_control <= "111";  -- SRL
        WAIT FOR 10 ns;
        REPORT "SRL: 0x" & to_hstring(src_a) & " >> " & INTEGER'IMAGE(TO_INTEGER(UNSIGNED(src_b(4 DOWNTO 0)))) & " = 0x" & to_hstring(alu_result);
        ASSERT alu_result = x"00000010" REPORT "SRL failed" SEVERITY error;

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;