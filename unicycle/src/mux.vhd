LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

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

ARCHITECTURE behavioral OF mux2 IS
BEGIN
    y <= d0 WHEN sel = '0' ELSE
        d1;
END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY mux3 IS
    GENERIC (
        WIDTH : INTEGER := 32
    );
    PORT (
        d0 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        d1 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        d2 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        sel : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        y : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
    );
END ENTITY mux3;

ARCHITECTURE behavioral OF mux3 IS
BEGIN
    WITH sel SELECT y <=
        d0 WHEN "00",
        d1 WHEN "01",
        d2 WHEN "10",
        d2 WHEN OTHERS;
END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY mux_tb IS
END ENTITY mux_tb;

ARCHITECTURE testbench OF mux_tb IS
    SIGNAL d0_32, d1_32, d2_32, y2_32, y3_32 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL sel_1 : STD_LOGIC;
    SIGNAL sel_2 : STD_LOGIC_VECTOR(1 DOWNTO 0);

    COMPONENT mux2 IS
        GENERIC (WIDTH : INTEGER := 32);
        PORT (
            d0, d1 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
            sel : IN STD_LOGIC;
            y : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT mux3 IS
        GENERIC (WIDTH : INTEGER := 32);
        PORT (
            d0, d1, d2 : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
            sel : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            y : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    uut_mux2 : mux2
    GENERIC MAP(WIDTH => 32)
    PORT MAP(
        d0 => d0_32,
        d1 => d1_32,
        sel => sel_1,
        y => y2_32
    );

    uut_mux3 : mux3
    GENERIC MAP(WIDTH => 32)
    PORT MAP(
        d0 => d0_32,
        d1 => d1_32,
        d2 => d2_32,
        sel => sel_2,
        y => y3_32
    );

    stimulus : PROCESS
    BEGIN
        d0_32 <= x"AAAAAAAA";
        d1_32 <= x"BBBBBBBB";
        d2_32 <= x"CCCCCCCC";

        REPORT "Testing mux2";
        sel_1 <= '0';
        WAIT FOR 10 ns;
        ASSERT y2_32 = x"AAAAAAAA" REPORT "mux2 sel=0 failed" SEVERITY error;

        sel_1 <= '1';
        WAIT FOR 10 ns;
        ASSERT y2_32 = x"BBBBBBBB" REPORT "mux2 sel=1 failed" SEVERITY error;

        REPORT "Testing mux3";
        sel_2 <= "00";
        WAIT FOR 10 ns;
        ASSERT y3_32 = x"AAAAAAAA" REPORT "mux3 sel=00 failed" SEVERITY error;

        sel_2 <= "01";
        WAIT FOR 10 ns;
        ASSERT y3_32 = x"BBBBBBBB" REPORT "mux3 sel=01 failed" SEVERITY error;

        sel_2 <= "10";
        WAIT FOR 10 ns;
        ASSERT y3_32 = x"CCCCCCCC" REPORT "mux3 sel=10 failed" SEVERITY error;

        WAIT;
    END PROCESS stimulus;

END ARCHITECTURE testbench;