# Mini OS

### Intro.

An embedded miniOS scheduling 3 tasks.

- **Hardware** [ZedBoard](http://www.zedboard.org/product/zedboard) based on Zynq-7000 XC7Z020-CLG484-1

- **Development Toos** Vivado (ver. 19.1) & SDK

- All of 3 tasks run forever.

    - **Task1** Selection Sorting

        ​	Its outcome is displayed on LEDs.

    - **Task2** DhryStone Benchmark

        ​	Used to measure the CPU performance

        ​	Some messages will be printed on UART console.

    - **Task3** Hello World

        ​	Output to UART console.

- **Scheduling Algorithm** Round-Robin

