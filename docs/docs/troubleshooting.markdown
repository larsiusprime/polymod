---
title: Troubleshooting
---
{% include toc.html %}

# Troubleshooting

This section is intended to provide assistance with common problems encountered when using Polymod.

## My script is failing, saying that a common/Std method is not defined. Why is this?

HScript relies heavily on Reflection to access and call functions. If Dead Code Elimination is enabled (DCE), the compiler has no way of knowing that the function will actually be needed by the user's script. As a result, the compiler will assume that the function is never called, and will remove it from the compiled code.

In order to ensure all required functions are available, you can disable DCE by setting the `--dce` flag to `no`.

You can learn more about DCE in the [Haxe documentation](https://haxe.org/manual/cr-dce.html).
