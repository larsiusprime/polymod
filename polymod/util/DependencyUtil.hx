package polymod.util;

import haxe.Http;
import haxe.io.Bytes;
import haxe.zip.Reader;
import polymod.Polymod.ModDependency;
import polymod.Polymod.ModMetadata;
import sys.FileSystem;
import sys.io.File;
import thx.semver.VersionRule;

/**
 * Utilities for managing dependencies.
 * Provides two key functions:
 * - Ensure a mod is not loaded if a dependency is missing or has a mismatched version.
 * - Ensure mods are loaded in the correct order (dependency mods before dependent mods).
 */
class DependencyUtil
{
	/**
	 * Given an ordered list of mods, return a reordered list of mods which satisfies dependency order.
	 *
	 * @param mods The list of mods to reorder.
	 * @param ignoreErrors If true, omit mods which cannot be reordered or whose dependencies are not met.
	 *                     If false, raise an error in these cases and return `[]`.
	 * @return The reordered list of mods, or `[]` if an error occurred.
	 */
	public static function sortByDependencies(modList:Array<ModMetadata>, ?skipErrors:Bool = false):Array<ModMetadata>
	{
		if (skipErrors)
		{
			// If skipErrors is true, a mod with unmet dependencies will call Polymod.warn() and be omitted from the list.
			var filteredMods = filterDependencies(modList);

			var test = filteredMods.map(function(mod:ModMetadata)
			{
				return mod.id;
			});
			return buildTopologyForDependencies(filteredMods, true);
		}
		else
		{
			// If skipErrors is false, a mod with unmet dependencies will call Polymod.error() and return null.
			if (!validateDependencies(modList))
			{
				return [];
			}

			return buildTopologyForDependencies(modList, false);
		}
	}

	/**
	 * Given an unordered list of mods, return a list of only the mods whose dependencies are met.
	 */
	static function filterDependencies(modList:Array<ModMetadata>):Array<ModMetadata>
	{
		var result:Array<ModMetadata> = [];

		// Compile a map of mod dependencies.
		var deps:Map<String, ModDependency> = compileDependencies(modList);

		// Check that all mods are in the mod list.
		var relevantMods:Array<ModMetadata> = [];
		for (mod in modList)
		{
			if (deps.exists(mod.id))
			{
				relevantMods.push(mod);
			}
		}

		// Check that all dependencies are satisfied.
		for (dep in deps.keys())
		{
			var depRule:VersionRule = deps.get(dep).version;

			// Check that the dependency is in the mod list.
			var depMod:ModMetadata = null;
			for (mod in relevantMods)
			{
				if (mod.id == dep)
				{
					depMod = mod;
					break;
				}
			}

			// If the dependency is not found, throw a warning/error.
			if (depMod == null)
			{
				Polymod.warning(DEPENDENCY_UNMET, 'Dependency "${dep}" not found.');
				continue;
			}

			// If the dependency is found, validate the version rule.
			if (VersionUtil.match(depMod.modVersion, depRule))
			{
				// The mod is valid.

				// Dependency is met with a valid version.
				result.push(depMod);
			}
			else
			{
				Polymod.warning(DEPENDENCY_VERSION_MISMATCH, 'Dependency "${dep}" has version "${depMod.modVersion}" but requires "${depRule}".');
				continue;
			}
		}

		return result;
	}

	/**
	 * Given an unordered list of mods, return true only if all dependencies are met.
	 */
	static function validateDependencies(modList:Array<ModMetadata>):Bool
	{
		// Compile a map of mod dependencies.
		var deps:Map<String, ModDependency> = compileDependencies(modList);

		// Check that all mods are in the mod list.
		var relevantMods:Array<ModMetadata> = [];
		for (mod in modList)
		{
			if (deps.exists(mod.id))
			{
				relevantMods.push(mod);
			}
		}

		// Check that all dependencies are satisfied.
		for (dep in deps.keys())
		{
			var depRule:VersionRule = deps.get(dep).version;

			// Check that the dependency is in the mod list.
			var depMod:ModMetadata = null;
			for (mod in relevantMods)
			{
				if (mod.id == dep)
				{
					depMod = mod;
					break;
				}
			}

			// If the dependency is not found, throw a warning/error.
			if (depMod == null)
			{
				Polymod.error(DEPENDENCY_UNMET, 'Dependency "${dep}" not found.');
				return false;
			}

			// If the dependency is found, validate the version rule.
			if (VersionUtil.match(depMod.modVersion, depRule))
			{
				// The mod is valid.
				continue;
			}
			else
			{
				Polymod.error(DEPENDENCY_VERSION_MISMATCH, 'Dependency "${dep}" has version "${depMod.modVersion}" but requires "${depRule}".');
				return false;
			}
		}
		return true;
	}

	/**
	 * Based on the ordered modlist, create a reordered modlist based on each mod's dependencies.
	 * Mods will be sorted first in dependency order, then further sorted based on the order of the modlist.
	 * 
	 * @param modList The list of mods to reorder.
	 */
	static function buildTopologyForDependencies(modList:Array<ModMetadata>, ?skipErrors = false):Array<ModMetadata>
	{
		// Build a map of dependencies.
		var dependencies:Map<String, Array<String>> = [];

		// Add the mod ID as a key, then add the mod ID as a value to each dependency.
		// The result is that mods with no dependencies will have an empty array as a value,
		// and mods with dependencies will have an array of the dependency mod IDs.
		for (mod in modList)
		{
			if (!dependencies.exists(mod.id))
				dependencies.set(mod.id, []);

			var deps = mod.dependencies;
			if (deps != null)
			{
				for (depKey in deps.keys())
				{
					if (dependencies.exists(mod.id))
					{
						dependencies.get(mod.id).push(depKey);
					}
					else
					{
						dependencies.set(mod.id, [depKey]);
					}
				}
			}
		}

		// Add the optional dependencies to the dependencies map.
		for (mod in modList)
		{
			// We consider optional dependencies when building topologies,
			// but we don't consider them when validating dependencies.
			var optDeps = mod.optionalDependencies;
			if (optDeps != null)
			{
				for (depKey in optDeps.keys())
				{
					if (dependencies.exists(depKey))
					{
						dependencies.get(mod.id).push(depKey);
					}
					else
					{
						// trace('Skipping optional dependency ' + depKey + ' for mod ' + mod.id);
						// dependencies.set(mod.id, [mod.id]);
					}
				}
			}
		}

		return buildTopology_Recursive(modList, dependencies, skipErrors);
	}

	static function buildTopology_Recursive(modList:Array<ModMetadata>, dependencies:Map<String, Array<String>>, ?skipErrors:Bool = false):Array<ModMetadata>
	{
		if (modList.length == 0)
			return [];

		var result:Array<ModMetadata> = [];

		// Loop through the dependencies, finding the mod IDs with no dependencies.
		var rootLevelMods:Array<String> = [];
		for (mod in modList)
		{
			if (!dependencies.exists(mod.id) || dependencies.get(mod.id).length == 0)
			{
				rootLevelMods.push(mod.id);
			}
		}

		// If the root level mod list is empty, then there is a circular dependency.
		if (rootLevelMods.length == 0)
		{
			var modList = modList.map(function(mod)
			{
				return mod.id;
			}).join(', ');
			if (skipErrors)
			{
				Polymod.warning(DEPENDENCY_CYCLICAL, 'Circular dependency detected between mods: ${modList}');
				return [];
			}
			else
			{
				Polymod.error(DEPENDENCY_CYCLICAL, 'Circular dependency detected between mods: ${modList}');
				return null;
			}
		}

		var childLevelMods:Array<ModMetadata> = [];

		for (modData in modList)
		{
			if (rootLevelMods.indexOf(modData.id) != -1)
			{
				// Add the mod to the result list.
				result.push(modData);

				// Remove the mod from the dependency list.
				dependencies.remove(modData.id);

				// Remove the mod from each dependency list.
				for (depKey in dependencies.keys())
				{
					var depList = dependencies.get(depKey);
					var index = depList.indexOf(modData.id);
					// If the mod is in the dependency list, remove it.
					if (index != -1)
					{
						depList.splice(index, 1);
					}
				}
			}
			else
			{
				childLevelMods.push(modData);
			}
		}

		// result now contains the mods with no dependencies, in the order they appear in the mod list.
		// dependencies now contains the remaining dependencies, with the root level mods removed.
		var innerResult = buildTopology_Recursive(childLevelMods, dependencies, skipErrors);

		// Pass circular dependency issues upward.
		if (innerResult == null)
			return null;

		return result.concat(innerResult);
	}

	/**
	 * Given a list of mods, return a merged list of mod dependency versions.
	 *
	 * For example, if one mod requires `>1.2.0` of `modA` and another requires `>1.3.0` of `modA`,
	 * the merged list will be `[modA: '>1.2.0 && >1.3.0']`.
	 */
	public static function compileDependencies(modList:Array<ModMetadata>):Map<String, ModDependency>
	{
		var result:Map<String, ModDependency> = [];

		for (mod in modList)
		{
			if (result[mod.id] == null)
				result[mod.id] = {
					version: VersionUtil.DEFAULT_VERSION_RULE
				};

			if (mod.dependencies != null)
			{
				for (dependencyId in mod.dependencies.keys())
				{
					if (result[dependencyId] == null)
						result[dependencyId] = {
							version: VersionUtil.DEFAULT_VERSION_RULE
						};

					result[dependencyId].url = mod.dependencies[dependencyId].url;
					result[dependencyId].commit = mod.dependencies[dependencyId].commit;
					var dependencyRule:VersionRule = mod.dependencies[dependencyId].version;

					if (result[dependencyId].version != null)
					{
						result[dependencyId].version = VersionUtil.combineRulesAnd(result[dependencyId].version, dependencyRule);
					}
					else
					{
						result[dependencyId].version = dependencyRule;
					}
				}
			}
		}

		return result;
	}

	/**
	 * Given a github url and commit hash, download the dependency.
	 * This is done using an http request.
	 * @param outputDir the directory to download the dependency to
	 * @param url github repository url: https://github.com/OWNER/REPOSITORY
	 * @param commit commit hash 
	 */
	public static function downloadDependency(outputDir:String, url:String, commit:String):Void
	{
		var zipBytes:Null<Bytes> = getDependencyAsZip(url, commit);

		if (zipBytes == null || zipBytes.length == 0)
			return;

		var reader = new Reader(new haxe.io.BytesInput(zipBytes));
		var entries = reader.read();

		if (!FileSystem.exists(outputDir))
		{
			FileSystem.createDirectory(outputDir);
		}

		for (entry in entries)
		{
			var fileName = entry.fileName;
			if (entry.fileSize > 0)
			{
				var content = entry.data;
				var filePath = outputDir + "/" + fileName;

				var dirs = fileName.split("/");
				dirs.pop();
				var currentDir = outputDir;
				for (dir in dirs)
				{
					currentDir += "/" + dir;
					if (!FileSystem.exists(currentDir))
					{
						FileSystem.createDirectory(currentDir);
					}
				}

				File.saveBytes(filePath, content);
				trace("Extracted: " + filePath);
			}
		}

		trace("Extraction complete. Files saved in: " + outputDir);
	}

	/**
	 * Get the bytes of a dependency as a zip file.
	 * @param url github repository url: https://github.com/OWNER/REPOSITORY
	 * @param commit commit hash 
	 * @return Null<Bytes>
	 */
	public static function getDependencyAsZip(url:String, commit:String):Null<Bytes>
	{
		// url structure of the code to download
		// https://codeload.github.com/OWNER/REPOSITORY/zip/COMMIT

		var urlSplit = url.split('/');
		var repository = urlSplit[urlSplit.length - 1];
		var owner = urlSplit[urlSplit.length - 2];

		var downloadUrl = 'https://codeload.github.com/${owner}/${repository}/zip/${commit}';

		var zipBytes:Null<Bytes> = null;

		var http = new Http(downloadUrl);
		http.onBytes = function(bytes:Bytes)
		{
			zipBytes = bytes;
		}
		http.request(false);

		if (zipBytes == null || zipBytes.length == 0)
			Polymod.error(DEPENDENCY_NOT_DOWNLOADABLE, 'Failed to download dependency: ${downloadUrl}');

		return zipBytes;
	}
}
