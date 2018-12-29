//
//  bridge_header.h
//  DMD 5620
//
//  Created by Seth Morabito on 12/21/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

#ifndef bridge_header_h
#define bridge_header_h

#include <stdint.h>

extern int dmd_reset();
extern uint8_t *dmd_video_ram();
extern int dmd_step();
extern int dmd_step_loop(size_t steps);
extern int dmd_get_pc(uint32_t *pc);
extern int dmd_read_word(uint32_t addr, uint32_t *val);
extern int dmd_read_byte(uint32_t addr, uint8_t *val);
extern int dmd_get_register(uint8_t reg, uint32_t *val);
extern int dmd_get_duart_output_port(uint8_t *val);
extern int dmd_rx_char(uint8_t c);
extern int dmd_rx_keyboard(uint8_t c);
extern int dmd_mouse_move(uint16_t x, uint16_t y);
extern int dmd_mouse_down(uint8_t button);
extern int dmd_mouse_up(uint8_t button);
extern int dmd_rs232_tx_poll(uint8_t *c);
extern int dmd_kb_tx_poll(uint8_t *c);
extern int dmd_set_nvram(uint8_t *nvram);
extern int dmd_get_nvram(uint8_t *nvram);

#endif /* bridge_header_h */
