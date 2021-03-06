#include "csd_zynq_peripherals.h"
#include "uart_regs.h"
#include "uart_init.s"

#define TIME_LOAD_VALUE 41624
#define CPSR_INIT_VALUE 0x6000050

.extern task1_c
.extern task2_c
.extern task3_c

.align 8

csd_vector_table:
    b csd_reset
    b .
    b .
    b .
    b .
    b .
    b csd_irq
    b .

.global main

csd_reset:
main:
@ System Setup ********************************************************** BEGIN

    cpsID i // disable IRQ interrupt to setup CPU: CPSR'I = 1

  // Stack Setup for Each Mode -------------------------------- BEGIN
    // * IRQ Stack
    cps #0x12
    ldr sp, =irq_stack_top
  // Stack Setup for Each Mode ---------------------------------- END

  // Vector Table Setup --------------------------------------- BEGIN
    cps #0x1f // enter SYS mode to change VBAR
    ldr r0, =csd_vector_table
    mcr p15, 0, r0, c12, c0, 0
    dsb
    isb
  // Vector Table Setup ----------------------------------------- END

@ System Setup ************************************************************ END

@ Configuration ********************************************************* BEGIN

  // Private Timer -------------------------------------------- BEGIN
    // * Private Timer Control Reg (Prescalar = 7, IRQ Enabled, AutoReload Mode, Timer Disabled)
    ldr r0, =PRIVATE_CONTROL
    ldr r1, [r0]
    mov r2, #0xff07 // select bits
    bic r1, r1, r2 // clear [15:8](prescalar) and disable [2:0](IRQ, AutoReload, TimerEnable)
    mov r2, #0x0706 // select bits
    orr r1, r1, r2 // set [15:8]=63=0b0000_0111 and [2:0]=0b110
    str r1, [r0]
    // * Private Timer Load Reg (LoadValue = 41624)
    ldr r0, =PRIVATE_LOAD
    ldr r1, =TIME_LOAD_VALUE
    str r1, [r0]
    // * Private Timer Interrupt Status Register (write PRIVATE_STATUS[0] = 1 to clear event flag)
    ldr r0, =PRIVATE_STATUS
    ldr r1, [r0]
    orr r1, r1, #1
    str r1, [r0]
  // Private Timer ---------------------------------------------- END

  // UART Setup ----------------------------------------------- BEGIN
    uart_init
  // UART Setup ------------------------------------------------- END

  // GIC Setup ------------------------------------------------ BEGIN
    // * GICD
    ldr r0, =GICD_CTLR // enable GICD: GICD_CTLR[0] = 1
    ldr r1, [r0]
    mov r2, #1
    orr r1, r1, r2
    str r1, [r0]
    ldr r0, =GICD_ISENABLER0 // set Interrupt Set-Enable Register 0, each bit for one src
    ldr r1, [r0]
    mov r2, #1 << 29 // enable src#29(Private Timer)
    orr r1, r1, r2
    str r1, [r0]
    ldr r0, =GICD_PRIOR7 // set Interrupt Priority Register #7 (7 = ceiling(29 % 4) - 1, since index start from 0)
    ldr r1, [r0]
    mov r2, #0x10 << 8 // set priority as 16 for src#29(Private Timer)
    orr r1, r1, r2
    str r1, [r0]
    // * GICC
    ldr r0, =GICC_CTLR // enable GICC: GICC_CTLR[0] = 1
    ldr r1, [r0]
    mov r2, #1
    orr r1, r1, r2
    str r1, [r0]
    ldr r0, =GICC_PMR // set priority mask
    ldr r1, [r0]
    mov r2, #0xff // use lowest threshold, which does not mask any interrupt actually
    orr r1, r1, r2
    str r1, [r0]
    ldr r0, =GICC_BPR // set binary point
    ldr r1, [r0]
    mov r2, #0x7 // use none group priority, so there'll not be preemption
    orr r1, r1, r2
    str r1, [r0]
  // GIC -------------------------------------------------------- END

@ Configuration *********************************************************** END

@ Application *********************************************************** BEGIN

  // TCB Setup ------------------------------------------------ BEGIN
    // * Task1
    ldr r0, =task1_tcb // tcb addr
    ldr r1, =task1_stack_irq_btm // irq stack (context backup stack)
    str r1, [r0]
    ldr r1, =task1_c // C code
    str r1, [r0, #4]
    ldr r1, =task2_tcb // next tcb
    str r1, [r0, #8]
    // * Task2
    ldr r0, =task2_tcb // tcb addr
    ldr r1, =task2_stack_irq_btm // irq stack (context backup stack)
    str r1, [r0]
    ldr r1, =task2_c // C code
    str r1, [r0, #4]
    ldr r1, =task3_tcb
    str r1, [r0, #8]
    // * Task3
    ldr r0, =task3_tcb // tcb addr
    ldr r1, =task3_stack_irq_btm // irq stack (context backup stack)
    str r1, [r0]
    ldr r1, =task3_c // C code
    str r1, [r0, #4]
    ldr r1, =task1_tcb // next tcb
    str r1, [r0, #8]
  // TCB Setup -------------------------------------------------- END

  // IRQ Stack Setup ------------------------------------------ BEGIN
    // * Task1
    ldr r0, =task1_stack_irq_top
    ldr r1, =CPSR_INIT_VALUE
    str r1, [r0, #-64] // modify cpsr
    ldr r1, =task1_stack_usr_top
    str r1, [r0, #-8] // modify sp
    // * Task2
    ldr r0, =task2_stack_irq_top
    ldr r1, =CPSR_INIT_VALUE
    str r1, [r0, #-64] // modify cpsr
    ldr r1, =task2_stack_usr_top
    str r1, [r0, #-8] // modify sp
    // * Task3
    ldr r0, =task3_stack_irq_top
    ldr r1, =CPSR_INIT_VALUE
    str r1, [r0, #-64] // modify cpsr
    ldr r1, =task3_stack_usr_top
    str r1, [r0, #-8] // modify sp
  // IRQ Stack Setup -------------------------------------------- END

  // Current Task Selection ----------------------------------- BEGIN
    ldr r0, =curr_tcb_ptr
    ldr r1, =task1_tcb
    str r1, [r0] // set task1 as the first task
  // Current Task Selection ------------------------------------- END

@ Application ************************************************************* END

@ Start Execution ******************************************************* BEGIN

    // * Enable Private Timer: PRIVATE_CONTROL[0] = 1
    ldr r0, =PRIVATE_CONTROL
    ldr r1, [r0]
    mov r2, #0x1
    orr r1, r1, r2
    str r1, [r0] // time starts from now since PRIVATE_CONTROL[0] is set

    cps #0x12 // enter IRQ mode to use its registers

    // * Read TCB of Current Task
    ldr r0, =curr_tcb_ptr // read tcb of the first task
    ldr r1, [r0] // r1 = *(curr_tcb_ptr) = pointer of current task's tcb
    ldr sp, [r1] // sp_irq = task's stack_irq
    ldr lr, [r1, #4] // lr_irq = task's pc
    ldr r0, [sp], #4 // spsr_irq = task's cpsr
    msr spsr, r0
    // * Set Context
    ldmfd sp, {r0-r14}^ // set context of task
    add sp, sp, #60 // modify sp
    // * Start Task
    movs pc, lr // since spsr_irq[Mode] == usr, CPU will run in usr mode from now

@ Start Execution ********************************************************* END


forever: // should never come to here
    b .


csd_irq: // context switching
@ IRQ ******************************************************************* BEGIN

  // Save Context & Update Info ------------------------------- BEGIN
    // * Save Context
    stmfd sp, {r0-r14}^ // push r0-r14
    sub sp, sp, #60
    mrs r0, spsr // push cpsr
    str r0, [sp, #-4]!
    // * Update TCB of Current Task
    ldr r0, =curr_tcb_ptr // read tcb of the first task
    ldr r1, [r0] // r1 = *(curr_tcb_ptr) = pointer of current task's tcb
    str sp, [r1] // update stack_irq_ptr
    sub lr, lr, #4 // modify task's pc
    str lr, [r1, #4] // update pc_task
    // * Update Current Task Pointer
    ldr r2, [r1, #8] // read the next task's tcb
    str r2, [r0] // update curr_tcb_ptr to it
  // Save Context & Update Info --------------------------------- END

  // Handle Interrupt ----------------------------------------- BEGIN
    // * Read ACK
  	ldr r0, =GICC_IAR
    ldr r12, [r0]
    // * Clear Event Flag of Timer
    ldr r0, =PRIVATE_STATUS
    ldr r1, [r0] // reread status register
    orr r1, r1, #1 // clear the event flag
    str r1, [r0] // store it back to the status register
    // * Mark the End of Interrupt
    ldr r0, =GICC_EOIR
    str r12, [r0]
  // Handle Interrupt ------------------------------------------- END

  // Recover Context ------------------------------------------ BEGIN
    // * Read TCB of Current Task
    ldr r0, =curr_tcb_ptr // read tcb of the first task
    ldr r1, [r0] // r1 = *(curr_tcb_ptr) = pointer of current task's tcb
    ldr sp, [r1] // sp_irq = task's stack_irq
    ldr lr, [r1, #4] // lr_irq = task's pc
    ldr r0, [sp], #4 // spsr_irq = task's cpsr
    msr spsr, r0
    // * Set Context
    ldmfd sp, {r0-r14}^ // set context of task
    add sp, sp, #60
    // * Start Task
    movs pc, lr // since spsr_irq[Mode] == usr, CPU will run in usr mode from now
  // Recover Context -------------------------------------------- END

@ IRQ ********************************************************************* END




.data
.align 4

// IRQ stack (context backup stack for tasks, [sp] need to be initialized!!)
irq_stack_btm:
    task1_stack_irq_btm: // after saving context (ldr from here)
        .space 64 // context backup
    task1_stack_irq_top: // before saving context

    task2_stack_irq_btm:
        .space 64 // context backup
    task2_stack_irq_top:

    task3_stack_irq_btm:
        .space 64 // context backup
    task3_stack_irq_top:
irq_stack_top:

// User Stacks
task1_stack_usr_btm:
    .space 1024 // execution stack
task1_stack_usr_top:

task2_stack_usr_btm:
    .space 1024 // execution stack
task2_stack_usr_top:

task3_stack_usr_btm:
    .space 1024 // execution stack
task3_stack_usr_top:

// TCBs
// current TCB pointer
curr_tcb_ptr:
    .space 4
/*
struct TCB {
    tcb1_stack_irq_ptr; // low address
    tcb1_lr_ptr;
    tcb1_next_ptr;      // high address
};
*/
// TCB1
task1_tcb:
    .space 12
// TCB2
task2_tcb:
  .space 12
// TCB3
task3_tcb:
    .space 12
