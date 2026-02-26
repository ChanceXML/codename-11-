package funkin.backend.system;

import flixel.FlxG;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.ui.FlxSoundTray;
import funkin.backend.assets.AssetSource;
import funkin.backend.assets.AssetsLibraryList;
import funkin.backend.assets.ModsFolder;
import funkin.backend.system.framerate.Framerate;
import funkin.backend.system.framerate.SystemInfo;
import funkin.backend.system.modules.*;
import funkin.backend.utils.ThreadUtil;
import funkin.editors.SaveWarning;
import funkin.options.PlayerSettings;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.utils.AssetLibrary;
import sys.FileSystem;
import sys.io.File;

#if android
import android.Manifest
import lime.system.System;
import funkin.mobile.utils.MobileUtil;
#end

class Main extends Sprite
{
	public static var instance:Main;
	public static var externalRoot:String;

	public static var modToLoad:String = null;
	public static var forceGPUOnlyBitmapsOff:Bool = #if desktop false #else true #end;
	public static var noTerminalColor:Bool = false;
	public static var verbose:Bool = false;

	public static var scaleMode:FunkinRatioScaleMode;

	#if desktop
	public static var framerateSprite:Framerate;
	#end

	var gameWidth:Int = 1280;
	var gameHeight:Int = 720;
	var skipSplash:Bool = true;
	var startFullscreen:Bool = false;

	public static var game:FunkinGame;

	public static var timeSinceFocus(get, never):Float;
	public static var time:Int = 0;

	public static function preInit() {
		funkin.backend.utils.NativeAPI.registerAsDPICompatible();
		funkin.backend.system.CommandLineHandler.parseCommandLine(Sys.args());
		funkin.backend.system.Main.fixWorkingDirectory();
	}

	public function new()
	{
		super();
		instance = this;
		CrashHandler.init();
		initStorage();
		addChild(game = new FunkinGame(gameWidth, gameHeight, MainState, Options.framerate, Options.framerate, skipSplash, startFullscreen));
		#if desktop
		addChild(framerateSprite = new Framerate());
		SystemInfo.init();
		#end
	}

	function initStorage()
	{
		#if android
		if (Build.VERSION.SDK_INT < 33)
		{
			System.requestPermissions([
				Manifest.permission.READ_EXTERNAL_STORAGE,
				Manifest.permission.WRITE_EXTERNAL_STORAGE
			]);
		}

		externalRoot = "/storage/emulated/0/.CodenameEngine-v1.0.1/";

		if (!FileSystem.exists(externalRoot))
			FileSystem.createDirectory(externalRoot);
		#else
		externalRoot = ".CodenameEngine-v1.0.1/";
		if (!FileSystem.exists(externalRoot))
			FileSystem.createDirectory(externalRoot);
		#end
	}

	public static var audioDisconnected:Bool = false;
	public static var changeID:Int = 0;

	public static var pathBack = #if (windows || linux)
			"../../../../"
		#elseif mac
			"../../../../../../../"
		#else
			"../../../../"
		#end;

	public static var startedFromSource:Bool = #if TEST_BUILD true #else false #end;

	@:dox(hide) public static function execAsync(func:Void->Void) ThreadUtil.execAsync(func);

	private static function getTimer():Int {
		return time = Lib.getTimer();
	}

	public static function loadGameSettings() {

		#if android
		MobileUtil.getPermissions();
		MobileUtil.copyAssetsFromAPK();
		MobileUtil.copyModsFromAPK();
		#end

		WindowUtils.init();
		SaveWarning.init();
		MemoryUtil.init();

		@:privateAccess
		FlxG.game.getTimer = getTimer;

		FunkinCache.init();
		Paths.assetsTree = new AssetsLibraryList();

		#if UPDATE_CHECKING
		funkin.backend.system.updating.UpdateUtil.init();
		#end

		ShaderResizeFix.init();
		Logs.init();
		Paths.init();

		hscript.Interp.importRedirects = funkin.backend.scripting.Script.getDefaultImportRedirects();

		#if GLOBAL_SCRIPT
		funkin.backend.scripting.GlobalScript.init();
		#end

		var lib = new AssetLibrary();
		@:privateAccess
		lib.__proxy = Paths.assetsTree;
		Assets.registerLibrary('default', lib);

		PlayerSettings.init();
		Options.load();

		FlxG.fixedTimestep = false;
		FlxG.scaleMode = scaleMode = new FunkinRatioScaleMode();

		Conductor.init();
		AudioSwitchFix.init();
		EventManager.init();

		FlxG.signals.focusGained.add(onFocus);
		FlxG.signals.preStateSwitch.add(onStateSwitch);
		FlxG.signals.postStateSwitch.add(onStateSwitchPost);
		FlxG.signals.postUpdate.add(onUpdate);

		FlxG.mouse.useSystemCursor = true;

		ModsFolder.init();

		#if MOD_SUPPORT
		if (FileSystem.exists("mods/autoload.txt"))
			modToLoad = File.getContent("mods/autoload.txt").trim();

		ModsFolder.switchMod(modToLoad.getDefault(Options.lastLoadedMod));
		#end

		initTransition();
	}

	public static function initTransition() {
		var diamond:FlxGraphic = FlxGraphic.fromClass(GraphicTransTileDiamond);
		diamond.persist = true;
		diamond.destroyOnNoUse = false;

		FlxTransitionableState.defaultTransIn = new TransitionData(FADE, 0xFF000000, 1, new FlxPoint(0, -1), {asset: diamond, width: 32, height: 32},
			new FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4));

		FlxTransitionableState.defaultTransOut = new TransitionData(FADE, 0xFF000000, 0.7, new FlxPoint(0, 1),
			{asset: diamond, width: 32, height: 32}, new FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4));
	}

	public static function onFocus() {
		_tickFocused = FlxG.game.ticks;
	}

	private static function onStateSwitch() {
		scaleMode.resetSize();
	}

	public static function onUpdate() {
		if (PlayerSettings.solo.controls.DEV_CONSOLE)
			NativeAPI.allocConsole();

		if (PlayerSettings.solo.controls.FPS_COUNTER)
			Framerate.debugMode = (Framerate.debugMode + 1) % 3;
	}

	private static function onStateSwitchPost() {
		@:privateAccess {
			for(length=>pool in openfl.display3D.utils.UInt8Buff._pools) {
				for(b in pool.clear())
					b.destroy();
			}
			openfl.display3D.utils.UInt8Buff._pools.clear();
		}
		MemoryUtil.clearMajor();
	}

	public static var noCwdFix:Bool = false;

	public static function fixWorkingDirectory() {
		#if windows
		if (!noCwdFix && !sys.FileSystem.exists('manifest/default.json')) {
			Sys.setCwd(haxe.io.Path.directory(Sys.programPath()));
		}
		#end
	}

	private static var _tickFocused:Float = 0;

	public static function get_timeSinceFocus():Float {
		return (FlxG.game.ticks - _tickFocused) / 1000;
	}
}
