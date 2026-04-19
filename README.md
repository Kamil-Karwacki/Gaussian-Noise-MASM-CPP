# Gaussian Noise Generator (MASM vs C++)

The main goal of this project is the practical implementation of multithreading and a direct performance comparison of the same algorithm written in C++ and 64-bit Assembly (MASM).
<img width="1858" height="1080" alt="image" src="https://github.com/user-attachments/assets/8bd0d81d-a9f4-4bfc-800f-a70344035040" />

## Technologies
* **GUI:** C# (WinForms)
* **C++:** C++ (Dynamic-link library)
* **ASM Engine:** x64 MASM (Dynamic-link library)
* **Environment:** Visual Studio

## Project Structure
The solution consists of three main modules:
* `GUI_App` – The user interface that allows loading an image, specifying the number of threads, selecting the computing backend (ASM or C++), and displaying the execution time.
* `Project_CPP_DLL` – A C++ DLL containing the noise generator implementation.
* `Projekt_JA` – A DLL containing the low-level 64-bit Assembly (MASM) implementation of the generator.

## How to Run

1. Clone the repository:  
```bash
   git clone https://github.com/Kamil-Karwacki/Gaussian-Noise-MASM-CPP.git
```

2. Open the Projekt_JA.sln solution file in Visual Studio.
3. Ensure the target platform is set to x64 (the assembly code is strictly 64-bit).
4. For accurate performance benchmarking, change the build configuration from Debug to Release.
5. Set GUI_App as the Startup Project (Right-click -> Set as Startup Project).
6. Build and run the application (Ctrl + F5).

## Performance Analysis & Insights

A detailed technical report with benchmark graphs (in Polish) is available in the [`docs/`](docs/) folder: **[Performance_Report_PL.pdf](docs/Performance_Report_PL.pdf)**. 

**Key technical takeaways from the benchmark:**
* **The Box-Muller Bottleneck:** While the ASM implementation is generally faster in pixel processing, the Box-Muller transform itself proved to be a bottleneck. It heavily relies on logarithmic and trigonometric functions (FPU), which lack direct, single-instruction vector (SIMD) equivalents in the utilized instruction set.
* **Architectural Optimization:** To achieve massive performance gains in pure Assembly, the **Irwin-Hall distribution** is proposed as a substitute for Box-Muller. Because Irwin-Hall relies on summing uniformly distributed variables, it completely eliminates expensive FPU trigonometry and allows for full vectorization.
* **SIMD & Saturation Arithmetic:** The MASM implementation utilizes AVX/SSE instructions (e.g., `vpbroadcastw`, `vpunpcklqdq`) and relies on **saturation arithmetic** (`vpackuswb`). This efficiently applies noise to 32bpp ARGB pixels in parallel while naturally preventing integer overflow (color wrapping).
* **Threading Overhead:** Benchmarks (up to 64 threads on an i5-12400f) revealed that the C++ `std::thread` implementation suffers from significant performance degradation at higher thread counts. The overhead of creating and managing threads simply outweighed the time saved on processing small image chunks.
