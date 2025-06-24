-- Register File
--
-- 32 32-bit registers, used to fast temporary data storage.
-- Loading and storing to a register is much faster than loading and storing to Data Memory (same-cycle acess).
--
-- Register File:
--   Inputs:
--     CLK (1 bit) => clock signal for synchronization.
--     A1 (5 bits) => encodes the register to read from.
--     A2 (5 bits) => encodes the register to read from.
--     A3 (5 bits) => encodes the register to write to.
--     WD3 (32 bits) => data to write to the register encoded by `A3`.
--     WE3 (1 bit) => enabler for writing `WD3` to `A3`.
--   Outputs:
--     RD1 (32 bits) => the data currently written at address `A1`.
--     RD2 (32 bits) => the data currently written at address `A2`.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY register_file IS
    PORT (
        clk : IN STD_LOGIC;
        we3 : IN STD_LOGIC;
        a1  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
        a2  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
        a3  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
        wd3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        rd1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        rd2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY register_file;

ARCHITECTURE behavioral OF register_file IS
    TYPE reg_file IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL registers : reg_file := (OTHERS => (OTHERS => '0'));

BEGIN
    write_proc : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF we3 = '1' THEN
                -- Register x0 is hardwired to zero in RISC-V
                IF TO_INTEGER(UNSIGNED(a3)) /= 0 THEN
                    registers(TO_INTEGER(UNSIGNED(a3))) <= wd3;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    rd1 <= (OTHERS => '0') WHEN TO_INTEGER(UNSIGNED(a1)) = 0 ELSE
           registers(TO_INTEGER(UNSIGNED(a1)));

    rd2 <= (OTHERS => '0') WHEN TO_INTEGER(UNSIGNED(a2)) = 0 ELSE
           registers(TO_INTEGER(UNSIGNED(a2)));

END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY register_file_tb IS
END ENTITY register_file_tb;

ARCHITECTURE testbench OF register_file_tb IS
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL we3 : STD_LOGIC;
    SIGNAL a1  : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL a2  : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL a3  : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL wd3 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL rd1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL rd2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL finished : BOOLEAN := false;

    COMPONENT register_file IS
        PORT (
            clk : IN STD_LOGIC;
            we3 : IN STD_LOGIC;
            a1  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            a2  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            a3  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            wd3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd1 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd2 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    clk <= NOT clk AFTER 5 ns WHEN NOT finished ELSE '0';

    uut : register_file
    PORT MAP(
        clk => clk,
        we3 => we3,
        a1  => a1,
        a2  => a2,
        a3  => a3,
        wd3 => wd3,
        rd1 => rd1,
        rd2 => rd2
    );

    stimulus : PROCESS
    BEGIN
        we3 <= '0';
        wd3 <= (OTHERS => '0');
        a1 <= (OTHERS => '0');
        a2 <= (OTHERS => '0');
        a3 <= (OTHERS => '0');

        WAIT FOR 20 ns;

        -- x0 is always 0x00000000
        a1 <= "00000";
        a2 <= "00000";
        WAIT FOR 1 ns;
        REPORT "A1: 0x" & to_hstring(a1) & " => RD1: 0x" & to_hstring(rd1);
        REPORT "A2: 0x" & to_hstring(a2) & " => RD2: 0x" & to_hstring(rd2);
        ASSERT rd1 = x"00000000" REPORT "x0 rd1 not zero!" SEVERITY error;
        ASSERT rd2 = x"00000000" REPORT "x0 rd2 not zero!" SEVERITY error;

        -- Write to x0 is ignored
        a3 <= "00000";
        wd3 <= x"DEADBEEF";
        we3 <= '1';
        WAIT UNTIL rising_edge(clk);
        we3 <= '0';
        WAIT FOR 1 ns;
        a1 <= "00000";
        WAIT FOR 1 ns;
        REPORT "A1: 0x" & to_hstring(a1) & " => RD1: 0x" & to_hstring(rd1);
        ASSERT rd1 = x"00000000" REPORT "x0 modified!" SEVERITY error;

        -- Write to registers != x0
        FOR i IN 1 TO 10 LOOP
            a3 <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, 5));
            wd3 <= STD_LOGIC_VECTOR(TO_UNSIGNED(i * 16#1000#, 32));
            we3 <= '1';
            WAIT UNTIL rising_edge(clk);
            REPORT "A3: 0x" & to_hstring(a3) & " WD3: 0x" & to_hstring(wd3);
        END LOOP;
        we3 <= '0';

        -- Read from registers
        FOR i IN 1 TO 10 LOOP
            a1 <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, 5));
            WAIT FOR 1 ns;
            REPORT "A1: 0x" & to_hstring(STD_LOGIC_VECTOR(TO_UNSIGNED(i, 5))) & " => RD1: 0x" & to_hstring(rd1);
            ASSERT rd1 = STD_LOGIC_VECTOR(TO_UNSIGNED(i * 16#1000#, 32))
                REPORT "Register x" & INTEGER'IMAGE(i) & " read mismatch!" SEVERITY error;
        END LOOP;

        -- Dual read
        a1 <= "00001"; -- x1
        a2 <= "00101"; -- x5
        WAIT FOR 1 ns;
        REPORT "A1: 0x" & to_hstring(a1) & ", " & "A2: 0x" & to_hstring(a2) & " => RD1: 0x" & to_hstring(rd1) & ", " & "=> RD2: 0x" & to_hstring(rd2);
        ASSERT rd1 = x"00001000" REPORT "x1 dual read failed!" SEVERITY error;
        ASSERT rd2 = x"00005000" REPORT "x5 dual read failed!" SEVERITY error;

        -- Write enable
        a3 <= "01111"; -- x15
        wd3 <= x"CAFEBABE";
        we3 <= '0'; -- Write disabled
        WAIT UNTIL rising_edge(clk);
        a1 <= "01111";
        WAIT FOR 1 ns;
        REPORT "A3: 0x" & to_hstring(a3) & ", " & "WD3: 0x" & to_hstring(wd3) & " (WE3 = 0)";
        REPORT "A1: 0x" & to_hstring(a1) & " => RD1: 0x" & to_hstring(rd1);
        ASSERT rd1 = x"00000000" REPORT "Write occurred with WE=0!" SEVERITY error;
        -- Enable write
        we3 <= '1';
        WAIT UNTIL rising_edge(clk);
        we3 <= '0';
        WAIT FOR 1 ns;
        REPORT "A3: 0x" & to_hstring(a3) & ", " & "WD3: 0x" & to_hstring(wd3) & " (WE3 = 1)";
        REPORT "A1: 0x" & to_hstring(a1) & " => RD1: 0x" & to_hstring(rd1);
        ASSERT rd1 = x"CAFEBABE" REPORT "Write failed with WE=1!" SEVERITY error;

        -- All registers
        FOR i IN 1 TO 31 LOOP
            a3 <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, 5));
            wd3 <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, 32));
            we3 <= '1';
            WAIT UNTIL rising_edge(clk);
        END LOOP;
        we3 <= '0';

        -- Verify all registers
        FOR i IN 0 TO 31 LOOP
            a1 <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, 5));
            WAIT FOR 1 ns;
            IF i = 0 THEN
                ASSERT rd1 = x"00000000" REPORT "x0 not zero!" SEVERITY error;
            ELSE
                ASSERT rd1 = STD_LOGIC_VECTOR(TO_UNSIGNED(i, 32))
                    REPORT "x" & INTEGER'IMAGE(i) & " incorrect!" SEVERITY error;
            END IF;
        END LOOP;

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;