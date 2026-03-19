/* ============================================================================
 * File: axi_stats.h
 * Description: AXI stats module
 *
 * Copyright (C) 2026 Quentin Ducasse
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * ============================================================================ */

 #ifndef AXI_STATS_H
#define AXI_STATS_H

#include <stdint.h>
#include <stddef.h>

#define AXI_STATS_MAP_SIZE 0x1000

// Default base addresses (can/should be overridden)
#ifndef AXI_STATS_BASE_ETM
#define AXI_STATS_BASE_ETM 0x80000000
#endif

/* Register offsets */
typedef enum {
    AXI_STATS_CTRL       = 0x00,
    AXI_STATS_TOTAL      = 0x04,
    AXI_STATS_TRANSFERS  = 0x08,
    AXI_STATS_IDLE       = 0x0C,
    AXI_STATS_BURST_CNT  = 0x10,
    AXI_STATS_MAX_BURST  = 0x14,
    AXI_STATS_MIN_GAP    = 0x18,
    AXI_STATS_MAX_GAP    = 0x1C,
    AXI_STATS_GAP_EVENTS = 0x20,
    AXI_STATS_SUM_BURST  = 0x24,
    AXI_STATS_SUM_GAPS   = 0x28
} axi_stats_reg_t;


/* Handle */
typedef struct {
    int fd;
    uintptr_t phys_addr;
    volatile uint32_t *regs;
} axi_stats_t;

typedef struct {
    const char *name;
    axi_stats_reg_t reg;
} axi_stat_desc_t;

/* API */
int  axi_stats_open(axi_stats_t *h, uintptr_t phys_addr);
void axi_stats_close(axi_stats_t *h);

void axi_stats_enable(axi_stats_t *h);
void axi_stats_disable(axi_stats_t *h);

uint32_t axi_stats_read(axi_stats_t *h, axi_stats_reg_t reg);

void axi_stats_print(axi_stats_t *h);

#endif