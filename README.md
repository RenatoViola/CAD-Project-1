# Particle Storm Simulation with CUDA

This project uses CUDA to accelerate a simulation of particle impacts on a surface. The simulator tracks the energy deposited along a one-dimensional cross-section and identifies the location of the highest energy peak after each wave.

The work starts by profiling a sequential C baseline, then moves the most expensive calculations to GPU kernels. The project report compares the sequential and CUDA implementations across different input sizes and documents the profiling and optimisation decisions.

Developed by João Tomás and Renato Viola. The project builds on the sequential simulator by Arturo Gonzalez-Escribano and Eduardo Rodriguez-Gutiez.

[CUDA source](src/energy_storms_cuda.cu) · [Project report](REPORT/main.pdf) · [License](LICENSE)
