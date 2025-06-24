-- Program Counter Register
--
-- The Program Counter stores the address of the instruction to be executed. On the rising edge of the clock signal, PC = PCNext.
--
-- Program Counter Register:
--   Inputs:
--     CLK (1 bit) => clock signal for synchronization.
--     PCNext (32 bits) => the address of the next instruction to be executed.
--   Outputs:
--     PC (32 bits) => the address of the current instruction to be executed.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pc_register IS
    PORT (
        clk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        pc_next : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY pc_register;

ARCHITECTURE behavioral OF pc_register IS
    SIGNAL pc_reg : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
BEGIN
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            pc_reg <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            pc_reg <= pc_next;
        END IF;
    END PROCESS;

    pc <= pc_reg;
END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pc_register_tb IS
END ENTITY pc_register_tb;

ARCHITECTURE testbench OF pc_register_tb IS
    SIGNAL clk, reset : STD_LOGIC := '0';
    SIGNAL pc_next, pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL finished : BOOLEAN := false;

    COMPONENT pc_register IS
        PORT (
            clk, reset : IN STD_LOGIC;
            pc_next : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            pc : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

BEGIN
    uut : pc_register
    PORT MAP(
        clk => clk,
        reset => reset,
        pc_next => pc_next,
        pc => pc
    );

    clk_process : PROCESS
    BEGIN
        WHILE NOT finished LOOP
            clk <= '0';
            WAIT FOR 5 ns;
            clk <= '1';
            WAIT FOR 5 ns;
        END LOOP;
        WAIT;
    END PROCESS;

    stimulus : PROCESS
    BEGIN
        reset <= '1';
        pc_next <= x"12345678";
        WAIT FOR 10 ns;
        ASSERT pc = x"00000000" REPORT "PC not reset while reset active" SEVERITY error;

        reset <= '0';
        WAIT FOR 1 ns;
        ASSERT pc = x"00000000" REPORT "PC changed immediately after reset release" SEVERITY error;

        pc_next <= x"00000004";
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT pc = x"00000004" REPORT "PC update 1 failed" SEVERITY error;

        pc_next <= x"00000008";
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT pc = x"00000008" REPORT "PC update 2 failed" SEVERITY error;

        pc_next <= x"00000100";
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        ASSERT pc = x"00000100" REPORT "PC update 3 failed" SEVERITY error;

        reset <= '1';
        WAIT FOR 5 ns;
        ASSERT pc = x"00000000" REPORT "PC reset during operation failed" SEVERITY error;
        reset <= '0';

        finished <= true;
        WAIT FOR 10 ns;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;