# samples/openfl_hscript_class

This sample creates implements a simple Stage class, then creates a ScriptedStage scripted class type using Polymod. Polymod can then parse any scripted classes within the assets folder that extend Stage, and instantiate an instance of Stage which utilizes the behavior defined in the script.

For example, the Basic stage creates a simple scene with a background, while the Advanced stage (from `mod6`) creates a scene with a background and a moving sprite.

The Basic stage overrides the `create()` function of the stage to add additional behavior (i.e. rendering the background).

The Advanced stage overrides `create()` to initialize the background and the moving sprite, but also overrides the `onUpdate()` and `onKeyPress()` functions to add additional behavior (moving the sprite, and changing the sprite's speed, respectively).

This sample demonstrates how an application can easily instantiate and utilize classes defined in a script. This is useful for quick debugging without rebuilding an entire codebase, as well as implementation of robust modding support for your project.
