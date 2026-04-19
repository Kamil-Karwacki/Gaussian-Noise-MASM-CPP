// Temat: Dodanie szumu o rozkładzie Gaussa
// Opis: Algorytm wykorzystuje transformację Boxa-Mullera do wygenerowania liczb o rozkładzie Gaussowskim 
// po czym dodawane są one do pikseli
// Semestr: 5
// Rok akademicki: 2025 / 2026
// Autor: Kamil Karwacki
// Wersja: 1.0.0

using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Globalization;

namespace GUI_App
{

    public partial class Form1 : Form
    {
        [DllImport("Project_ASM_DLL.dll", CallingConvention = CallingConvention.Cdecl, EntryPoint = "DodajASM")]
        public static extern int DodajASM(IntPtr ptr, int width, int height, double strength, int stride);

        [DllImport("Project_CPP_DLL.dll", CallingConvention = CallingConvention.Cdecl, EntryPoint = "ProcessImage")]
        public static extern int ProcessImage(IntPtr ptr, int width, int height, double strength, int stride, int threads);

        public Form1()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            double[] time = new double[20];
            for (int j = 0; j < 21; j++)
            {
                if (pictureBox1.Image == null)
                {
                    InfoLabel.Text = "You must choose an Image!";
                    return;
                }
                Bitmap bmp = ConvertTo32bpp(pictureBox1.ImageLocation);

                Rectangle rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
                BitmapData bmpData = bmp.LockBits(rect, ImageLockMode.ReadWrite, bmp.PixelFormat);

                int processorCount = (int)numericUpDown1.Value;
                Console.WriteLine($"Number of threads: {processorCount}");
                Stopwatch sw = Stopwatch.StartNew();

                if (comboBox1.SelectedIndex == 0)
                {
                    int height = bmp.Height;
                    int width = bmp.Width;
                    int stride = bmpData.Stride;
                    double noiseVal = (double)noiseInput.Value;
                    IntPtr basePtr = bmpData.Scan0;


                    Parallel.For(0, processorCount, i =>
                    {
                        int startY = (height * i) / processorCount;
                        int endY = (height * (i + 1)) / processorCount;
                        int chunkHeight = endY - startY;

                        if (chunkHeight > 0)
                        {
                            IntPtr chunkPtr = IntPtr.Add(basePtr, startY * stride);

                            DodajASM(chunkPtr, width, chunkHeight, noiseVal, stride);
                        }
                    });
                }
                else
                {
                    ProcessImage(bmpData.Scan0, bmp.Width, bmp.Height, ((double)noiseInput.Value), bmpData.Stride, processorCount); //c++
                }
                sw.Stop();

                Console.WriteLine($"Time: {sw.Elapsed.TotalMilliseconds} ms");
                Console.WriteLine($"Ticks: {sw.ElapsedTicks}");
                InfoLabel.Text = $"Time: {sw.Elapsed.TotalMilliseconds} ms";
                if(j != 0)
                    time[j-1] = sw.Elapsed.TotalMilliseconds;
                bmp.UnlockBits(bmpData);

                pictureBox2.Image = bmp;
                pictureBox2.Refresh();
                Console.WriteLine($"Added noise to the image {pictureBox1.ImageLocation} strength: {noiseInput.Value}");
            }

            string[] czasy = time.Select(d => d.ToString(new CultureInfo("pl-PL"))).ToArray();
            File.WriteAllLines("czasy.csv", czasy);
        }

        private Bitmap ConvertTo32bpp(string sciezkaDoPliku)
        {
            using (Bitmap oryginal = new Bitmap(sciezkaDoPliku))
            {
                Bitmap nowaBitmapa = new Bitmap(oryginal.Width, oryginal.Height, PixelFormat.Format32bppArgb);

                using (Graphics g = Graphics.FromImage(nowaBitmapa))
                {
                    g.DrawImage(oryginal, 0, 0, oryginal.Width, oryginal.Height);
                }

                return nowaBitmapa;
            }
        }

        private void browse_btn_Click(object sender, EventArgs e)
        {
            OpenFileDialog openFileDialog = new OpenFileDialog();

            openFileDialog.Filter = "Image Files|*.jpg;*.jpeg;*.png;*.bmp;*.gif";
            openFileDialog.Title = "Select an Image";

            if (openFileDialog.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    pictureBox1.ImageLocation = openFileDialog.FileName;
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Error loading image: " + ex.Message);
                }
            }
        }

        private void flowLayoutPanel1_Paint(object sender, PaintEventArgs e)
        {

        }

        private void saveBtn_Click(object sender, EventArgs e)
        {
            if (pictureBox2.Image == null)
            {
                InfoLabel.Text = "You have not processed image yet!";
                return;
            }
            using (SaveFileDialog sfd = new SaveFileDialog())
            {
                // ustawienia okna dialogowego
                sfd.Title = "Save processed image";
                sfd.Filter = "Obraz PNG (*.png)|*.png|Obraz JPEG (*.jpg)|*.jpg|Mapa bitowa (*.bmp)|*.bmp";
                sfd.FileName = "result"; // domyślna nazwa pliku
                sfd.DefaultExt = "png"; // domyślne rozszerzenie
                sfd.AddExtension = true;

                if (sfd.ShowDialog() == DialogResult.OK)
                {
                    Image imgToSave = pictureBox2.Image;

                    ImageFormat format = ImageFormat.Png;

                    switch (sfd.FilterIndex)
                    {
                        case 1: format = ImageFormat.Png; break;
                        case 2: format = ImageFormat.Jpeg; break;
                        case 3: format = ImageFormat.Bmp; break;
                    }

                    try
                    {
                        imgToSave.Save(sfd.FileName, format);
                        MessageBox.Show("File saved succesfully!", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Error while saving: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
            }
        }
    }
}
