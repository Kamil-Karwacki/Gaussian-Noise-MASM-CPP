// Temat: Dodanie szumu o rozk³adzie Gaussa
// Opis: Algorytm wykorzystuje transformacjê Boxa - Mullera do wygenerowania liczb o rozk³adzie Gaussowskim
//       po czym dodawane s¹ one do pikseli
// Semestr: 5
// Rok akademicki : 2025 / 2026
// Autor: Kamil Karwacki
// Wersja: 1.0.0
#include "pch.h"
#include <cmath>
#include <algorithm>
#include <vector>
#include <thread>
#include <random>
#include <ctime>

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

void AddNoiseWorker(unsigned char* basePtr, int width, int startY, int endY, int channels, int stride, double stddev)
{
    const double PI = 3.14159;

    std::hash<std::thread::id> hasher;
    unsigned int seed = static_cast<unsigned int>(time(nullptr)) + hasher(std::this_thread::get_id());
    std::mt19937 gen(seed);

    std::uniform_real_distribution<double> dist(0.0, 1.0);

    double spareValue = 0.0;
    bool hasSpare = false;

    auto getNextNoise = [&]() -> double {
        if (hasSpare) {
            hasSpare = false;
            return spareValue;
        }

        double u1 = dist(gen);
        double u2 = dist(gen);

        // Zabezpieczenie co by nie by³o log(0)
        if (u1 < 1e-9) u1 = 1e-9;

        double magnitude = std::sqrt(-2.0 * std::log(u1));

        spareValue = magnitude * std::sin(2.0 * PI * u2);
        hasSpare = true;
        return magnitude * std::cos(2.0 * PI * u2);
    };

    for (int y = startY; y < endY; y++)
    {
        unsigned char* rowPtr = basePtr + (y * stride);

        for (int x = 0; x < width; x++)
        {
            int pixelOffset = x * channels;

            auto noiseVal = getNextNoise();
            int noiseInt = static_cast<int>(noiseVal * stddev);

            for (int c = 0; c < 3; c++) // R, G, B
            {
                int val = rowPtr[pixelOffset + c] + noiseInt;

                if (val > 255) val = 255;
                else if (val < 0) val = 0;

                rowPtr[pixelOffset + c] = static_cast<unsigned char>(val);
            }
        }
    }
}

extern "C" __declspec(dllexport) int ProcessImage(unsigned char* ptr, int width, int height, double strength, int stride, int numThreads)
{
    std::vector<std::thread> threads;
    threads.reserve(numThreads);

    // podzia³ na chunki
    int chunkHeight = height / numThreads;
    int remainder = height % numThreads;

    int startY = 0;

    for (unsigned int i = 0; i < numThreads; i++)
    {
        // ostatni w¹tek bierze remainder
        int endY = startY + chunkHeight + (i == numThreads - 1 ? remainder : 0);

        // uruchomienie w¹tku
        threads.emplace_back(AddNoiseWorker, ptr, width, startY, endY, 4, stride, strength);

        startY = endY;
    }

    // czekamy a¿ wszystkie w¹tki skoñcz¹ pracê
    for (auto& t : threads) {
        if (t.joinable()) {
            t.join();
        }
    }

    return 1;
}