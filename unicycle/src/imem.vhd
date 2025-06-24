-- Instruction Memory
--
-- The Instruction Memory is the ROM of the CPU, responsible for storing the `.text` segment: the program itself.
--
-- Instruction Memory:
--   Inputs:
--     A (32 bits) => the address to be read from.
--   Outputs:
--     RD (32 bits) => the data written at address `A`.

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE STD.TEXTIO.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;

ENTITY instruction_memory IS
    GENERIC (
        ADDR_WIDTH : INTEGER := 10;
        DATA_WIDTH : INTEGER := 32;
        MIF_FILE : STRING := "static/mif/text.mif"
    );
    PORT (
        addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        rd : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY instruction_memory;

ARCHITECTURE behavioral OF instruction_memory IS
    TYPE memory_array IS ARRAY (0 TO 2 ** ADDR_WIDTH - 1) OF STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
    SIGNAL memory : memory_array := (OTHERS => (OTHERS => '0'));
    SIGNAL max_loaded_addr : INTEGER := 0;
    SIGNAL init_done : STD_LOGIC := '0';

BEGIN
    init_process : PROCESS
        FILE mem_file : TEXT;
        VARIABLE line_buffer : LINE;
        VARIABLE file_status : FILE_OPEN_STATUS;
        VARIABLE line_count : INTEGER := 0;
        VARIABLE addr_val : INTEGER := 0;
        VARIABLE data_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE char : CHARACTER;
    BEGIN
        file_open(file_status, mem_file, MIF_FILE, read_mode);

        IF file_status = open_ok THEN
            addr_val := 0;

            WHILE NOT endfile(mem_file) LOOP
                readline(mem_file, line_buffer);
                line_count := line_count + 1;

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

                    -- Store it to Instruction Memory
                    IF addr_val < 2 ** ADDR_WIDTH THEN
                        memory(addr_val) <= data_val;

                        max_loaded_addr <= addr_val;

                        addr_val := addr_val + 1;
                    END IF;
                END IF;
            END LOOP;

            file_close(mem_file);
        ELSE
            REPORT "Failed to open MIF file: " & MIF_FILE SEVERITY error;
        END IF;

        init_done <= '1';
        WAIT;
    END PROCESS;

    PROCESS (addr, init_done)
        VARIABLE word_addr : INTEGER;
        VARIABLE addr_slice : STD_LOGIC_VECTOR(ADDR_WIDTH + 1 DOWNTO 0);
    BEGIN
        IF init_done = '1' THEN
            addr_slice := addr(ADDR_WIDTH + 1 DOWNTO 0);

            IF addr_slice = (addr_slice'RANGE => 'U') OR
                addr_slice = (addr_slice'RANGE => 'X') OR
                addr_slice = (addr_slice'RANGE => 'Z') OR
                addr_slice = (addr_slice'RANGE => '-') THEN
                rd <= (OTHERS => '0');
            ELSE
                word_addr := TO_INTEGER(UNSIGNED(addr_slice(ADDR_WIDTH + 1 DOWNTO 2)));
                IF word_addr < 2 ** ADDR_WIDTH THEN
                    rd <= memory(word_addr);
                ELSE
                    rd <= (OTHERS => '0');
                END IF;
            END IF;
        ELSE
            rd <= (OTHERS => '0');
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;

--------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE STD.TEXTIO.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;

ENTITY instruction_memory_tb IS
END ENTITY instruction_memory_tb;

ARCHITECTURE testbench OF instruction_memory_tb IS
    SIGNAL addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL rd : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL finished : BOOLEAN := false;

    TYPE INTEGER_ARRAY IS ARRAY (NATURAL RANGE <>) OF INTEGER;

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

    COMPONENT instruction_memory IS
        GENERIC (
            ADDR_WIDTH : INTEGER := 14;
            DATA_WIDTH : INTEGER := 32;
            MIF_FILE : STRING := "static/mif/text.mif"
        );
        PORT (
            addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            rd : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL max_addr : INTEGER;

BEGIN
    uut : instruction_memory
    GENERIC MAP(
        ADDR_WIDTH => 10,
        DATA_WIDTH => 32,
        MIF_FILE => "static/mif/text.mif"
    )
    PORT MAP(
        addr => addr,
        rd => rd
    );

    max_addr <= << SIGNAL uut.max_loaded_addr : INTEGER >> ;

    stimulus : PROCESS
    BEGIN
        WAIT FOR 30 ns;

        FOR i IN 0 TO max_addr + 2 LOOP
            addr <= STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32));
            WAIT FOR 10 ns;

            IF rd /= x"00000000" THEN
                REPORT "PC=0x" & to_hstring(STD_LOGIC_VECTOR(TO_UNSIGNED(i * 4, 32))) &
                    ": " & to_bstring(rd) & " (" & decode_instruction(rd) & ")";
            END IF;
        END LOOP;
        REPORT "Finished reading .text segment";

        finished <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;