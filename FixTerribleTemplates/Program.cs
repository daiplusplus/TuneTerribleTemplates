using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FixTerribleTemplates
{
	public static class Program
	{
		public static void Main( String[] args )
		{
			// CBA to reimplement vswhere.exe: https://github.com/Microsoft/vswhere
			// Do it manually or with command-line args:

			List<String> fileNames;
			{
				DirectoryInfo[] roots = new DirectoryInfo[]
				{
					new DirectoryInfo( @"C:\Program Files (x86)\Microsoft Visual Studio 15.0" ),
					new DirectoryInfo( @"C:\Users\David\Apps\Visual Studio 2017\Templates" ),
					// new DirectoryInfo( @"C:\Users\David\AppData\Local\Microsoft\VisualStudio\15.0_e7c3c18b" )
				};

				fileNames = GetFileNames( roots );
			}
		}

		public static List<String> GetFileNames(IEnumerable<DirectoryInfo> rootDirectories)
		{
			List<String> fileNames = new List<String>();

			foreach( DirectoryInfo root in rootDirectories )
			{
				if( root.Exists )
				{
					GetFileNames( root.Name.Length, root, pathContainsTemplates: false, fileNames );
				}
			}

			return fileNames;
		}

		private static void GetFileNames(Int32 rootPrefixLength, DirectoryInfo directory, Boolean pathContainsTemplates, List<String> fileNames)
		{
			Boolean isTemplateDirectory = pathContainsTemplates || directory.Name.IndexOf( "templates", StringComparison.OrdinalIgnoreCase ) > -1;

			foreach( DirectoryInfo child in directory.GetDirectories() )
			{
				GetFileNames( rootPrefixLength, child, isTemplateDirectory, fileNames );
			}

			if( isTemplateDirectory )
			{
				foreach( FileInfo file in directory.GetFiles("*.cs") )
				{
					fileNames.Add( file.FullName.Substring( startIndex: rootPrefixLength );
				}
			}
		}
	}
}
