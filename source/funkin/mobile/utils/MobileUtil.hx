package funkin.mobile.utils;

#if android
import extension.androidtools.os.Build.VERSION;
import extension.androidtools.os.Environment;
import extension.androidtools.Permissions;
import extension.androidtools.Settings;
#end

import lime.system.System;
import openfl.Assets;
import haxe.io.Bytes;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class MobileUtil {

    public static var currentDirectory:String = null;

    public static function getDirectory():String {
        #if android
        var preferredPath = "/storage/emulated/0/.CodenameEngine-v1.0.1/";

        try {
            if (!FileSystem.exists(preferredPath)) {
                FileSystem.createDirectory(preferredPath);
            }
        } catch (e:Dynamic) {
            trace("Failed to create external directory: " + e);
        }

        return preferredPath;
        #elseif ios
        return System.documentsDirectory;
        #else
        return "";
        #end
    }

    public static function getPermissions():Void {
        #if android
        try {
            if (VERSION.SDK_INT >= 30) {
                if (!Environment.isExternalStorageManager()) {
                    Settings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
                }
            } else {
                Permissions.requestPermissions([
                    'READ_EXTERNAL_STORAGE',
                    'WRITE_EXTERNAL_STORAGE'
                ]);
            }
        } catch (e:Dynamic) {
            trace('Permission request error: $e');
        }
        #end
    }

    public static function copyAssetsFromAPK(sourcePath:String = "assets/", targetPath:String = null):Void {
        #if mobile
        if (targetPath == null)
            targetPath = getDirectory() + "assets/";

        if (!FileSystem.exists(targetPath))
            FileSystem.createDirectory(targetPath);

        copyAssetsRecursively(sourcePath, targetPath);
        #end
    }

    public static function copyModsFromAPK(sourcePath:String = "mods/", targetPath:String = null):Void {
        #if mobile
        if (targetPath == null)
            targetPath = getDirectory() + "mods/";

        if (!FileSystem.exists(targetPath))
            FileSystem.createDirectory(targetPath);

        copyAssetsRecursively(sourcePath, targetPath);
        #end
    }

    private static function copyAssetsRecursively(sourcePath:String, targetPath:String):Void {
        #if mobile
        try {
            var cleanSourcePath = sourcePath;

            if (cleanSourcePath.endsWith("/"))
                cleanSourcePath = cleanSourcePath.substr(0, cleanSourcePath.length - 1);

            var assetList:Array<String> = Assets.list();

            for (assetPath in assetList) {

                if (assetPath.startsWith(cleanSourcePath)) {

                    var relativePath = assetPath.substr(cleanSourcePath.length);

                    if (relativePath.startsWith("/"))
                        relativePath = relativePath.substr(1);

                    if (relativePath == "")
                        continue;

                    var fullTargetPath = targetPath + relativePath;
                    var targetDir = haxe.io.Path.directory(fullTargetPath);

                    if (targetDir != "" && !FileSystem.exists(targetDir))
                        createDirectoryRecursive(targetDir);

                    try {
                        if (Assets.exists(assetPath)) {
                            var bytes:Bytes = Assets.getBytes(assetPath);
                            if (bytes != null)
                                File.saveBytes(fullTargetPath, bytes);
                        }
                    } catch (e:Dynamic) {
                        trace('Error copying $assetPath: $e');
                    }
                }
            }
        } catch (e:Dynamic) {
            trace('Recursive copy error: $e');
        }
        #end
    }

    private static function createDirectoryRecursive(path:String):Void {
        #if mobile
        if (FileSystem.exists(path))
            return;

        var parts = path.split("/");
        var current = "";

        for (part in parts) {
            if (part == "")
                continue;

            current += "/" + part;

            if (!FileSystem.exists(current)) {
                try {
                    FileSystem.createDirectory(current);
                } catch (e:Dynamic) {
                    trace('Directory creation error: $e');
                }
            }
        }
        #end
    }
}
