-- Memory
--
-- The Multicycle architecture uses a unified memory for both `data` and `text` segments,
-- since access to these regions ia made on different cycles. This is cheaper and less
-- complex than the Unicycle approach with separate memories for each segment.
--
-- Unified Memory:
--   Inputs:
--     CLK (1 bit) => clock signal for synchronization.
--     A (32 bits) => the address to be read from or written to.
--     WD (32 bits) => the data that must be written to address `A`.
--     WE (1 bit) => whether to enable writing data to memory.
--   Outputs:
--     RD (32 bits) => the data currently stored at address `A`.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE STD.TEXTIO.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;

ENTITY memory IS
    GENERIC (
        ADDR_WIDTH : INTEGER := 12;
        DATA_WIDTH : INTEGER := 32;
        TEXT_MIF_FILE : STRING := "static/mif/text.mif";
        DATA_MIF_FILE : STRING := "static/mif/data.mif"
    );
    PORT (
        clk : IN STD_LOGIC;
        addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        wr_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY memory;

ARCHITECTURE behavioral OF memory IS
    TYPE memory_array IS ARRAY (0 TO 2 ** ADDR_WIDTH - 1) OF STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);

    CONSTANT TEXT_BASE_ADDR : UNSIGNED(31 DOWNTO 0) := x"00000000";
    CONSTANT DATA_BASE_ADDR : UNSIGNED(31 DOWNTO 0) := x"10010000";

    -- Helper function that parses a `.text` MIF file into the TEXT address space.
    IMPURE FUNCTION load_text_memory RETURN memory_array IS
        VARIABLE temp_memory : memory_array;
        FILE mem_file : TEXT;
        VARIABLE line_buffer : LINE;
        VARIABLE file_status : FILE_OPEN_STATUS;
        VARIABLE addr_val : INTEGER := 0;
        VARIABLE data_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE char : CHARACTER;
    BEGIN
        FOR i IN 0 TO 2 ** ADDR_WIDTH - 1 LOOP
            temp_memory(i) := (OTHERS => '0');
        END LOOP;

        file_open(file_status, mem_file, TEXT_MIF_FILE, read_mode);

        IF file_status = open_ok THEN
            addr_val := 0;

            WHILE NOT endfile(mem_file) AND addr_val < 2 ** ADDR_WIDTH LOOP
                readline(mem_file, line_buffer);

                IF line_buffer'length >= 8 THEN
                    data_val := (OTHERS => '0');
                    FOR i IN 1 TO 8 LOOP
                        IF i <= line_buffer'length THEN
                            char := line_buffer(i);
                            data_val := data_val(27 DOWNTO 0) & "0000";
                            IF char >= '0' AND char <= '9' THEN
                                data_val(3 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(CHARACTER'POS(char) - CHARACTER'POS('0'), 4));
                            ELSIF char >= 'A' AND char <= 'F' THEN
                                data_val(3 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(CHARACTER'POS(char) - CHARACTER'POS('A') + 10, 4));
                            ELSIF char >= 'a' AND char <= 'f' THEN
                                data_val(3 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(CHARACTER'POS(char) - CHARACTER'POS('a') + 10, 4));
                            END IF;
                        END IF;
                    END LOOP;

                    temp_memory(addr_val) := data_val;
                    addr_val := addr_val + 1;
                END IF;
            END LOOP;

            file_close(mem_file);
        ELSE
            REPORT "Failed to open text MIF file: " & TEXT_MIF_FILE SEVERITY error;
        END IF;

        RETURN temp_memory;
    END FUNCTION;

    -- Helper function that parses a `.data` MIF file into the DATA address space.
    IMPURE FUNCTION load_data_memory RETURN memory_array IS
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

        file_open(file_status, mem_file, DATA_MIF_FILE, read_mode);

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

    SIGNAL text_memory : memory_array := load_text_memory;
    SIGNAL data_memory : memory_array := load_data_memory;
    SIGNAL is_data_region : STD_LOGIC := '0';
    SIGNAL read_address : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');

BEGIN
    addr_decode_proc : PROCESS (addr)
        VARIABLE word_addr : INTEGER;
        VARIABLE offset_addr : UNSIGNED(31 DOWNTO 0);
        VARIABLE addr_unsigned : UNSIGNED(31 DOWNTO 0);
    BEGIN
        addr_unsigned := UNSIGNED(addr);

        -- `data` region
        IF addr_unsigned >= DATA_BASE_ADDR THEN
            is_data_region <= '1';
            offset_addr := addr_unsigned - DATA_BASE_ADDR;
            word_addr := TO_INTEGER(offset_addr(ADDR_WIDTH + 1 DOWNTO 2));

            IF word_addr >= 0 AND word_addr < 2 ** ADDR_WIDTH THEN
                read_address <= STD_LOGIC_VECTOR(TO_UNSIGNED(word_addr, ADDR_WIDTH));
            ELSE
                read_address <= (OTHERS => '0');
            END IF;
        ELSE -- `text` region
            is_data_region <= '0';
            word_addr := TO_INTEGER(addr_unsigned(ADDR_WIDTH + 1 DOWNTO 2));
            IF word_addr >= 0 AND word_addr < 2 ** ADDR_WIDTH THEN
                read_address <= STD_LOGIC_VECTOR(TO_UNSIGNED(word_addr, ADDR_WIDTH));
            ELSE
                read_address <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;

    -- Write process (clocked)
    write_proc : PROCESS (clk)
        VARIABLE word_addr : INTEGER;
        VARIABLE offset_addr : UNSIGNED(31 DOWNTO 0);
        VARIABLE addr_unsigned : UNSIGNED(31 DOWNTO 0);
    BEGIN
        IF rising_edge(clk) THEN
            addr_unsigned := UNSIGNED(addr);
            IF addr_unsigned >= DATA_BASE_ADDR AND wr_en = '1' THEN
                offset_addr := addr_unsigned - DATA_BASE_ADDR;
                word_addr := TO_INTEGER(offset_addr(ADDR_WIDTH + 1 DOWNTO 2));
                IF word_addr < 2 ** ADDR_WIDTH THEN
                    data_memory(word_addr) <= wr_data;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Output data based on address region
    rd_data <= data_memory(TO_INTEGER(UNSIGNED(read_address))) WHEN is_data_region = '1' ELSE
        text_memory(TO_INTEGER(UNSIGNED(read_address)));

END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY memory_tb IS
END ENTITY memory_tb;

ARCHITECTURE testbench OF memory_tb IS
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL wr_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL wr_en : STD_LOGIC;
    SIGNAL rd_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL finished : BOOLEAN := false;

    FUNCTION decode_instruction(instr : STD_LOGIC_VECTOR(31 DOWNTO 0)) RETURN STRING IS
        VARIABLE opcode : STD_LOGIC_VECTOR(6 DOWNTO 0);
    BEGIN
        IF instr = x"00000000" THEN
            RETURN "nop";
        END IF;

        opcode := instr(6 DOWNTO 0);
        CASE opcode IS
            WHEN "0110111" => RETURN "lui";
            WHEN "0010011" => RETURN "addi";
            WHEN "0000011" => RETURN "lw";
            WHEN "0110011" => RETURN "add";
            WHEN "1101111" => RETURN "jal";
            WHEN OTHERS => RETURN "other";
        END CASE;
    END FUNCTION;

    COMPONENT memory IS
        GENERIC (
            ADDR_WIDTH : INTEGER := 10;
            DATA_WIDTH : INTEGER := 32;
            TEXT_MIF_FILE : STRING := "static/mif/text.mif";
            DATA_MIF_FILE : STRING := "static/mif/data.mif"
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
    clk <= NOT clk AFTER 5 ns WHEN NOT finished ELSE
        '0';

    uut : memory
    GENERIC MAP(
        ADDR_WIDTH => 10,
        DATA_WIDTH => 32,
        TEXT_MIF_FILE => "static/mif/text.mif",
        DATA_MIF_FILE => "static/mif/data.mif"
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

        -- Test reading from text memory (instructions)
        FOR i IN 0 TO 7 LOOP
            addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32));
            WAIT UNTIL rising_edge(clk);
            WAIT FOR 1 ns;

            IF rd_data /= x"00000000" THEN
                REPORT "text.mif " & "A: 0x" & to_hstring(STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32))) & " => RD: " & to_hstring(rd_data) & " (" & decode_instruction(rd_data) & ")";
            END IF;
        END LOOP;

        -- Test reading from data memory
        FOR i IN 0 TO 7 LOOP
            addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(16#10010000# + i * 4, 32));
            WAIT UNTIL rising_edge(clk);
            WAIT FOR 1 ns;

            IF rd_data /= x"00000000" THEN
                REPORT "data.mif " & "A: 0x" & to_hstring(STD_LOGIC_VECTOR(TO_UNSIGNED(16#10010000# + i * 4, 32))) & " => RD: " & to_hstring(rd_data);
            END IF;
        END LOOP;

        -- Test writing to data memory
        addr <= x"10010020";
        wr_data <= x"DEADBEEF";
        wr_en <= '1';
        WAIT UNTIL rising_edge(clk);
        REPORT "A: 0x" & to_hstring(addr) & " WD: 0x" & to_hstring(wr_data);

        wr_en <= '0';
        WAIT FOR 1 ns;
        REPORT "W/R: wrote 0xDEADBEEF, read " & to_hstring(rd_data);
        ASSERT rd_data = x"DEADBEEF" REPORT "Write/read mismatch!" SEVERITY error;

        addr <= x"10010024";
        wr_data <= x"CAFEBABE";
        wr_en <= '1';
        WAIT UNTIL rising_edge(clk);
        REPORT "Data write: addr=0x" & to_hstring(addr) & " data=0x" & to_hstring(wr_data);

        wr_en <= '0';
        WAIT FOR 1 ns;
        REPORT "W/R test: wrote 0xCAFEBABE, read " & to_hstring(rd_data);
        ASSERT rd_data = x"CAFEBABE" REPORT "Write/read mismatch!" SEVERITY error;

        -- Verify first write is still there
        addr <= x"10010020";
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        REPORT "Persist test: first write is still " & to_hstring(rd_data);
        ASSERT rd_data = x"DEADBEEF" REPORT "Data not persistent!" SEVERITY error;

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;