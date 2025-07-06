-- Register
--
-- A generic register, used in this implementation for non-architectural state elements.
-- I could simply copy the existing `PC Register` implementation, but made this separate for clarity.
--
-- Register:
--   Inputs:
--     CLK (1 bit) => clock signal for synchronization.
--     RESET (1 bit) => asynchronous reset signal.
--     EN (1 bit) => enable signal (optional, controlled by HAS_ENABLE generic).
--     D (WIDTH bits) => data input to be stored.
--   Outputs:
--     Q (WIDTH bits) => stored data output.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY generic_register IS
    GENERIC (
        WIDTH : INTEGER := 32;
        HAS_ENABLE : BOOLEAN := FALSE;
        RESET_VALUE : STD_LOGIC_VECTOR := "00000000000000000000000000000000"
    );
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        en : IN STD_LOGIC := '1';
        d : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
        q : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
    );
END ENTITY generic_register;

ARCHITECTURE behavioral OF generic_register IS
    SIGNAL reg_data : STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
BEGIN
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            reg_data <= RESET_VALUE(RESET_VALUE'LENGTH - WIDTH TO RESET_VALUE'LENGTH - 1);
        ELSIF rising_edge(clk) THEN
            IF NOT HAS_ENABLE OR en = '1' THEN
                reg_data <= d;
            END IF;
        END IF;
    END PROCESS;

    q <= reg_data;
END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY generic_register_tb IS
END ENTITY generic_register_tb;

ARCHITECTURE testbench OF generic_register_tb IS
    SIGNAL clk, reset : STD_LOGIC := '0';
    SIGNAL en : STD_LOGIC := '1';
    SIGNAL d, q_no_en, q_with_en : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL finished : BOOLEAN := false;

    COMPONENT generic_register IS
        GENERIC (
            WIDTH : INTEGER := 32;
            HAS_ENABLE : BOOLEAN := FALSE;
            RESET_VALUE : STD_LOGIC_VECTOR := "00000000000000000000000000000000"
        );
        PORT (
            clk : IN STD_LOGIC;
            reset : IN STD_LOGIC;
            en : IN STD_LOGIC := '1';
            d : IN STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
            q : OUT STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    -- Register w/o enable
    reg_no_enable : generic_register
    GENERIC MAP(
        WIDTH => 32,
        HAS_ENABLE => FALSE,
        RESET_VALUE => x"00000000"
    )
    PORT MAP(
        clk => clk,
        reset => reset,
        d => d,
        q => q_no_en
    );

    -- Register w/ enable
    reg_with_enable : generic_register
    GENERIC MAP(
        WIDTH => 32,
        HAS_ENABLE => TRUE,
        RESET_VALUE => x"FFFFFFFF"
    )
    PORT MAP(
        clk => clk,
        reset => reset,
        en => en,
        d => d,
        q => q_with_en
    );

    clk <= NOT clk AFTER 5 ns WHEN NOT finished ELSE '0';

    stimulus : PROCESS
    BEGIN
        -- Reset
        reset <= '1';
        d <= x"12345678";
        en <= '1';
        WAIT FOR 10 ns;
        ASSERT q_no_en = x"00000000" REPORT "Register without enable not reset correctly" SEVERITY error;
        ASSERT q_with_en = x"FFFFFFFF" REPORT "Register with enable not reset correctly" SEVERITY error;

        -- Normal operation
        reset <= '0';
        d <= x"DEADBEEF";
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT q_no_en = x"DEADBEEF" REPORT "Register without enable update failed" SEVERITY error;
        ASSERT q_with_en = x"DEADBEEF" REPORT "Register with enable update failed" SEVERITY error;

        -- Enable functionality
        en <= '0';
        d <= x"CAFEBABE";
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT q_no_en = x"CAFEBABE" REPORT "Register without enable should always update" SEVERITY error;
        ASSERT q_with_en = x"DEADBEEF" REPORT "Register with enable should not update when disabled" SEVERITY error;

        -- Re-enable and
        en <= '1';
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT q_with_en = x"CAFEBABE" REPORT "Register with enable failed to update when re-enabled" SEVERITY error;

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;