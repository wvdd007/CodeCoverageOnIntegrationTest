using Microsoft.VisualStudio.TestTools.CodeCoverage;

namespace CoverageConverter
{
    class Program
    {
        static void Main(string[] args)
        {
            using (CoverageInfo info = CoverageInfo.CreateFromFile(
                "PATH_OF_YOUR_*.coverage_FILE",
                new string[] { @"DIRECTORY_OF_YOUR_DLL_OR_EXE" },
                new string[] { }))
            {
                CoverageDS data = info.BuildDataSet();
                data.WriteXml("converted.coveragexml");
            }
        }
    }
}