LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

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

ARCHITECTURE behavioral OF adder IS
BEGIN
    result <= STD_LOGIC_VECTOR(UNSIGNED(a) + UNSIGNED(b));
END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY adder_tb IS
END ENTITY adder_tb;

ARCHITECTURE testbench OF adder_tb IS
    SIGNAL a_32, b_32, result_32 : STD_LOGIC_VECTOR(31 DOWNTO 0);

    SIGNAL a_8, b_8, result_8 : STD_LOGIC_VECTOR(7 DOWNTO 0);

    COMPONENT adder IS
        GENERIC (WIDTH : INTEGER := 32);
        PORT (
            a, b : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
            result : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    uut_32 : adder
    GENERIC MAP(WIDTH => 32)
    PORT MAP(
        a => a_32,
        b => b_32,
        result => result_32
    );

    uut_8 : adder
    GENERIC MAP(WIDTH => 8)
    PORT MAP(
        a => a_8,
        b => b_8,
        result => result_8
    );

    stimulus : PROCESS
    BEGIN
        REPORT "Testing 32-bit adder";

        a_32 <= x"00000005"; -- 5
        b_32 <= x"00000003"; -- 3
        WAIT FOR 10 ns;
        ASSERT result_32 = x"00000008" REPORT "32-bit: 5+3 failed" SEVERITY error;

        a_32 <= x"00000100";
        b_32 <= x"00000004";
        WAIT FOR 10 ns;
        ASSERT result_32 = x"00000104" REPORT "32-bit: PC+4 failed" SEVERITY error;

        a_32 <= x"00000100";
        b_32 <= x"00000010";
        WAIT FOR 10 ns;
        ASSERT result_32 = x"00000110" REPORT "32-bit: branch target failed" SEVERITY error;

        a_32 <= x"12345678";
        b_32 <= x"87654321";
        WAIT FOR 10 ns;
        ASSERT result_32 = x"99999999" REPORT "32-bit: large addition failed" SEVERITY error;

        a_32 <= x"FFFFFFFF";
        b_32 <= x"00000001";
        WAIT FOR 10 ns;
        ASSERT result_32 = x"00000000" REPORT "32-bit: overflow wrap failed" SEVERITY error;


        REPORT "Testing 8-bit adder";

        a_8 <= x"0F";
        b_8 <= x"01";
        WAIT FOR 10 ns;
        ASSERT result_8 = x"10" REPORT "8-bit: 15+1 failed" SEVERITY error;

        a_8 <= x"FF";
        b_8 <= x"01";
        WAIT FOR 10 ns;
        ASSERT result_8 = x"00" REPORT "8-bit: overflow wrap failed" SEVERITY error;

        REPORT "Adder tests passed";
        WAIT;
    END PROCESS stimulus;

END ARCHITECTURE testbench;