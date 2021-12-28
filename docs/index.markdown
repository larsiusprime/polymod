---
layout: default
---

<!--
[![Build Status](https://github.com/larsiusprime/polymod/workflows/Build/badge.svg "GitHub Actions")](https://github.com/larsiusprime/haxe-concurrent/actions?query=workflow%3A%22Build%22)
-->
[![Release](https://img.shields.io/github/release/larsiusprime/polymod.svg)](http://lib.haxe.org/p/polymod)
[![License](https://img.shields.io/github/license/larsiusprime/polymod.svg?label=license)](#license)
[![Issues](https://img.shields.io/github/issues/larsiusprime/polymod.svg?label=issues)](https://github.io/larsiusprime/polymod/issues)

Polymod is an atomic modding framework for use with Haxe. It supports scripting as well as replacement of any asset.

1. [Showcase](#showcase)
2. [What is Polymod?](#what-is-polymod)
3. [Supported Platforms](#supported-platforms)
4. [Features](#features)
5. [Documentation](/docs/)

## Showcase

Here are some of the wonderful games and apps that use Polymod!

<!--
<a href="https://www.newgrounds.com/portal/view/770371" style="width: 100%; float: left;">
  <img src="assets/images/showcase/fridayNightFunkin.png" alt="Friday Night Funkin'"
      style="width: 100%; padding: 0;" />
</a>
-->

<div style="padding-bottom: 12px">
<a href="http://www.defendersquest.com/1/" style="width: 30%; float: left;">
  <img
    src="{{ 'assets/images/showcase/defendersQuest.png' | relative_url }}"
    alt="Defender's Quest꞉ Valley of the Forgotten"
    style="width: 100%; padding: 0;" />
</a>

<a href="https://store.steampowered.com/app/861540/Dicey_Dungeons/" style="width: 30%; float: left;">
  <img
    src="{{ 'assets/images/showcase/diceyDungeons.png' | relative_url }}"
    alt="Dicey Dungeons"
    style="width: 100%; padding: 0;" />
</a>

<a href="http://www.defendersquest.com/2/" style="width: 30%; float: left;">
  <img
    src="{{ 'assets/images/showcase/defendersQuest2.png' | relative_url }}"
    alt="Defender's Quest 2"
    style="width: 100%; padding: 0;" />
</a>
</div>

## What is Polymod?

If you're developing a game or app, and you're looking to allow users to manage and install mods for it, the easiest way to do this is to:

1. Make your game data-driven (expose as much of your content in the form of loose data files as possible)
2. Let players provide their own data files

Easy enough. But what if you want players to be able to use multiple mods together? How do you manage that?

Polymod solves both problems.

First, it **overrides your framework's asset system** with a custom one pointed at a mod folder (or folders) somewhere on the user's hard drive. Whenever you request an asset via `Assets.getBitmapData()` or `Res.loader.load()` call or whatever, the custom backend first checks if the mod has a modified version of this file. If it does, it returns the mod's modified version. If it doesn't, it falls through to the default asset system (the assets included with the game).

Second, it **combines mods atomically**. Instead of supplying one mod folder, you can provide several. Polymod will go through each folder in turn and apply the changes from each mod, automatically joining them into one combined mod at runtime. Note that this means that the order you load the mods in matters, in the case that they have overlapping changes.

## Supported Platforms

Polymod currently works with the following frameworks:
- [Lime](https://github.com/openfl/lime)
- [OpenFL](https://www.openfl.org)
  - [HaxeFlixel](https://haxeflixel.com)
  - [Away3D](https://github.com/openfl/away3d)
- [NME](https://github.com/haxenme/nme)
- [HEAPS](https://www.heaps.io)

Polymod also supports providing a custom backend if you need it.

Polymod currently supports the following file systems:
- Windows, Mac, and Linux (with access to the File System)
- NodeJS via Electron (with access to the File System)

Polymod also supports providing a custom file system if you need it.

## Features

Polymod supports the following kinds of operations for your players' mods:
- Replace default assets with custom ones
- Append data to the end of an existing asset
  - This is only supported for plaintext assets.
- Merge data at a specified location within an existing asset.
  - This is supported for plaintext, CSV/TSV, JSON, and XML files.

Asset replacement works with ANY asset type, including but not limited to music and graphics.

Polymod also supports scripting in Haxe, allowing modders to supply custom logic you can utilize in your application.

## Documentation

[Click here](/docs) to view the full documentation.
