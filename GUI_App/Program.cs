// Temat: Dodanie szumu o rozkładzie Gaussa
// Opis: Algorytm wykorzystuje transformację Boxa-Mullera do wygenerowania liczb o rozkładzie Gaussowskim 
// po czym dodawane są one do pikseli
// Semestr: 5
// Rok akademicki: 2025 / 2026
// Autor: Kamil Karwacki
// Wersja: 1.0.0

using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace GUI_App
{
    internal static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Form1());
        }
    }
}
