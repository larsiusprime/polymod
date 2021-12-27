---
title: Merging Files
---
{% include toc.html %}

# Merging Files

Merging files in Polymod can be complex, but it is also the most powerful method, since it allows you to interact with more complex data types such as JSON.

## Parse Rules

The `parseRules` parameter, provided to Polymod upon initialization, allows you to define which of the below methods are used for each file extension or even each specific file.

You may also define your own parsing rules by extending `polymod.format.BaseParseFormat`, adding your own implementation, then referencing it for the relevant file extensions in your parse rules.

## Merging for XML

Say you have a big complicated XML file at `data/stuff.xml` with lots of nodes:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<data>
   <!--lots of complicated stuff-->
   <mode id="difficulty" values="easy"/>
   <!--even more complicated stuff-->
</data>
```

And you want it to say this instead:

```xml
<?xml version="1.0" encoding="utf-8" ?>
<data>
   <!--lots of complicated stuff-->
   <mode id="difficulty" values="super_hard"/>
   <!--even more complicated stuff-->
</data>
```

Basically we want to change this one tag from this:

```xml
<mode id="difficulty" values="easy"/>
```

to this:
```xml
<mode id="difficulty" values="super_hard"/>
```

This is the file you would put in `<modroot>/<mergeFolder>/data/stuff.xml`:
```xml
<?xml version="1.0" encoding="utf-8" ?>
<data>
    <mode id="difficulty" values="super_hard">
        <merge key="id" value="difficulty"/>
    </mode>
</data>
```

This file contains both data and merge instructions. The `<merge>` child tag tells the mod loader what to do, and will not be included in the final data. The actual payload is just this:

```xml
<mode id="difficulty" values="super_hard">
```

The `<merge>` tag instructs the mod loader thus:

* Look for any tags with the same name as my parent (in this case, `<mode>`)
* Look within said tags for a `key` attribute (in this case, one named `"id"`)
* Check if the key's value matches what I'm looking for (in this case, `"difficulty"`)

As soon as it finds the first match, it stops and merges the payload with the specified tag. Any attributes will be added to the base tag (overwriting any existing attributes with the same name, which in this case changes values from "easy" to just "super_hard", which is what we want). Furthermore, if the payload has child nodes, all of its children will be merged with the target tag as well.

## Merging CSV and TSV

CSV and TSV files can be merged as well. In this case, the mod loader will look for any rows in the base file whose first cell matches the same value as those in the merge file, and replace them with the rows from the merge file.

Advanced merge logic for CSV/TSV (i.e. specifying a column other than the first one as the primary merge key) is not yet supported.

## Merging for JSON

JSON acts somewhat similarly to XML. Say you have a data file like this:

```json
{
    "data": {
        "difficulty": "easy",
	"nested": {
	    "enemies": [
	    	{
		    "name": "foo"
		},
	    	{
		    "name": "bar",
		    "weapon": "deagle"
		},
	    	{
		    "name": "baz"
		}
	    ]
	}
    }
}
```

And you want to change the difficulty to `super_hard`, same idea as the XML. We also want to bump up Bar's meager Desert Eagle into a fearsome Minigun. Instead of specifying the whole structure and putting a merge tag underneath it, you create a single top-level array called `merge`, specify the full path to inject into, along with the payload to inject, like so:

```json
{
    "merge": [
    	{
	    "target": "data.difficulty",
	    "payload": "super_hard"
	},
	{
	    "target": "data.nested.enemies[1].weapon",
	    "payload": "minigun"
	}
    ]
}
```

You can inject as many values as you like into as many paths as you like.

## Merging for Plaintext

Merging for plaintext is not supported. Please use _append, or adapt your file to some other structure such as JSON or XML.

## Merging for Binary Files

Merging for binary files is currently not supported. You may implement your own binary merging method by extending `BaseParseFormat` in your own application.
