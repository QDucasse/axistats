-- ============================================================================
-- File: axi_stats.vhd
-- Description: AXI stats module
--
-- Copyright (C) 2026 Quentin Ducasse
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- AXI stats
--
-- Module that derives stats from an incoming AXI stream:
--   global idle cycles,
--   gap details,
--   burst details,
--
-- Presents an AXI-Lite interface to activate the module and read the stats:
--   0x0: Control (bit 0 = stats enable, bit 1 = reset)
--   0x4: Total cycles [31:0]
--   0x8: Transfer count [31:0]
--   0xC: Idle cycles [31:0]
--   0x10: Burst count [31:0]
--   0x14: Max burst [31:0]
--   0x18: Min gap [31:0]
--   0x1C: Max gap [31:0]
--   0x20: Gap events [31:0]
--   0x24: Sum burst [31:0]
--   0x28: Sum gaps [31:0]

entity axi_stats is
    generic (
        DATA_WIDTH : integer := 64;
        COUNTER_W  : integer := 64;
        ADDR_WIDTH : integer := 8
    );
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
        -- write address channel
        s_axi_awaddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        -- write data channel
        s_axi_wdata   : in  std_logic_vector(31 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        -- write response channel
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        -- read address channel
        s_axi_araddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        -- read data channel
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic
    );
end entity;

architecture Behavioral of axi_stats is

    -- Enable/Reset
    signal stats_en      : std_logic := '0';
    signal stats_reset   : std_logic := '0';

    -- Reset handle, AXI write capture
    signal stats_reset_req   : std_logic := '0';

    -- Stats for the AXI transfer
    signal total_cycles   : unsigned(COUNTER_W-1 downto 0);
    signal transfer_count : unsigned(COUNTER_W-1 downto 0);
    signal idle_cycles    : unsigned(COUNTER_W-1 downto 0);

    signal gap_counter   : unsigned(COUNTER_W-1 downto 0);
    signal min_gap       : unsigned(COUNTER_W-1 downto 0);
    signal max_gap       : unsigned(COUNTER_W-1 downto 0);
    signal sum_gaps      : unsigned(COUNTER_W-1 downto 0);
    signal gap_events    : unsigned(COUNTER_W-1 downto 0);

    signal burst_len     : unsigned(COUNTER_W-1 downto 0);
    signal burst_count   : unsigned(COUNTER_W-1 downto 0);
    signal max_burst     : unsigned(COUNTER_W-1 downto 0);
    signal sum_burst     : unsigned(COUNTER_W-1 downto 0);

    signal consecutive_transfer_cycles : unsigned(COUNTER_W-1 downto 0);

    signal prev_valid        : std_logic;
    signal has_seen_transfer : std_logic;

    signal transfer : std_logic;
    signal ready    : std_logic;

    -- AXI-Lite signals
    signal awready_i : std_logic := '0';
    signal wready_i  : std_logic := '0';
    signal bvalid_i  : std_logic := '0';
    signal bresp_i   : std_logic_vector(1 downto 0) := (others=>'0');

    signal arready_i : std_logic := '0';
    signal rvalid_i  : std_logic := '0';
    signal rresp_i   : std_logic_vector(1 downto 0) := (others=>'0');

    signal awaddr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal araddr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal wdata_reg  : std_logic_vector(31 downto 0);

    signal aw_seen : std_logic := '0';
    signal w_seen  : std_logic := '0';
    signal read_in_progress : std_logic := '0';

begin

    -- AXI stream passthrough when disabled
    ready <= m_axis_tready when stats_en = '1' else '1';
    s_axis_tready <= ready;
    m_axis_tvalid <= s_axis_tvalid;
    m_axis_tdata  <= s_axis_tdata;

    -- AXI-Lite outputs
    s_axi_awready <= awready_i;
    s_axi_wready  <= wready_i;
    s_axi_bvalid  <= bvalid_i;
    s_axi_bresp   <= bresp_i;

    s_axi_arready <= arready_i;
    s_axi_rvalid  <= rvalid_i;
    s_axi_rresp   <= rresp_i;

    -- Counting logic
    transfer <= s_axis_tvalid and ready;
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' or stats_reset = '1' then
                -- Cycle info
                total_cycles   <= (others=>'0');
                transfer_count <= (others=>'0');
                idle_cycles    <= (others=>'0');

                -- Gap info (cycles between packets)
                gap_counter   <= (others=>'0');
                min_gap       <= (others=>'0');
                max_gap       <= (others=>'0');
                sum_gaps      <= (others=>'0');
                gap_events    <= (others=>'0');

                -- Burst info (packs of valid packets)
                burst_len     <= (others=>'0');
                burst_count   <= (others=>'0');
                max_burst     <= (others=>'0');
                sum_burst     <= (others=>'0');

                -- Current values
                consecutive_transfer_cycles <= (others=>'0');
                has_seen_transfer           <= '0';
                prev_valid                  <= '0';
            else
                if stats_en = '1' then
                    -- Global cycle count
                    total_cycles <= total_cycles + 1;

                    if transfer = '1' then

                        transfer_count <= transfer_count + 1;
                        burst_len      <= burst_len + 1;

                        has_seen_transfer <= '1';  -- monotonic latch

                        if prev_valid = '1' then
                            consecutive_transfer_cycles <= consecutive_transfer_cycles + 1;
                        else
                            -- New burst
                            burst_count <= burst_count + 1;

                            -- Gap is valid only after first-ever transfer
                            if has_seen_transfer = '1' then
                                gap_events <= gap_events + 1;
                                sum_gaps   <= sum_gaps + gap_counter;

                                if gap_counter < min_gap then
                                    min_gap <= gap_counter;
                                end if;

                                if gap_counter > max_gap then
                                    max_gap <= gap_counter;
                                end if;
                            end if;

                            gap_counter <= (others=>'0');
                        end if;

                    else -- taxis_valid
                        idle_cycles <= idle_cycles + 1;
                        gap_counter <= gap_counter + 1;

                        -- Updating burst events
                        if prev_valid = '1' then
                            sum_burst <= sum_burst + burst_len;

                            if burst_len > max_burst then
                                max_burst <= burst_len;
                            end if;

                            burst_len <= (others=>'0');
                        end if;
                    end if;

                    prev_valid <= transfer;
                end if;
            end if;
        end if;
    end process;


    -- AXI-Lite interface for control and reads
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                awready_i <= '0';
                wready_i  <= '0';
                bvalid_i  <= '0';
                arready_i <= '0';
                rvalid_i  <= '0';
                aw_seen   <= '0';
                w_seen    <= '0';
                read_in_progress  <= '0';
                stats_en <= '0';

            else
                -- WRITE CHANNEL

                -- Accept address
                if (awready_i = '0' and s_axi_awvalid = '1') then
                    awready_i  <= '1';
                    awaddr_reg <= s_axi_awaddr;
                    aw_seen    <= '1';
                else
                    awready_i  <= '0';
                end if;

                -- Accept data
                if (wready_i = '0' and s_axi_wvalid = '1') then
                    wready_i  <= '1';
                    wdata_reg <= s_axi_wdata;
                    w_seen    <= '1';
                else
                    wready_i  <= '0';
                end if;

                -- Generate write response
                if (aw_seen = '1' and w_seen = '1' and bvalid_i = '0') then
                    bvalid_i <= '1';
                    bresp_i  <= "00";

                    -- Register write
                    if awaddr_reg = x"00" then
                        stats_en        <= wdata_reg(0);
                        stats_reset_req <= wdata_reg(1);
                    end if;

                elsif (bvalid_i = '1' and s_axi_bready = '1') then
                    bvalid_i <= '0';
                    aw_seen  <= '0';
                    w_seen   <= '0';
                end if;

                ----------------------------------------------------------------
                -- READ CHANNEL

                -- Accept address
                if (arready_i = '0' and s_axi_arvalid = '1' and read_in_progress = '0') then
                    arready_i        <= '1';
                    araddr_reg       <= s_axi_araddr;
                    read_in_progress <= '1';
                else
                    arready_i        <= '0';
                end if;

                -- Provide data
                if (read_in_progress = '1' and rvalid_i = '0') then
                    rvalid_i <= '1';
                    rresp_i  <= "00";

                    case araddr_reg is
                        -- reset bit not readable as it is self-clearing
                        when x"00" => s_axi_rdata <= (31 downto 1=>'0') & stats_en;
                        when x"04" => s_axi_rdata <= std_logic_vector(total_cycles(31 downto 0));
                        when x"08" => s_axi_rdata <= std_logic_vector(transfer_count(31 downto 0));
                        when x"0C" => s_axi_rdata <= std_logic_vector(idle_cycles(31 downto 0));
                        when x"10" => s_axi_rdata <= std_logic_vector(burst_count(31 downto 0));
                        when x"14" => s_axi_rdata <= std_logic_vector(max_burst(31 downto 0));
                        when x"18" => s_axi_rdata <= std_logic_vector(min_gap(31 downto 0));
                        when x"1C" => s_axi_rdata <= std_logic_vector(max_gap(31 downto 0));
                        when x"20" => s_axi_rdata <= std_logic_vector(gap_events(31 downto 0));
                        when x"24" => s_axi_rdata <= std_logic_vector(sum_burst(31 downto 0));
                        when x"28" => s_axi_rdata <= std_logic_vector(sum_gaps(31 downto 0));
                        when others => s_axi_rdata <= (others=>'0');
                    end case;

                elsif (rvalid_i = '1' and s_axi_rready = '1') then
                    rvalid_i <= '0';
                    read_in_progress <= '0';
                end if;
            end if;
            -- Self-clearing reset logic
            if stats_reset_req = '1' then
                stats_reset <= '1';
                stats_reset_req <= '0'; -- clear the request
            else
                stats_reset <= '0';
            end if;
        end if;
    end process;


end architecture;