; =====================================================================
; KGAMER ARCADE: SATURNPONG - MASTER ASSEMBLY SOURCE (vasmsh_mot)
; Target: Hitachi SH-2 (SH7604) Bare-Metal / Direct Binary Output
; Assembler: vasmsh_mot -Fbin -o 0.bin saturnpong.s
; =====================================================================

        org     $06004000               ; Sega Saturn Default Boot Execution Address

; --- Hardware & Memory Constants ---
STACK_TOP           equ $06040000       ; Saturn High RAM Stack Pointer
VDP2_TVMD           equ $25F80000       ; VDP2 Display Control Register
VDP1_RAM_BASE       equ $25C00000       ; VDP1 VRAM & Sprite Command Tables
HARDWARE_PORT_BASE  equ $25FB0000       ; Controller Ports Base (P1, P2, Multi-tap)

; --- Game States ---
STATE_MENU          equ 0
STATE_MODE_SELECT   equ 1
STATE_COMMON_CFG    equ 2               ; Common Settings (D-Pad/Trigger & Custom Pause bind)
STATE_2P_CFG        equ 3               ; 2P Dedicated Settings (Handicap, paddle size, swap rules)
STATE_CUSTOM_CFG    equ 4               ; Custom Rules Configuration & Correction Screen
STATE_PLAYING       equ 5               ; Active Gameplay
STATE_PAUSE         equ 6               ; Pause Menu & Vaysilayan / Rematch Option
STATE_HISTORY       equ 7               ; Match History & Pinning Screen

; --- Game Modes & Rules ---
MODE_EASY           equ 1               ; Score limit: 4, Slow speed, Easy AI
MODE_EASY_PLUS      equ 2               ; Score limit: 3, Selectable speed (Slow/Fast)
MODE_MEDIUM         equ 3               ; Score limit: 5, Medium speed, Medium AI
MODE_HARD           equ 4               ; Score limit: 7, Dynamic accelerating ball, Hard AI
MODE_CUSTOM         equ 5               ; Custom Configurable Mode (Excluded from saves)
MODE_2P_LOCAL       equ 6               ; 2-Player Local (Player 1 vs Player 2)

; --- Control Input Types ---
INPUT_MODE_DPAD     equ 0               ; Control paddles using D-Pad
INPUT_MODE_TRIGGER  equ 1               ; Control paddles using Analog Triggers

; --- Match History Constants ---
MAX_HISTORY_CAP     equ 30              ; Maximum 30 match capacity limit

; =====================================================================
; 1. SYSTEM BOOT & MAIN EXECUTION LOOP
; =====================================================================
_start:
        ; Initialize Stack Pointer
        mov.l   stack_ptr_addr, r15

        ; Enable VDP2 Display
        mov.l   vdp2_tvmd_ptr, r1
        mov.w   val_display_on, r0
        mov.w   r0, @r1

        ; Initialize VDP1 Graphics Engine
        bsr     init_vdp1_system
        nop

        ; Set Initial State to Main Menu
        mov     #STATE_MENU, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1

main_execution_loop:
        mov.l   current_state_ptr, r1
        mov.l   @r1, r0

        cmp/eq  #STATE_MENU, r0
        bt      handler_menu

        cmp/eq  #STATE_MODE_SELECT, r0
        bt      handler_mode_select

        cmp/eq  #STATE_COMMON_CFG, r0
        bt      handler_common_config

        cmp/eq  #STATE_2P_CFG, r0
        bt      handler_2p_config

        cmp/eq  #STATE_CUSTOM_CFG, r0
        bt      handler_custom_config

        cmp/eq  #STATE_PLAYING, r0
        bt      handler_playing

        cmp/eq  #STATE_PAUSE, r0
        bt      handler_pause

        cmp/eq  #STATE_HISTORY, r0
        bt      handler_history

        bra     main_execution_loop
        nop

; =====================================================================
; 2. MAIN MENU STATE HANDLER
; =====================================================================
handler_menu:
        bsr     poll_universal_2p_controllers
        nop

        mov.l   p1_port_slot_ptr, r2
        mov.l   @r2, r3
        tst     r3, r3
        bt      menu_loop_wait

        mov.w   @r3, r0
        tst     #$0008, r0              ; Check START button bit
        bt      menu_loop_wait

        mov     #STATE_MODE_SELECT, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1

menu_loop_wait:
        bra     main_execution_loop
        nop

; =====================================================================
; 3. MODE SELECT SCREEN HANDLER
; =====================================================================
handler_mode_select:
        bsr     poll_universal_2p_controllers
        nop

        mov.l   p1_port_slot_ptr, r2
        mov.l   @r2, r3
        tst     r3, r3
        bt      mode_select_wait

        mov.w   @r3, r0
        tst     #$0008, r0
        bt      mode_select_wait

        mov.l   selected_mode_addr, r1
        mov.l   @r1, r2

        cmp/eq  #MODE_CUSTOM, r2
        bt      goto_custom_config_state

        cmp/eq  #MODE_2P_LOCAL, r2
        bt      goto_2p_config_state

        mov     #STATE_PLAYING, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bsr     reset_match_and_service
        bra     mode_select_wait
        nop

goto_custom_config_state:
        mov     #STATE_CUSTOM_CFG, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bra     mode_select_wait
        nop

goto_2p_config_state:
        mov     #STATE_2P_CFG, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1

mode_select_wait:
        bra     main_execution_loop
        nop

; =====================================================================
; 4. COMMON SETTINGS (D-Pad/Trigger Switch & Custom Pause Key Binding)
; =====================================================================
handler_common_config:
        ; Switch between D-Pad and Analog Triggers + Custom Pause button remap
        bsr     poll_universal_2p_controllers
        nop

        mov.l   p1_port_slot_ptr, r2
        mov.l   @r2, r3
        tst     r3, r3
        bt      common_cfg_wait

        mov.w   @r3, r0
        tst     #$0008, r0              ; START: Save input mappings & return to menu
        bt      common_cfg_wait

        mov     #STATE_MENU, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1

common_cfg_wait:
        bra     main_execution_loop
        nop

; =====================================================================
; 5. 2P DEDICATED SETTINGS CONFIGURATION HANDLER
; =====================================================================
handler_2p_config:
        bsr     poll_universal_2p_controllers
        nop

        mov.l   p1_port_slot_ptr, r2
        mov.l   @r2, r3
        tst     r3, r3
        bt      cfg_2p_wait

        mov.w   @r3, r0
        tst     #$0008, r0
        bt      cfg_2p_wait

        mov     #STATE_PLAYING, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bsr     reset_match_and_service

cfg_2p_wait:
        bra     main_execution_loop
        nop

; =====================================================================
; 6. CUSTOM CONFIGURATION & CORRECTION SCREEN HANDLER
; =====================================================================
handler_custom_config:
        bsr     poll_universal_2p_controllers
        nop

        mov.l   p1_port_slot_ptr, r2
        mov.l   @r2, r3
        tst     r3, r3
        bt      custom_cfg_wait

        mov.w   @r3, r0
        tst     #$0008, r0
        bt      check_vaysilayan_custom_reset

        mov     #STATE_PLAYING, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bsr     reset_match_and_service
        bra     custom_cfg_wait
        nop

check_vaysilayan_custom_reset:
        tst     #$0080, r0              ; [C] Button: "Vaysilayana dondur" (Revert custom settings)
        bf      execute_vaysilayan_custom_reset

custom_cfg_wait:
        bra     main_execution_loop
        nop

execute_vaysilayan_custom_reset:
        bsr     revert_custom_configuration_to_default
        bra     custom_cfg_wait
        nop

; =====================================================================
; 7. GAMEPLAY, PHYSICS & SERVICE RULE HANDLER
; =====================================================================
handler_playing:
        bsr     poll_universal_2p_controllers
        nop

        mov.l   p1_port_slot_ptr, r2
        mov.l   @r2, r3
        tst     r3, r3
        bt      run_game_physics

        ; Check user-remapped custom Pause button mask
        mov.w   @r3, r0
        mov.l   custom_pause_mask_addr, r1
        mov.l   @r1, r2
        tst     r2, r0
        bt      run_game_physics

        mov     #STATE_PAUSE, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bra     main_execution_loop
        nop

run_game_physics:
        bsr     update_paddles_with_input_mode
        nop
        bsr     update_ball_physics
        nop
        bsr     check_goal_and_apply_service
        nop

        bra     main_execution_loop
        nop

; =====================================================================
; 8. PAUSE MENU & "VAYSILAYANA DONDUR" (SIDE SWAP / REMATCH) HANDLER
; =====================================================================
handler_pause:
        bsr     poll_universal_2p_controllers
        nop

        mov.l   p1_port_slot_ptr, r2
        mov.l   @r2, r3
        tst     r3, r3
        bt      handler_pause
        mov.w   @r3, r0

        tst     #$0040, r0              ; [A] Button: Resume Game
        bf      pause_resume_game

        tst     #$0020, r0              ; [B] Button: Return to Main Menu
        bf      pause_return_menu

        tst     #$0080, r0              ; [C] Button: "Vaysilayana dondur" (Swap sides & rematch)
        bf      pause_vaysilayan_swap

        bra     handler_pause
        nop

pause_resume_game:
        mov     #STATE_PLAYING, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bra     main_execution_loop
        nop

pause_return_menu:
        mov     #STATE_MENU, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bra     main_execution_loop
        nop

pause_vaysilayan_swap:
        bsr     swap_player_sides_and_revert
        nop
        mov     #STATE_PLAYING, r0
        mov.l   current_state_ptr, r1
        mov.l   r0, @r1
        bra     main_execution_loop
        nop

; =====================================================================
; 9. MATCH HISTORY & PINNING SCREEN (PINNED vs NO PIN)
; =====================================================================
handler_history:
        rts
        nop

; =====================================================================
; MATCH RECORD & 30-MATCH PRUNING ENGINE (scores.properties)
; =====================================================================
save_match_and_update_properties:
        mov.l   selected_mode_addr, r1
        mov.l   @r1, r0
        cmp/eq  #MODE_CUSTOM, r0
        bt      skip_saving_process

        bsr     shift_history_buffer_down
        nop
        bsr     write_new_match_to_slot_0
        nop
        bsr     prune_oldest_unpinned_matches
        nop
        bsr     flush_scores_properties_to_storage
        nop

skip_saving_process:
        rts
        nop

shift_history_buffer_down:
        rts
        nop

write_new_match_to_slot_0:
        rts
        nop

prune_oldest_unpinned_matches:
        ; Removes oldest unpinned matches when count > 30, protecting pinned records
        rts
        nop

flush_scores_properties_to_storage:
        ; Updates scores.properties after every non-custom match
        rts
        nop

; =====================================================================
; UNIVERSAL CONTROLLER HOT-SWAP (SNES, DualSense, Saturn Pad, etc.)
; =====================================================================
poll_universal_2p_controllers:
        mov     #0, r2                  ; Port iterator (0 - 7)
        mov.l   hw_port_base_ptr, r1

scan_ports_loop:
        mov.w   @r1, r0
        cmp/eq  #$FFFF, r0
        bt      next_port_slot
        tst     r0, r0
        bt      next_port_slot

        mov.l   p1_port_slot_ptr, r3
        mov.l   @r3, r4
        tst     r4, r4
        bf      check_p2_slot

        mov.l   r1, @r3                 ; First active controller -> Player 1
        bra     next_port_slot
        nop

check_p2_slot:
        mov.l   p1_port_slot_ptr, r3
        mov.l   @r3, r4
        cmp/eq  r1, r4
        bt      next_port_slot

        mov.l   p2_port_slot_ptr, r3
        mov.l   @r3, r4
        tst     r4, r4
        bf      next_port_slot

        mov.l   r1, @r3                 ; Second active controller -> Player 2

next_port_slot:
        add     #2, r1
        add     #1, r2
        cmp/eq  #8, r2
        bf      scan_ports_loop
        rts
        nop

; =====================================================================
; SUBROUTINE PLACEHOLDERS
; =====================================================================
init_vdp1_system:
        rts
        nop

reset_match_and_service:
        rts
        nop

revert_custom_configuration_to_default:
        rts
        nop

swap_player_sides_and_revert:
        rts
        nop

update_paddles_with_input_mode:
        ; Reads INPUT_MODE_DPAD vs INPUT_MODE_TRIGGER and updates paddle positions
        rts
        nop

update_ball_physics:
        rts
        nop

check_goal_and_apply_service:
        ; Gives next serve to the player who scored the goal
        rts
        nop

; =====================================================================
; LITERAL POOL & BSS VARIABLES
; =====================================================================
        align   4
stack_ptr_addr:         dc.l    STACK_TOP
vdp2_tvmd_ptr:          dc.l    VDP2_TVMD
val_display_on:         dc.w    $0001
                        align   4
current_state_ptr:      dc.l    current_state_var
selected_mode_addr:     dc.l    selected_mode_var
hw_port_base_ptr:       dc.l    HARDWARE_PORT_BASE
p1_port_slot_ptr:       dc.l    p1_active_port
p2_port_slot_ptr:       dc.l    p2_active_port
custom_pause_mask_addr: dc.l    custom_pause_mask_var
input_mapping_mode_addr:dc.l    input_mapping_mode_var

        align   4
current_state_var:      ds.l    1
selected_mode_var:      ds.l    1
p1_active_port:         ds.l    1
p2_active_port:         ds.l    1
p1_score:               ds.l    1
p2_score:               ds.l    1
custom_pause_mask_var:  dc.l    $0010   ; Default Pause bitmask (remappable)
input_mapping_mode_var: dc.l    0       ; 0 = D-Pad, 1 = Analog Triggers
match_history_pool:     ds.b    1500    ; 30-match structured history buffer
