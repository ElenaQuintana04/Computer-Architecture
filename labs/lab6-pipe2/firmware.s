.section .text
.global main
.global _start

_start: 
  li t0, 0
  li t1, 1
  li t2, 11
  
  loop:
    add, t0, t0, t1
    addi, t1, t1, 1
    bne t1, t2, loop
  
  addi, x10, t0, 0
  ebreak
