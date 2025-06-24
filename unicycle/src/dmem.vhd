-- Data Memory
--
-- The Data Memory is the RAM of the CPU, responsible for storing the `.data` segment: variables, the heap and the stack.
--
-- Data Memory:
--   Inputs:
--     CLK (1 bit) => clock signal for synchronization.
--     A (32 bits) => the address data must be written to or read from.
--     WD (32 bits) => the data that must be written to address `A`.
--     WE (1 bit) => wheter to enable writing data to it.
--   Outputs:
--     RD (32 bits) => the data currently written at address `A`.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE STD.TEXTIO.ALL;

ENTITY data_memory IS
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
END ENTITY data_memory;

ARCHITECTURE behavioral OF data_memory IS
    TYPE memory_array IS ARRAY (0 TO 2 ** ADDR_WIDTH - 1) OF STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);

    -- Helper function that parses a `.data` MIF file into the Data Memory.
    IMPURE FUNCTION load_memory RETURN memory_array IS
        VARIABLE temp_memory : memory_array;
        FILE mem_file : TEXT;
        VARIABLE line_buffer : LINE;
        VARIABLE file_status : FILE_OPEN_STATUS;
        VARIABLE addr_val : INTEGER := 0;
        VARIABLE data_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE char : CHARACTER;
        VARIABLE hex_char_count : INTEGER;
    BEGIN
        FOR i IN 0 TO 2 ** ADDR_WIDTH - 1 LOOP
            temp_memory(i) := (OTHERS => '0');
        END LOOP;

        file_open(file_status, mem_file, MIF_FILE, read_mode);

        IF file_status = open_ok THEN
            addr_val := 0;

            WHILE NOT endfile(mem_file) AND addr_val < 2 ** ADDR_WIDTH LOOP
                readline(mem_file, line_buffer);

                IF line_buffer'length >= 8 THEN
                    data_val := (OTHERS => '0');
                    hex_char_count := 0;

                    FOR i IN 1 TO line_buffer'length LOOP
                        IF hex_char_count < 8 THEN
                            char := line_buffer(i);
                            IF (char >= '0' AND char <= '9') OR
                                (char >= 'A' AND char <= 'F') OR
                                (char >= 'a' AND char <= 'f') THEN

                                data_val := data_val(27 DOWNTO 0) & "0000";

                                IF char >= '0' AND char <= '9' THEN
                                    data_val(3 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(CHARACTER'POS(char) - CHARACTER'POS('0'), 4));
                                ELSIF char >= 'A' AND char <= 'F' THEN
                                    data_val(3 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(CHARACTER'POS(char) - CHARACTER'POS('A') + 10, 4));
                                ELSIF char >= 'a' AND char <= 'f' THEN
                                    data_val(3 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(CHARACTER'POS(char) - CHARACTER'POS('a') + 10, 4));
                                END IF;

                                hex_char_count := hex_char_count + 1;
                            END IF;
                        END IF;
                    END LOOP;

                    IF hex_char_count = 8 THEN
                        temp_memory(addr_val) := data_val;
                        addr_val := addr_val + 1;
                    END IF;
                END IF;
            END LOOP;

            file_close(mem_file);
        END IF;

        RETURN temp_memory;
    END FUNCTION;

    SIGNAL memory : memory_array := load_memory;
    SIGNAL read_address : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');

BEGIN
    ram_proc : PROCESS (clk)
        VARIABLE word_addr : INTEGER;
    BEGIN
        IF rising_edge(clk) THEN
            word_addr := TO_INTEGER(UNSIGNED(addr(ADDR_WIDTH + 1 DOWNTO 2)));

            IF wr_en = '1' AND word_addr < 2 ** ADDR_WIDTH THEN
                memory(word_addr) <= wr_data;
            END IF;

            read_address <= addr(ADDR_WIDTH + 1 DOWNTO 2);
        END IF;
    END PROCESS;

    rd_data <= memory(TO_INTEGER(UNSIGNED(read_address)));

END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY data_memory_tb IS
END ENTITY data_memory_tb;

ARCHITECTURE testbench OF data_memory_tb IS
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL wr_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL wr_en : STD_LOGIC;
    SIGNAL rd_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL finished : BOOLEAN := false;

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

BEGIN
    clk <= NOT clk AFTER 5 ns WHEN NOT finished ELSE '0';

    uut : data_memory
    GENERIC MAP(
        ADDR_WIDTH => 10, -- 2^10 addresses
        DATA_WIDTH => 32, -- 32 bits
        MIF_FILE => "static/mif/data.mif"
    )
    PORT MAP(
        clk => clk,
        addr => addr,
        wr_data => wr_data,
        wr_en => wr_en,
        rd_data => rd_data
    );

    stimulus : PROCESS
    BEGIN
        addr <= (OTHERS => '0');
        wr_data <= (OTHERS => '0');
        wr_en <= '0';

        WAIT FOR 50 ns;

        -- Initial state of `data.mif`
        FOR i IN 0 TO (2 ** 10) LOOP
            addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32));
            WAIT UNTIL rising_edge(clk);
            WAIT FOR 1 ns;

            REPORT "data.mif " & "A: 0x" & to_hstring(STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32))) & " => RD: " & to_hstring(rd_data);
        END LOOP;

        FOR i IN 0 TO 7 LOOP
            addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32));
            WAIT UNTIL rising_edge(clk);
            WAIT FOR 1 ns;

            IF rd_data /= x"00000000" THEN
                REPORT "A: 0x" & to_hstring(STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32))) & " => RD: 0x" & to_hstring(rd_data);
            END IF;
        END LOOP;
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;

        addr <= x"00000014";
        wr_data <= x"DEADBEEF";
        wr_en <= '1';
        WAIT UNTIL rising_edge(clk);
        REPORT "A: 0x" & to_hstring(addr) & " WD: 0x" & to_hstring(wr_data);

        wr_en <= '0';
        WAIT FOR 1 ns;
        REPORT "W/R: wrote 0xDEADBEEF, read " & to_hstring(rd_data);
        ASSERT rd_data = x"DEADBEEF" REPORT "Write/read mismatch!" SEVERITY error;

        addr <= x"00000010";
        wr_data <= x"CAFEBABE";
        wr_en <= '1';
        WAIT UNTIL rising_edge(clk);
        REPORT "Data write: addr=0x" & to_hstring(addr) & " data=0x" & to_hstring(wr_data);

        wr_en <= '0';
        WAIT FOR 1 ns;
        REPORT "W/R test: wrote 0xCAFEBABE, read " & to_hstring(rd_data);
        ASSERT rd_data = x"CAFEBABE" REPORT "Write/read mismatch!" SEVERITY error;

        addr <= x"00000014";
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        REPORT "Persist test: first write is still " & to_hstring(rd_data);
        ASSERT rd_data = x"DEADBEEF" REPORT "Data not persistent!" SEVERITY error;

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;