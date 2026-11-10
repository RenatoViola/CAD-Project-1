# Instructions for running code

Build:

    - Enter the 'src' directory, as you will find a Makefile inside it.

        Running 'make all' in the command line will provide you with 3 executables inside the 'src' folder: 
            energy_storms_seq: Sequential version, in C;
            energy_storms_cuda: Parallelized version, in CUDA;
            energy_storms_gprof: Sequential version, in C, ready for profiling with gprof.


Run:

    - In the project's directory, there is a bash script called 'script.sh'. It facilitates running the program with the set of tests you choose, as well as profiling it.


    Test:

        The script's arguments are: 
            - the version of the program ('seq' or 'cuda')
            - the number of the set of tests to run
            - the number of control points

        Example of use: << Run the 'cuda' version with the set of tests 8 and 100_000_000 control points >>
            In the project's directory, you'd write the following commmand in the terminal:
                bash script.sh cuda 8 100000000

            You'll find the result of this execution in a folder called 'results'. The file is named as 'resultsCUDA.csv', in this case.
            Note: Other executions of the 'cuda' version will be appended to this file, works the same for the 'seq' version.


    Benchmark:

        You'll run the script exactly as in the previous section, but now you choose a profiler instead of the version of the program.
        In place of the version, you may now have either 'gprof' or 'nvprof'.
       
        GPROF - Example of use: << Profile the program with 'gprof', using set of tests 2 and 30_000 control points >>.
            In the project's directory, you'd write the following commmand in the terminal:
                    bash script.sh gprof 2 30000

            You'll find the result of this execution in a folder called 'gprof_results'. The file is named as 'gprof_test_2.csv', in this case.
            Note: Executing the profiling with the same test will overwrite this file. 

        NVPROF - Example of use: << Profile the program with 'nvprof', using set of tests 7 and 1_000_000 control points >>.
            In the project's directory, you'd write the following commmand in the terminal:
                    bash script.sh nvprof 7 1000000

            You'll find the result of this execution in a folder called 'nvprof_results'. The file is named as 'nvprof_test_7.csv', in this case.
            Note: Executing the profiling with the same test will overwrite this file. 