package utils;

import sys.io.File;
import sys.FileSystem;
import haxe.CallStack;
import openfl.Lib;
import openfl.events.UncaughtErrorEvent;

class DebugLogger
{
    static var basePath:String = "/storage/emulated/0/.CodenameEngine-v1.0.1/logs/";
    static var filePath:String = basePath + "log.txt";

    public static function init()
    {
        #if android
        try
        {
            if (!FileSystem.exists(basePath))
                FileSystem.createDirectory(basePath);

            File.saveContent(filePath, "=== Codename Engine Android Log ===\n");

            Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
                UncaughtErrorEvent.UNCAUGHT_ERROR,
                function(e)
                {
                    log("=== UNCAUGHT CRASH ===");
                    log(Std.string(e.error));
                    log(CallStack.toString(CallStack.exceptionStack()));
                }
            );
        }
        catch (e:Dynamic) {}
        #end
    }

    public static function log(text:String)
    {
        #if android
        try
        {
            var previous = FileSystem.exists(filePath) ? File.getContent(filePath) : "";
            File.saveContent(filePath, previous + text + "\n");
        }
        catch (e:Dynamic) {}
        #end
    }
}
