
//               Copyright Ahmet Sait 2024.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          https://www.boost.org/LICENSE_1_0.txt)

module discord.upstart.app;

import gdk.Screen;

import gio.Application : GioApplication = Application;

import gtk.Application;
import gtk.CssProvider;
import gtk.StyleContext;

import discord.upstart.appwindow;

immutable string css = import("main.css");

class App : Application
{
	string releaseChannel;
	
	this(string applicationId, string releaseChannel)
	{
		super(applicationId, ApplicationFlags.FLAGS_NONE);
		this.releaseChannel = releaseChannel;
		initSignals();
	}
	
	private void initSignals()
	{
		addOnStartup(&onStartup);
		addOnShutdown(&onShutdown);
		addOnActivate(&onActivate);
	}
	
	void onStartup(GioApplication app)
	{
	}
	
	void onShutdown(GioApplication app)
	{
	}
	
	void onActivate(GioApplication app)
	{
		CssProvider cssProvider = new CssProvider();
		cssProvider.loadFromData(css);
		StyleContext.addProviderForScreen(Screen.getDefault, cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);
		
		AppWindow appWindow = new AppWindow(this, releaseChannel);
		this.addWindow(appWindow);
		appWindow.present();
	}
}
