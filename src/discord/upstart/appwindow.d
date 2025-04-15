
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.appwindow;

import core.atomic;
import core.sys.posix.signal : kill, SIGINT;
import core.thread;

import std.conv;
import std.exception;
import std.net.curl;
import std.path;
import std.process;
import std.string;

import glib.MainContext;

import gdk.Event;

import gtk.ApplicationWindow;
import gtk.Builder;
import gtk.Button;
import gtk.Label;
import gtk.ProgressBar;
import gtk.Widget;

import vte.Terminal;

import discord.upstart.app;
import discord.upstart.start;
import discord.upstart.syscall;
import discord.upstart.util;

immutable string glade = import("main.glade");

class AppWindow : ApplicationWindow
{
	string releaseChannel;
	
	Label label;
	ProgressBar progressBar;
	Terminal terminal;
	Button buttonCancel;
	
	this(App app, string releaseChannel)
	{
		Builder builder = new Builder();
		builder.setApplication(app);
		builder.addFromString(glade);
		ApplicationWindow applicationWindow = cast(ApplicationWindow)builder.getObject("appWindow");
		
		this.releaseChannel = releaseChannel;
		this.label = cast(Label)builder.getObject("label");
		this.progressBar = cast(ProgressBar)builder.getObject("progressBar");
		this.terminal = cast(Terminal)builder.getObject("terminal");
		this.buttonCancel = cast(Button)builder.getObject("buttonCancel");
		
		this(applicationWindow.getApplicationWindowStruct());
		
		this.setApplication(app);
		this.setTitle("Discord Upstart");
	}
	
	this(GtkApplicationWindow* gtkApplicationWindow, bool ownedRef = false)
	{
		super(gtkApplicationWindow, ownedRef);
		initSignals();
	}
	
	private void initSignals()
	{
		addOnDelete(&onDelete);
		addOnShow(&onShow);
		buttonCancel.addOnClicked(&buttonCancel_onClick);
		terminal.addOnChildExited(&terminal_childExited);
	}
	
	bool done = false;
	
	void terminal_childExited(int status, Terminal)
	{
		aptPid = 0;
		if (isCancelled)
		{
			this.getApplication.quit();
		}
		else if (status == 0)
		{
			execDiscord();
		}
		else
		{
			terminal.feed("Failed with exit status: ");
			terminal.feed(status.to!string);
		}
		done = true;
	}
	
	void buttonCancel_onClick(Button)
	{
		cancel();
	}
	
	void cancel()
	{
		if (done)
		{
			this.getApplication.quit();
			return;
		}
		isCancelled = true;
		
		if (aptPid)
		{
			kill(aptPid, SIGINT);
		}
	}
	
	private bool firstShown = true;
	void onShow(Widget)
	{
		if (firstShown)
		{
			isCancelled = false;
			workerThread = new Thread(&downloadAndInstall);
			workerThread.start();
			
			firstShown = false;
		}
	}
	
	pid_t aptPid;
	
	bool _isCancelled;
	bool isCancelled() => atomicLoad(_isCancelled);
	bool isCancelled(bool value)
	{
		atomicStore(_isCancelled, value);
		return value;
	}
	
	WorkerState _workerState;
	WorkerState workerState() => atomicLoad(_workerState);
	WorkerState workerState(WorkerState value)
	{
		atomicStore(_workerState, value);
		return value;
	}
	
	Thread workerThread;
	
	private void downloadAndInstall()
	{
		workerState = WorkerState.started;
		void signalFinish()
		{
			extern(C) static int lambda(AppWindow _this)
			{
				try
				{
					try
						_this.workerThread.join();
					catch (CurlException ex) { }
					
					if (_this.workerState != WorkerState.fired)
						_this.getApplication.quit();
				}
				catch (Exception ex)
				{
					_this.terminal.feed(ex.toString());
				}
				return 0;
			}
			MainContext.default_.invoke(
				cast(GSourceFunc)&lambda,
				cast(void*)this,
			);
		}
		
		scope(exit) signalFinish();
		
		void setLabel(string str)
		{
			static struct Data
			{
				Label label;
				string str;
			}
			extern(C) static int lambda(ref Data data)
			{
				data.label.setText(data.str);
				return 0;
			}
			Data* data = new Data(label, str);
			MainContext.default_.invoke(
				cast(GSourceFunc)&lambda,
				cast(void*)data,
			);
		}
		
		void setProgress(double fraction, string str)
		{
			static struct Data
			{
				ProgressBar progressBar;
				double fraction;
				string str;
			}
			extern(C) static int lambda(ref Data data)
			{
				data.progressBar.setFraction(data.fraction);
				data.progressBar.setText(data.str);
				return 0;
			}
			Data* data = new Data(progressBar, fraction, str);
			MainContext.default_.invoke(
				cast(GSourceFunc)&lambda,
				cast(void*)data,
			);
		}
		
		immutable string apiDownloadUrl = text("https://discord.com/api/download/", releaseChannel, "?platform=linux&format=deb");
		string finalDownloadUrl;
		size_t downloadSize;
		{
			HTTP http = HTTP(apiDownloadUrl);
			http.onReceiveHeader(
				(key, value)
				{
					if (icmp(key, "content-length") == 0)
						downloadSize = value.to!size_t;
					else if (icmp(key, "location") == 0)
						finalDownloadUrl = value.dup;
				}
			);
			http.method = HTTP.Method.head;
			http.perform();
		}
		string filename = baseName(finalDownloadUrl);
		string ext = extension(filename);
		string tmpPath = buildPath("/tmp", setExtension("discord", ext));
		{
			HTTP http = HTTP();
			size_t lastPercent = -1;
			http.onProgress(
				(size_t dlTotal, size_t dlNow, size_t ulTotal, size_t ulNow)
				{
					if (dlTotal > 0)
					{
						size_t percent = dlNow * 100 / dlTotal;
						if (percent != atomicLoad(lastPercent))
						{
							string progText = format("%s%% (%s / %s)", percent, formatSize(dlNow), formatSize(dlTotal));
							setProgress(percent / 100.0, progText);
							atomicStore(lastPercent, percent);
						}
					}
					return atomicLoad(isCancelled) ? 1 : 0;
				}
			);
			setLabel(finalDownloadUrl);
			download(finalDownloadUrl, tmpPath, http);
		}
		workerState = WorkerState.downloaded;
		
		void fireApt()
		{
			static struct Data
			{
				AppWindow window;
				string debFile;
			}
			extern(C) static int lambda(ref Data data)
			{
				data.window.terminal.spawnSync(
					PtyFlags.DEFAULT,
					null,
					["apt", "install", "--yes", "--allow-downgrades", data.debFile],
					null,
					SpawnFlags.SEARCH_PATH,
					&setEffectiveIds,
					null,
					data.window.aptPid,
					null,
				);
				
				return 0;
			}
			Data* data = new Data(this, tmpPath);
			MainContext.default_.invoke(
				cast(GSourceFunc)&lambda,
				cast(void*)data,
			);
		}
		fireApt();
		workerState = WorkerState.fired;
	}
	
	bool onDelete(Event e, Widget)
	{
		cancel();
		return true;
	}
}

enum WorkerState
{
	none,
	started,
	downloaded,
	fired,
}

public extern(C) void setEffectiveIds(void* userData)
{
	gid_t rgid, egid, sgid;
	errnoEnforce(getresgid(&rgid, &egid, &sgid) == 0);
	uid_t ruid, euid, suid;
	errnoEnforce(getresuid(&ruid, &euid, &suid) == 0);
	
	errnoEnforce(setresgid(egid, egid, euid) == 0);
	errnoEnforce(setresuid(euid, euid, euid) == 0);
}
