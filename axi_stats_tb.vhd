library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_stats_tb is
-- Port ( );
end axi_stats_tb;

architecture Simulation of axi_stats_tb is

    -- constants
    constant DATA_WIDTH : integer := 64;
    constant ADDR_WIDTH : integer := 8;

    -- Component definition

    component axi_stats
    port (
        aclk     : in  std_logic;
        aresetn  : in  std_logic;

        -- AXI Stream interface
        s_axis_tvalid : in  std_logic;
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tready : out std_logic;

        m_axis_tvalid : out std_logic;
        m_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tready : in  std_logic;

        -- AXI4-Lite interface
        s_axi_awaddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(31 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_araddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic
    );
    end component;

    -- -----------------
    -- Procedures
    -- -----------------

    -- Helper procedure for AXI-Lite write
    procedure axi_lite_write(
        signal awaddr  : out std_logic_vector;
        signal awvalid : inout std_logic;
        signal wdata   : out std_logic_vector;
        signal wvalid  : inout std_logic;
        signal awready : in std_logic;
        signal wready  : in std_logic;
        signal bvalid  : in std_logic;
        signal clock   : in std_logic;
        addr           : in std_logic_vector;
        data           : in std_logic_vector
    ) is
        variable aw_done : boolean := false;
        variable w_done  : boolean := false;
    begin
        -- Assert write address and write data
        awaddr  <= addr;
        awvalid <= '1';
        wdata   <= data;
        wvalid  <= '1';

        -- Wait for both write channel and address write channel to be done
        while not (aw_done and w_done) loop
            wait until rising_edge(clock);
            if awvalid = '1' and awready = '1' then
                awvalid <= '0';
                aw_done := true;
            end if;
            if wvalid = '1' and wready = '1' then
                wvalid <= '0';
                w_done := true;
            end if;
        end loop;

        -- Wait for response
        wait until rising_edge(clock) and bvalid = '1';
    end procedure;

    -- Helper procedure for AXI-Lite read
    procedure axi_lite_read(
        signal araddr  : out std_logic_vector;
        signal arvalid : inout std_logic;
        signal rdata   : in std_logic_vector;
        signal arready : in std_logic;
        signal rvalid  : in std_logic;
        signal clock   : in std_logic;
        addr           : in std_logic_vector;
        variable data  : out std_logic_vector(31 downto 0)
    ) is
        variable ar_done : boolean := false;
    begin
        -- Assert read address
        araddr  <= addr;
        arvalid <= '1';

        -- Wait for both read channel and address read channel to be done
        while not ar_done loop
            wait until rising_edge(clock);
            if arvalid = '1' and arready = '1' then
                arvalid <= '0';
                ar_done := true;
            end if;
        end loop;

        -- Wait for valid data
        wait until rising_edge(clock) and rvalid = '1';
        data := rdata;
    end procedure;

    -- Clock and reset
    signal clock  : std_logic := '1';
    signal reset  : std_logic := '1';

    -- AXI Stream
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others=>'0');
    signal s_axis_tready : std_logic;

    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m_axis_tready : std_logic := '1';

    -- AXI-Lite
    signal s_axi_awaddr  : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others=>'0');
    signal s_axi_awvalid : std_logic := '0';
    signal s_axi_awready : std_logic;

    signal s_axi_wdata   : std_logic_vector(31 downto 0) := (others=>'0');
    signal s_axi_wvalid  : std_logic := '0';
    signal s_axi_wready  : std_logic;

    signal s_axi_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_bvalid  : std_logic;
    signal s_axi_bready  : std_logic := '1';

    signal s_axi_araddr  : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others=>'0');
    signal s_axi_arvalid : std_logic := '0';
    signal s_axi_arready : std_logic;

    signal s_axi_rdata   : std_logic_vector(31 downto 0);
    signal s_axi_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_rvalid  : std_logic;
    signal s_axi_rready  : std_logic := '1';

begin
    -- Clock and reset
    clock <= not clock after 1 ns;
    reset <= '0', '1' after 6 ns;

    -- DUT instantiation WITH SIGNALS
    DUT: axi_stats port map (
            aclk     => clock,
            aresetn  => reset,

            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tready => s_axis_tready,

            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tready => m_axis_tready,

            s_axi_awaddr  => s_axi_awaddr,
            s_axi_awvalid => s_axi_awvalid,
            s_axi_awready => s_axi_awready,

            s_axi_wdata   => s_axi_wdata,
            s_axi_wvalid  => s_axi_wvalid,
            s_axi_wready  => s_axi_wready,

            s_axi_bresp   => s_axi_bresp,
            s_axi_bvalid  => s_axi_bvalid,
            s_axi_bready  => s_axi_bready,

            s_axi_araddr  => s_axi_araddr,
            s_axi_arvalid => s_axi_arvalid,
            s_axi_arready => s_axi_arready,

            s_axi_rdata   => s_axi_rdata,
            s_axi_rresp   => s_axi_rresp,
            s_axi_rvalid  => s_axi_rvalid,
            s_axi_rready  => s_axi_rready
        );

    -- Simulation process
    simulation_process: process
        -- Variables to store read results
        variable total_cycles : std_logic_vector(31 downto 0);
        variable packet_count : std_logic_vector(31 downto 0);
        variable idle_cycles  : std_logic_vector(31 downto 0);
        variable burst_count  : std_logic_vector(31 downto 0);
        variable max_burst    : std_logic_vector(31 downto 0);
        variable min_gap      : std_logic_vector(31 downto 0);
        variable max_gap      : std_logic_vector(31 downto 0);
        variable gap_events   : std_logic_vector(31 downto 0);
        variable sum_burst    : std_logic_vector(31 downto 0);
        variable sum_gaps     : std_logic_vector(31 downto 0);
    begin
        -- wait for reset
        wait until reset = '1';

        ----------------------------------------------------------------
        -- AXI STREAM (no stats)
        ----------------------------------------------------------------

        -- Send AXI stream packets without stats_en, they should be transparently sent
        s_axis_tvalid <= '1';
        s_axis_tdata  <= x"1111111111111111";
        wait for 2 ns;

        s_axis_tvalid <= '0';
        wait for 2 ns;

        s_axis_tvalid <= '1';
        s_axis_tdata  <= x"2222222222222222";
        wait for 2 ns;

        s_axis_tvalid <= '0';
        wait for 2 ns;

        ----------------------------------------------------------------
        -- AXI-LITE WRITE ENABLE
        ----------------------------------------------------------------

        axi_lite_write(s_axi_awaddr, s_axi_awvalid, s_axi_wdata, s_axi_wvalid,
               s_axi_awready, s_axi_wready, s_axi_bvalid, clock, x"00", x"00000001");

        ----------------------------------------------------------------
        -- AXI STREAM (with stats)
        ----------------------------------------------------------------

        -- Send 5 AXI stream packets with gaps
        s_axis_tvalid <= '1';
        s_axis_tdata  <= x"1111111111111111";
        wait for 2 ns;
        s_axis_tdata  <= x"2222222222222222";
        wait for 2 ns;
        s_axis_tvalid <= '0';
        wait for 2 ns;
        s_axis_tvalid <= '1';
        s_axis_tdata  <= x"3333333333333333";
        wait for 2 ns;
        s_axis_tvalid <= '0';
        wait for 2 ns;
        s_axis_tvalid <= '1';
        s_axis_tdata  <= x"4444444444444444";
        wait for 2 ns;


        ----------------------------------------------------------------
        -- AXI-LITE WRITE DISABLE
        ----------------------------------------------------------------

        axi_lite_write(s_axi_awaddr, s_axi_awvalid, s_axi_wdata, s_axi_wvalid,
               s_axi_awready, s_axi_wready, s_axi_bvalid, clock, x"00", x"00000000");


        ----------------------------------------------------------------
        -- AXI-LITE READ: dump stats registers
        ----------------------------------------------------------------

        -- Read total_cycles (0x04)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"04", total_cycles);

        -- Read packet_count (0x08)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"08", packet_count);

        -- Read idle_cycles (0x0C)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"0C", idle_cycles);

        -- Read burst_count (0x10)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"10", burst_count);

        -- Read max_burst (0x14)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"14", max_burst);

        -- Read min_gap (0x14)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"18", min_gap);

        -- Read max_gap (0x1C)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"1C", max_gap);

        -- Read gap_events (0x20)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"20", gap_events);

        -- Read sum_burst (0x24)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"24", sum_burst);

        -- Read sum_gaps (0x28)
        axi_lite_read(s_axi_araddr, s_axi_arvalid, s_axi_rdata,
              s_axi_arready, s_axi_rvalid, clock,
              x"28", sum_gaps);

        -- Print all stats in a simple report
        report "=== AXI Stats ===";
        report "Total cycles  : " & integer'image(to_integer(unsigned(total_cycles)));
        report "Packet count  : " & integer'image(to_integer(unsigned(packet_count)));
        report "Idle cycles   : " & integer'image(to_integer(unsigned(idle_cycles)));
        report "Burst count   : " & integer'image(to_integer(unsigned(burst_count)));
        report "Max burst     : " & integer'image(to_integer(unsigned(max_burst)));
        report "Min gap       : " & integer'image(to_integer(unsigned(min_gap)));
        report "Max gap       : " & integer'image(to_integer(unsigned(max_gap)));
        report "Gap events    : " & integer'image(to_integer(unsigned(gap_events)));
        report "Sum burst     : " & integer'image(to_integer(unsigned(sum_burst)));
        report "Sum gaps      : " & integer'image(to_integer(unsigned(sum_gaps)));
        report "=================";

        wait;
    end process;
end Simulation;