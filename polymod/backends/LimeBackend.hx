package polymod.backends;

#if lime
#end

class LimeBackend implements IBackend
{
    #if lime
    function new() {}
    #else
    function new()
    {
        throw "LimeBackend: needs the lime library!";
    }
    #end
}

