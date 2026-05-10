#***************************************
#
# Student Name: Paul Mosincat
# Student Email: pmosincat@hawk.illinoistech.edu
# Course: CS 350 Computer Organization and Assembly Language Programming
# Assignment: Tetris Project
#
# Summary of Assignment Purpose: The purpose of this assignment 
#
# Date of Initial Creation: April 29, 2026 at 5pm 
#
# Description of Program Purpose: The purpose of the project is to use MMIO, timers, event programming, and Bitmap to develop Tetris
#
# Functions and Modules in this file: Most of the functions in this project revolve around tetris. There is random feature, tetris controls, locking, dropping and rotating, and lastly clearing.
# All of these functions are the basic features that tetris uses in terms of gameplay.
#
# Additional Required Files: N/A
#
#****************** Setup/Controls *********************
# These are controls and display setting for the most optimal gameplay.
# The project should assemble then just connect the 3 tools, start the timer and then you should be able to play and control the peice through the MMIO.
# Bitmap Display Settings:
# Unit Width: 4
# Unit Height: 4
# Display Width: 256
# Display Height: 256
# Base Address: 0x10010000 (static data)
#
# Tools:
# Bitmap Display
# Keyboard and Display MMIO Simulator
# Timer Tool
#
# Controls:
# A/a = left
# D/d = right
# S/s = down
# R/r = rotate
# Space = hard drop
# Q/q = quit


#---------------------------- DATA--------------------------
# This section stores all the shapes from tetris, bitmap, colors for the shapes, and the actual moving piece like rotating.
.data
display_buffer: .space 16384

I_piece:
.word 1,0,0,0
.word 1,0,0,0
.word 1,0,0,0
.word 1,0,0,0

O_piece:
.word 1,1,0,0
.word 1,1,0,0
.word 0,0,0,0
.word 0,0,0,0

T_piece:
.word 0,1,0,0
.word 1,1,1,0
.word 0,0,0,0
.word 0,0,0,0

S_piece:
.word 0,1,1,0
.word 1,1,0,0
.word 0,0,0,0
.word 0,0,0,0

Z_piece:
.word 1,1,0,0
.word 0,1,1,0
.word 0,0,0,0
.word 0,0,0,0

J_piece:
.word 1,0,0,0
.word 1,1,1,0
.word 0,0,0,0
.word 0,0,0,0

L_piece:
.word 0,0,1,0
.word 1,1,1,0
.word 0,0,0,0
.word 0,0,0,0

piece_table:
.word I_piece
.word O_piece
.word T_piece
.word S_piece
.word Z_piece
.word J_piece
.word L_piece

color_table:
.word 0x0000FFFF
.word 0x00FFFF00
.word 0x00FF00FF
.word 0x0000FF00
.word 0x00FF0000
.word 0x000000FF
.word 0x00FF8800
active_matrix: .space 64
rotate_matrix: .space 64
active_piece: .word active_matrix
active_x: .word 3
active_y: .word 0
active_color: .word 0x00FF00FF
fall_delay: .word 800
board_grid: .space 800


#---------------------------- PROGRAM SETUP ----------------------------
.text
.globl main
.eqv BASE_ADDR, 0x10010000
.eqv SCREEN_W, 64
.eqv BOARD_X, 17
.eqv BOARD_Y, 2
.eqv BLOCK_SIZE, 3
.eqv BOARD_W, 10
.eqv BOARD_H, 20
.eqv KEY_CTRL, 0xffff0000
.eqv KEY_DATA, 0xffff0004
.eqv TIME_LOW, 0xffff0018
.eqv TIMECMP_LOW, 0xffff0020


#---------------------------- MAIN GAME LOOP ----------------------------
# This is just the main loop of the overall game. First the game is setup, then as you play the game gets updates and when it done it exists.
main:

    la a0, T_piece
    la a1, active_matrix
    jal copy_matrix
    jal clear_screen
    jal draw_board
    jal draw_locked_blocks
    jal draw_active_piece
    jal init_timer

game_loop:

    jal check_input
    jal check_auto_fall
    j game_loop

game_done:

    j game_done

#---------------------------- BOARD DRAWING ----------------------------
# In this section of the code I took your typical Tetris board which is 10 by 20 and rednered it in the bitmap. 
# This is the basic setup for the board. Additionally, it start off by drawing the intial piece using a matrix
# in row and columns like a Java double for loop for both pieces and the actual map.

clear_screen:

    li t0, BASE_ADDR
    li t1, 4096
    li t2, 0x00000000

clear_screen_loop:

    beqz t1, clear_screen_done
    sw t2, 0(t0)
    addi t0, t0, 4
    addi t1, t1, -1
    j clear_screen_loop

clear_screen_done:

    jr ra

draw_board:

    li t0, 0

draw_board_row_loop:

    li t1, 60
    bge t0, t1, draw_board_done
    li t2, 0

draw_board_col_loop:

    li t1, 30
    bge t2, t1, draw_board_next_row
    addi t3, t2, BOARD_X
    addi t4, t0, BOARD_Y
    li t5, SCREEN_W
    mul t6, t4, t5
    add t6, t6, t3
    slli t6, t6, 2
    li t5, BASE_ADDR
    add t6, t6, t5
    li t5, 0x00181818
    sw t5, 0(t6)
    addi t2, t2, 1
    j draw_board_col_loop

draw_board_next_row:

    addi t0, t0, 1
    j draw_board_row_loop

draw_board_done:

    jr ra

draw_piece:

    addi sp, sp, -28
    sw ra, 24(sp)
    sw s0, 20(sp)
    sw s1, 16(sp)
    sw s2, 12(sp)
    sw s3, 8(sp)
    sw s4, 4(sp)
    sw s5, 0(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    li s4, 0

draw_piece_row_loop:

    li t0, 4
    bge s4, t0, draw_piece_done
    li s5, 0

draw_piece_col_loop:

    li t0, 4
    bge s5, t0, draw_piece_next_row
    li t0, 4
    mul t1, s4, t0
    add t1, t1, s5
    slli t1, t1, 2
    add t1, s0, t1
    lw t2, 0(t1)
    beqz t2, draw_piece_skip_cell
    add t1, s1, s5
    li t0, BLOCK_SIZE
    mul a0, t1, t0
    addi a0, a0, BOARD_X
    add t1, s2, s4
    mul a1, t1, t0
    addi a1, a1, BOARD_Y
    mv a2, s3
    jal draw_block

draw_piece_skip_cell:

    addi s5, s5, 1
    j draw_piece_col_loop

draw_piece_next_row:

    addi s4, s4, 1
    j draw_piece_row_loop

draw_piece_done:

    lw s5, 0(sp)
    lw s4, 4(sp)
    lw s3, 8(sp)
    lw s2, 12(sp)
    lw s1, 16(sp)
    lw s0, 20(sp)
    lw ra, 24(sp)
    addi sp, sp, 28
    jr ra

draw_block:

    mv t3, a0
    mv t4, a1
    mv t5, a2
    li t0, 0

draw_block_row_loop:

    li t1, BLOCK_SIZE
    bge t0, t1, draw_block_done
    li t1, 0

draw_block_col_loop:

    li t2, BLOCK_SIZE
    bge t1, t2, draw_block_next_row
    add t2, t3, t1
    add t6, t4, t0
    li a4, SCREEN_W
    mul t6, t6, a4
    add t6, t6, t2
    slli t6, t6, 2
    li a4, BASE_ADDR
    add t6, t6, a4
    sw t5, 0(t6)
    addi t1, t1, 1
    j draw_block_col_loop

draw_block_next_row:

    addi t0, t0, 1
    j draw_block_row_loop

draw_block_done:

    jr ra

draw_active_piece:

    addi sp, sp, -4
    sw ra, 0(sp)
    lw a0, active_piece
    lw a1, active_x
    lw a2, active_y
    lw a3, active_color
    jal draw_piece
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra


#---------------------------- COLLISION ----------------------------
# Another major aspect of Tetris is the collision aspect. This includes peiece and the board itself.
# In the beginning when testing this out peiece that do not have collision can fly out from the board.
# The other aspect is piece collision whether the user can place the peiece or not.

can_place_active:

    addi sp, sp, -4
    sw ra, 0(sp)
    lw a0, active_piece
    lw a1, active_x
    lw a2, active_y
    jal can_place_piece
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

can_place_piece:

    addi sp, sp, -24
    sw ra, 20(sp)
    sw s0, 16(sp)
    sw s1, 12(sp)
    sw s2, 8(sp)
    sw s3, 4(sp)
    sw s4, 0(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    li s3, 0

can_place_row_loop:

    li t0, 4
    bge s3, t0, can_place_valid
    li s4, 0

can_place_col_loop:

    li t0, 4
    bge s4, t0, can_place_next_row
    li t0, 4
    mul t1, s3, t0
    add t1, t1, s4
    slli t1, t1, 2
    add t1, s0, t1
    lw t2, 0(t1)
    beqz t2, can_place_skip_cell
    add t3, s1, s4
    bltz t3, can_place_invalid
    li t0, BOARD_W
    bge t3, t0, can_place_invalid
    add t4, s2, s3
    bltz t4, can_place_invalid
    li t0, BOARD_H
    bge t4, t0, can_place_invalid
    li t0, BOARD_W
    mul t5, t4, t0
    add t5, t5, t3
    slli t5, t5, 2
    la t6, board_grid
    add t5, t5, t6
    lw t6, 0(t5)
    bnez t6, can_place_invalid

can_place_skip_cell:

    addi s4, s4, 1
    j can_place_col_loop

can_place_next_row:

    addi s3, s3, 1
    j can_place_row_loop

can_place_valid:

    li a0, 1
    j can_place_return

can_place_invalid:

    li a0, 0

can_place_return:

    lw s4, 0(sp)
    lw s3, 4(sp)
    lw s2, 8(sp)
    lw s1, 12(sp)
    lw s0, 16(sp)
    lw ra, 20(sp)
    addi sp, sp, 24
    jr ra

#---------------------------- INPUT ----------------------------
# Another major aspect of Tetris is the movement. This section focus on the user input.
# The keys and functions are listed at the top of the program. This section basically those functions
# and implements it into the game.
check_input:

    addi sp, sp, -4
    sw ra, 0(sp)
    li t0, KEY_CTRL
    lw t1, 0(t0)
    beqz t1, check_input_done
    li t0, KEY_DATA
    lw t1, 0(t0)
    li t2, 97
    beq t1, t2, key_left
    li t2, 65
    beq t1, t2, key_left
    li t2, 100
    beq t1, t2, key_right
    li t2, 68
    beq t1, t2, key_right
    li t2, 115
    beq t1, t2, key_down
    li t2, 83
    beq t1, t2, key_down
    li t2, 114
    beq t1, t2, key_rotate
    li t2, 82
    beq t1, t2, key_rotate
    li t2, 119
    beq t1, t2, key_rotate
    li t2, 87
    beq t1, t2, key_rotate
    li t2, 32
    beq t1, t2, key_drop
    li t2, 113
    beq t1, t2, key_quit
    li t2, 81
    beq t1, t2, key_quit
    j check_input_done

key_left:

    li a0, -1
    li a1, 0
    jal try_move
    j check_input_done

key_right:

    li a0, 1
    li a1, 0
    jal try_move
    j check_input_done

key_down:

    li a0, 0
    li a1, 1
    jal try_move
    j check_input_done

key_rotate:

    jal rotate_active_piece
    j check_input_done

key_drop:

    jal hard_drop
    j check_input_done

key_quit:

    li a7, 10
    ecall

check_input_done:

    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

#---------------------------- HARD DROP--------------------------
# Going of the movement section is the hard drop feature. Basically when you press space
# the program detects the user input and instantly drops the piece to the bottom of the game
# board just in actual Tetris.
try_move:

    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    mv s2, a0
    mv s3, a1
    lw t0, active_x
    add s0, t0, s2
    lw t0, active_y
    add s1, t0, s3
    lw a0, active_piece
    mv a1, s0
    mv a2, s1
    jal can_place_piece
    beqz a0, try_move_failed
    la t0, active_x
    sw s0, 0(t0)
    la t0, active_y
    sw s1, 0(t0)
    jal redraw_screen
    j try_move_done

try_move_failed:

    bnez s3, try_move_failed_down
    j try_move_done

try_move_failed_down:

    jal lock_active_piece
    jal clear_full_lines
    jal spawn_piece
    jal redraw_screen

try_move_done:

    lw s3, 0(sp)
    lw s2, 4(sp)
    lw s1, 8(sp)
    lw s0, 12(sp)
    lw ra, 16(sp)
    addi sp, sp, 20
    jr ra

hard_drop:

    addi sp, sp, -8
    sw ra, 4(sp)
    sw s0, 0(sp)

hard_drop_loop:

    lw t0, active_y
    addi s0, t0, 1
    lw a0, active_piece
    lw a1, active_x
    mv a2, s0
    jal can_place_piece
    beqz a0, hard_drop_done
    la t0, active_y
    sw s0, 0(t0)
    j hard_drop_loop

hard_drop_done:

    jal lock_active_piece
    jal clear_full_lines
    jal spawn_piece
    jal set_fall_timer
    jal redraw_screen
    lw s0, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8
    jr ra

redraw_screen:

    addi sp, sp, -4
    sw ra, 0(sp)
    jal clear_screen
    jal draw_board
    jal draw_locked_blocks
    jal draw_active_piece
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

#---------------------------- FALL TIMER ----------------------------
# In tetris one the simpler aspects is the timer feature. Basically, when you start the timer in RSIC-V 
# the bitmap will show the peiece slowly falling down based on that timer.
init_timer:

    addi sp, sp, -4
    sw ra, 0(sp)
    jal set_fall_timer
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

set_fall_timer:

    li t0, TIME_LOW
    lw t1, 0(t0)
    lw t2, fall_delay
    add t1, t1, t2
    li t0, TIMECMP_LOW
    sw t1, 0(t0)
    jr ra

check_auto_fall:

    addi sp, sp, -4
    sw ra, 0(sp)
    li t0, TIME_LOW
    lw t1, 0(t0)
    li t0, TIMECMP_LOW
    lw t2, 0(t0)
    blt t1, t2, auto_fall_done
    li a0, 0
    li a1, 1
    jal try_move
    jal set_fall_timer

auto_fall_done:

    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

#---------------------------- LOCKED BLOCKS--------------------------
# Similarly to the collision part, this section focuses on keeping the piece locked into places. 
#  It takes your active peiece and once it in place you want the peice to be in, it will lock in.
# This ensures no piece continues to fall based on the timer and remains with the game board.
lock_active_piece:

    addi sp, sp, -24
    sw ra, 20(sp)
    sw s0, 16(sp)
    sw s1, 12(sp)
    sw s2, 8(sp)
    sw s3, 4(sp)
    sw s4, 0(sp)
    lw s0, active_piece
    lw s1, active_x
    lw s2, active_y
    lw s3, active_color
    li s4, 0

lock_piece_row_loop:

    li t0, 4
    bge s4, t0, lock_piece_done
    li t1, 0

lock_piece_col_loop:

    li t0, 4
    bge t1, t0, lock_piece_next_row
    li t0, 4
    mul t2, s4, t0
    add t2, t2, t1
    slli t2, t2, 2
    add t2, s0, t2
    lw t3, 0(t2)
    beqz t3, lock_piece_skip_cell
    add t4, s1, t1
    add t5, s2, s4
    li t6, BOARD_W
    mul t5, t5, t6
    add t5, t5, t4
    slli t5, t5, 2
    la t6, board_grid
    add t5, t5, t6
    sw s3, 0(t5)

lock_piece_skip_cell:

    addi t1, t1, 1
    j lock_piece_col_loop

lock_piece_next_row:

    addi s4, s4, 1
    j lock_piece_row_loop

lock_piece_done:

    lw s4, 0(sp)
    lw s3, 4(sp)
    lw s2, 8(sp)
    lw s1, 12(sp)
    lw s0, 16(sp)
    lw ra, 20(sp)
    addi sp, sp, 24
    jr ra

draw_locked_blocks:

    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)
    li s0, 0

draw_locked_row_loop:

    li t0, BOARD_H
    bge s0, t0, draw_locked_done
    li s1, 0

draw_locked_col_loop:

    li t0, BOARD_W
    bge s1, t0, draw_locked_next_row
    li t0, BOARD_W
    mul t1, s0, t0
    add t1, t1, s1
    slli t1, t1, 2
    la t2, board_grid
    add t1, t1, t2
    lw t3, 0(t1)
    beqz t3, draw_locked_skip_cell
    li t0, BLOCK_SIZE
    mul a0, s1, t0
    addi a0, a0, BOARD_X
    mul a1, s0, t0
    addi a1, a1, BOARD_Y
    mv a2, t3
    jal draw_block

draw_locked_skip_cell:

    addi s1, s1, 1
    j draw_locked_col_loop

draw_locked_next_row:

    addi s0, s0, 1
    j draw_locked_row_loop

draw_locked_done:

    lw s1, 0(sp)
    lw s0, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    jr ra

#---------------------------- RANDOM SPAWN / GAME OVER ----------------------------
# This sections basically uses the ideas we learned from the previous project. 
# In this part the random is the different peiece and ensures there is a way for the player to lose/quit if needed.
spawn_piece:

    addi sp, sp, -8
    sw ra, 4(sp)
    sw s0, 0(sp)
    li t0, TIME_LOW
    lw t1, 0(t0)
    li t2, 7
    remu s0, t1, t2
    slli t3, s0, 2
    la t4, piece_table
    add t4, t4, t3
    lw a0, 0(t4)
    la a1, active_matrix
    jal copy_matrix
    la t4, active_piece
    la t5, active_matrix
    sw t5, 0(t4)
    la t4, color_table
    slli t3, s0, 2
    add t4, t4, t3
    lw t5, 0(t4)
    la t4, active_color
    sw t5, 0(t4)
    la t0, active_x
    li t1, 3
    sw t1, 0(t0)
    la t0, active_y
    li t1, 0
    sw t1, 0(t0)
    jal can_place_active
    beqz a0, game_over
    lw s0, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8
    jr ra

game_over:

    li a7, 10
    ecall

#---------------------------- ROTATION ----------------------------
# This sections basically uses the Java logic with matrix from the drawing the board section and apply the rotation to it.
# This section use the rotate user input for a piece and then rotates it depending on how many times the user wants.
copy_matrix:

    li t0, 0

copy_matrix_loop:

    li t1, 16
    bge t0, t1, copy_matrix_done
    slli t2, t0, 2
    add t3, a0, t2
    lw t4, 0(t3)
    add t5, a1, t2
    sw t4, 0(t5)
    addi t0, t0, 1
    j copy_matrix_loop

copy_matrix_done:

    jr ra

rotate_active_piece:

    addi sp, sp, -4
    sw ra, 0(sp)
    la a0, active_matrix
    la a1, rotate_matrix
    jal rotate_matrix_clockwise
    la a0, rotate_matrix
    lw a1, active_x
    lw a2, active_y
    jal can_place_piece
    beqz a0, rotate_active_done
    la a0, rotate_matrix
    la a1, active_matrix
    jal copy_matrix
    jal redraw_screen

rotate_active_done:

    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

rotate_matrix_clockwise:

    li t0, 0

rotate_row_loop:

    li t1, 4
    bge t0, t1, rotate_matrix_done
    li t2, 0

rotate_col_loop:

    li t1, 4
    bge t2, t1, rotate_next_row
    li t3, 4
    mul t4, t0, t3
    add t4, t4, t2
    slli t4, t4, 2
    add t5, a0, t4
    lw t6, 0(t5)
    li t3, 3
    sub t3, t3, t0
    li t4, 4
    mul t5, t2, t4
    add t5, t5, t3
    slli t5, t5, 2
    add t5, a1, t5
    sw t6, 0(t5)
    addi t2, t2, 1
    j rotate_col_loop

rotate_next_row:

    addi t0, t0, 1
    j rotate_row_loop

rotate_matrix_done:

    jr ra

#---------------------------- LINE CLEARING ----------------------------
# This is the last section for a basic tetris implemention. This is clears lines when the line is full
# depending on the piece and move the peiece/squares above it down.
clear_full_lines:

    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)
    li s0, 19

clear_lines_check_row:

    bltz s0, clear_lines_done
    li s1, 0
    li t0, 1

clear_lines_check_col:

    li t1, BOARD_W
    bge s1, t1, clear_lines_row_checked
    li t1, BOARD_W
    mul t2, s0, t1
    add t2, t2, s1
    slli t2, t2, 2
    la t3, board_grid
    add t2, t2, t3
    lw t4, 0(t2)
    beqz t4, clear_lines_not_full
    addi s1, s1, 1
    j clear_lines_check_col

clear_lines_not_full:

    li t0, 0

clear_lines_row_checked:

    beqz t0, clear_lines_next_row
    mv a0, s0
    jal clear_one_line
    j clear_lines_check_row

clear_lines_next_row:

    addi s0, s0, -1
    j clear_lines_check_row

clear_lines_done:

    lw s1, 0(sp)
    lw s0, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    jr ra

clear_one_line:

    addi sp, sp, -8
    sw ra, 4(sp)
    sw s0, 0(sp)
    mv s0, a0

shift_rows_down:

    beqz s0, clear_top_row
    li t0, 0

copy_row_col_loop:

    li t1, BOARD_W
    bge t0, t1, next_shift_row
    addi t2, s0, -1
    li t1, BOARD_W
    mul t3, t2, t1
    add t3, t3, t0
    slli t3, t3, 2
    la t4, board_grid
    add t3, t3, t4
    lw t5, 0(t3)
    li t1, BOARD_W
    mul t6, s0, t1
    add t6, t6, t0
    slli t6, t6, 2
    la t4, board_grid
    add t6, t6, t4
    sw t5, 0(t6)
    addi t0, t0, 1
    j copy_row_col_loop

next_shift_row:

    addi s0, s0, -1
    j shift_rows_down

clear_top_row:

    li t0, 0

clear_top_col_loop:

    li t1, BOARD_W
    bge t0, t1, clear_one_line_done
    slli t2, t0, 2
    la t3, board_grid
    add t2, t2, t3
    sw zero, 0(t2)
    addi t0, t0, 1
    j clear_top_col_loop

clear_one_line_done:

    lw s0, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8
    jr ra
