package polymod.backends;

#if heaps
#end

class HEAPSBackend implements IBackend
{
    #if heaps
    function new() {}
    #else
    function new()
    {
        throw "HEAPSBackend: needs the heaps library!";
    }
    #end
}

