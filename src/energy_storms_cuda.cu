/*
 * Simplified simulation of high-energy particle storms
 *
 * Parallel computing (Degree in Computer Engineering)
 * 2017/2018
 *
 * Version: 2.0
 *
 * Code prepared to be used with the Tablon on-line judge.
 * The current Parallel Computing course includes contests using:
 * OpenMP, MPI, and CUDA.
 *
 * (c) 2018 Arturo Gonzalez-Escribano, Eduardo Rodriguez-Gutiez
 * Grupo Trasgo, Universidad de Valladolid (Spain)
 *
 * This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
 * https://creativecommons.org/licenses/by-sa/4.0/
 */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <sys/time.h>

/* Headers for the CUDA assignment versions */
#include <cuda_profiler_api.h>

#include <cuda.h>

#include <cuda_runtime.h>
// #include <cuda_profiler_api.h>

/* Use fopen function in local tests. The Tablon online judge software
   substitutes it by a different function to run in its sandbox */
#ifdef CP_TABLON
#include "cputilstablon.h"
#else
#define cp_open_file(name) fopen(name, "r")
#endif

/* Function to get wall time */
double cp_Wtime()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + 1.0e-6 * tv.tv_usec;
}

#define THRESHOLD 0.001f
#define THREADS_PER_BLOCK 1024
#define N (2048 * 2048)

/* Structure used to store data for one storm of particles */
typedef struct
{
    int size;    // Number of particles
    int *posval; // Positions and values
} Storm;

/* THIS FUNCTION CAN BE MODIFIED */
/* Function to update a single position of the layer */
__device__ void update(float *d_layer, int layer_size, int k, int pos, float energy)
{
    /* 1. Compute the absolute value of the distance between the
        impact position and the k-th position of the layer */
    int distance = pos - k;
    if (distance < 0)
        distance = -distance;

    /* 2. Impact cell has a distance value of 1 */
    distance = distance + 1;

    /* 3. Square root of the distance */
    /* NOTE: Real world atenuation typically depends on the square of the distance.
       We use here a tailored equation that affects a much wider range of cells */
    float atenuacion = sqrtf((float)distance);

    /* 4. Compute attenuated energy */
    float energy_k = energy / layer_size / atenuacion;

    /* 5. Do not add if its absolute value is lower than the threshold */
    if (energy_k >= THRESHOLD / layer_size || energy_k <= -THRESHOLD / layer_size)
        d_layer[k] = d_layer[k] + energy_k;
}

/* ANCILLARY FUNCTIONS: These are not called from the code section which is measured, leave untouched */
/* DEBUG function: Prints the layer status */
void debug_print(int layer_size, float *layer, int *positions, float *maximum, int num_storms)
{
    int i, k;
    /* Only print for array size up to 35 (change it for bigger sizes if needed) */
    if (layer_size <= 35)
    {
        /* Traverse layer */
        for (k = 0; k < layer_size; k++)
        {
            /* Print the energy value of the current cell */
            printf("%10.4f |", layer[k]);

            /* Compute the number of characters.
               This number is normalized, the maximum level is depicted with 60 characters */
            int ticks = (int)(60 * layer[k] / maximum[num_storms - 1]);

            /* Print all characters except the last one */
            for (i = 0; i < ticks - 1; i++)
                printf("o");

            /* If the cell is a local maximum print a special trailing character */
            if (k > 0 && k < layer_size - 1 && layer[k] > layer[k - 1] && layer[k] > layer[k + 1])
                printf("x");
            else
                printf("o");

            /* If the cell is the maximum of any storm, print the storm mark */
            for (i = 0; i < num_storms; i++)
                if (positions[i] == k)
                    printf(" M%d", i);

            /* Line feed */
            printf("\n");
        }
    }
}

/*
 * Function: Read data of particle storms from a file
 */
Storm read_storm_file(char *fname)
{
    FILE *fstorm = cp_open_file(fname);
    if (fstorm == NULL)
    {
        fprintf(stderr, "Error: Opening storm file %s\n", fname);
        exit(EXIT_FAILURE);
    }

    Storm storm;
    int ok = fscanf(fstorm, "%d", &(storm.size));
    if (ok != 1)
    {
        fprintf(stderr, "Error: Reading size of storm file %s\n", fname);
        exit(EXIT_FAILURE);
    }

    storm.posval = (int *)malloc(sizeof(int) * storm.size * 2);
    if (storm.posval == NULL)
    {
        fprintf(stderr, "Error: Allocating memory for storm file %s, with size %d\n", fname, storm.size);
        exit(EXIT_FAILURE);
    }

    int elem;
    for (elem = 0; elem < storm.size; elem++)
    {
        ok = fscanf(fstorm, "%d %d\n",
                    &(storm.posval[elem * 2]),
                    &(storm.posval[elem * 2 + 1]));
        if (ok != 2)
        {
            fprintf(stderr, "Error: Reading element %d in storm file %s\n", elem, fname);
            exit(EXIT_FAILURE);
        }
    }
    fclose(fstorm);

    return storm;
}

__global__ void func_3(int layer_size, float *d_layer, float *d_layer_copy)
{
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index < layer_size)
    {
        d_layer[index] = 0.0f;
        d_layer_copy[index] = 0.0f;
    }
}

__global__ void func_4_1(int layer_size, float *d_layer, int position, float energy)
{
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index < layer_size)
        update(d_layer, layer_size, index, position, energy);
}

__global__ void func_4_2_1(int layer_size, float *d_layer, float *d_layer_copy)
{
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index < layer_size)
        d_layer_copy[index] = d_layer[index];
}

__global__ void func_4_2_2(int layer_size, float *d_layer, float *d_layer_copy)
{
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    if (index > 0 && index < layer_size - 1)
        d_layer[index] = (d_layer_copy[index - 1] + d_layer_copy[index] + d_layer_copy[index + 1]) / 3;
}

__global__ void func_4_3_kernel(float *d_layer, float *d_maxValues, int *d_maxPositions, int layer_size)
{
    __shared__ float sdata[THREADS_PER_BLOCK];
    __shared__ int sindices[THREADS_PER_BLOCK];

    int tid = threadIdx.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < layer_size)
    {
        sdata[tid] = d_layer[idx];
        sindices[tid] = idx;
    }

    __syncthreads();

    for (unsigned int s = THREADS_PER_BLOCK / 2; s > 0; s /= 2)
    {
        int strideIndex = tid + s;
        if (tid < s && strideIndex < layer_size - 1)
        {
            if (sdata[strideIndex] > sdata[strideIndex - 1] && sdata[strideIndex] > sdata[strideIndex + 1])
            {
                if (sdata[tid] < sdata[strideIndex])
                {
                    sdata[tid] = sdata[strideIndex];
                    sindices[tid] = sindices[strideIndex];
                }
            }
        }

        __syncthreads();
    }

    if (tid == 0)
    {
        d_maxValues[blockIdx.x] = sdata[0];
        d_maxPositions[blockIdx.x] = sindices[0];
    }
}

void func_4_3(int i, int layer_size, int nBlocks, float *d_layer, float *maximum, int *positions)
{
    float *maxValues = (float *)malloc(nBlocks * sizeof(float));
    int *maxPositions = (int *)malloc(nBlocks * sizeof(int));

    float *d_maxValues;
    int *d_maxPositions;

    cudaMalloc((void **)&d_maxValues, nBlocks * sizeof(float));
    cudaMalloc((void **)&d_maxPositions, nBlocks * sizeof(int));

    func_4_3_kernel<<<nBlocks, THREADS_PER_BLOCK>>>(d_layer, d_maxValues, d_maxPositions, layer_size);

    cudaMemcpy(maxValues, d_maxValues, nBlocks * sizeof(float), cudaMemcpyDeviceToHost);
    cudaMemcpy(maxPositions, d_maxPositions, nBlocks * sizeof(int), cudaMemcpyDeviceToHost);

    float max = -MAXFLOAT;
    int pos = -1;

    for (int j = 0; j < nBlocks; j++)
    {
        if (maxValues[j] > max)
        {
            max = maxValues[j];
            pos = maxPositions[j];
        }
    }

    maximum[i] = max;
    positions[i] = pos;

    cudaFree(d_maxValues);
    cudaFree(d_maxPositions);
    free(maxValues);
    free(maxPositions);
}

/*
 * MAIN PROGRAM
 */
int main(int argc, char *argv[])
{
    int i;

    /* 1.1. Read arguments */
    if (argc < 3)
    {
        fprintf(stderr, "Usage: %s <size> <storm_1_file> [ <storm_i_file> ] ... \n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int layer_size = atoi(argv[1]);
    int num_storms = argc - 2;
    Storm storms[num_storms];

    /* 1.2. Read storms information */
    for (i = 2; i < argc; i++)
        storms[i - 2] = read_storm_file(argv[i]);

    /* 1.3. Intialize maximum levels to zero */
    float maximum[num_storms];
    int positions[num_storms];
    for (i = 0; i < num_storms; i++)
    {
        maximum[i] = 0.0f;
        positions[i] = 0;
    }

    /* 2. Begin time measurement */
    cudaSetDevice(0);
    cudaDeviceSynchronize();
    double ttotal = cp_Wtime();

    /* START: Do NOT optimize/parallelize the code of the main program above this point */

    /* 3. Allocate memory for the layer and initialize to zero */
    int size = sizeof(float) * layer_size;
    int nBlocks = (layer_size + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    //  Memory allocation in host
    float *layer = (float *)malloc(size);
    float *layer_copy = (float *)malloc(size);
    if (layer == NULL || layer_copy == NULL)
    {
        fprintf(stderr, "Error: Allocating the layer memory\n");
        exit(EXIT_FAILURE);
    }

    //  Memory allocation in device
    float *d_layer, *d_layer_copy;
    cudaMalloc((void **)&d_layer, size);
    cudaMalloc((void **)&d_layer_copy, size);

    func_3<<<nBlocks, THREADS_PER_BLOCK>>>(layer_size, d_layer, d_layer_copy);

    /* 4. Storms simulation */
    for (i = 0; i < num_storms; i++)
    {
        /* 4.1. Add impacts energies to layer cells */
        for (int j = 0; j < storms[i].size; j++)
        {
            /* Get impact energy (expressed in thousandths) */
            float energy = (float)storms[i].posval[j * 2 + 1] * 1000;
            /* Get impact position */
            int position = storms[i].posval[j * 2];

            /* For each cell in the layer */
            func_4_1<<<nBlocks, THREADS_PER_BLOCK>>>(layer_size, d_layer, position, energy);
        }

        /* 4.2. Energy relaxation between storms */
        /* 4.2.1. Copy values to the ancillary array */
        func_4_2_1<<<nBlocks, THREADS_PER_BLOCK>>>(layer_size, d_layer, d_layer_copy);

        /* 4.2.2. Update layer using the ancillary values.
                  Skip updating the first and last positions */
        func_4_2_2<<<nBlocks, THREADS_PER_BLOCK>>>(layer_size, d_layer, d_layer_copy);

        /* 4.3. Locate the maximum value in the layer, and its position */
        func_4_3(i, layer_size, nBlocks, d_layer, maximum, positions);
    }

    cudaMemcpy(layer, d_layer, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(layer_copy, d_layer_copy, size, cudaMemcpyDeviceToHost);
    cudaFree(d_layer);
    cudaFree(d_layer_copy);

    /* END: Do NOT optimize/parallelize the code below this point */
    /* 5. End time measurement */
    ttotal = cp_Wtime() - ttotal;
    

/* 6. DEBUG: Plot the result (only for layers up to 35 points) */
#ifdef DEBUG
    debug_print(layer_size, layer, positions, maximum, num_storms);
#endif

    /* 7. Results output, used by the Tablon online judge software */
    printf("\n");
    /* 7.1. Total computation time */
    printf("Time: %lf\n", ttotal);
    /* 7.2. Print the maximum levels */
    printf("Result:");
    for (i = 0; i < num_storms; i++)
        printf(" %d %f", positions[i], maximum[i]);
    printf("\n");

    /* 8. Free resources */
    for (i = 0; i < argc - 2; i++)
        free(storms[i].posval);

    /* 9. Program ended successfully */
    return 0;
}
