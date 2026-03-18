/* ============================================================================
 * File: axi_stats.c
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

 #include "axi_stats.h"

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>


int axi_stats_open(axi_stats_t *handle, uintptr_t phys_addr)
{
    /* Register physical address */
    handle->phys_addr = phys_addr;

    /* Open /dev/mem directly */
    handle->fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (handle->fd < 0) {
        perror("open /dev/mem");
        return -1;
    }

    /* MMAP our axi stats registers */
    void *map = mmap(
        NULL,
        AXI_STATS_MAP_SIZE,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        handle->fd,
        phys_addr
    );
    if (map == MAP_FAILED) {
        perror("mmap");
        close(handle->fd);
        return -1;
    }

    /* Mapped address */
    handle->regs = (volatile uint32_t *)map;

    return 0;
}


void axi_stats_close(axi_stats_t *handle)
{
    munmap((void*)handle->regs, AXI_STATS_MAP_SIZE);
    close(handle->fd);
}


void axi_stats_enable(axi_stats_t *handle)
{
    handle->regs[AXI_STATS_CTRL/4] = 1;
}


void axi_stats_disable(axi_stats_t *handle)
{
    handle->regs[AXI_STATS_CTRL/4] = 0;
}


uint32_t axi_stats_read(axi_stats_t *handle, axi_stats_reg_t reg)
{
    return handle->regs[reg/4];
}


static axi_stat_desc_t stats[] = {
    {"Total cycles", AXI_STATS_TOTAL},
    {"Packet count", AXI_STATS_PACKETS},
    {"Idle cycles",  AXI_STATS_IDLE},
    {"Burst count",  AXI_STATS_BURST_CNT},
    {"Max burst",    AXI_STATS_MAX_BURST},
    {"Min gap",      AXI_STATS_MIN_GAP},
    {"Max gap",      AXI_STATS_MAX_GAP},
    {"Gap events",   AXI_STATS_GAP_EVENTS},
    {"Sum burst",    AXI_STATS_SUM_BURST},
    {"Sum gaps",     AXI_STATS_SUM_GAPS},
};

void axi_stats_print(axi_stats_t *handle)
{
    size_t n = sizeof(stats)/sizeof(stats[0]);

    for (size_t i = 0; i < n; i++)
    {
        printf("%-15s : %u\n",
               stats[i].name,
               axi_stats_read(handle, stats[i].reg));
    }
}