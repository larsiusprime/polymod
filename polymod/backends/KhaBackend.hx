package polymod.backends;

#if kha
#end

class KhaBackend implements IBackend
{
    #if kha
    function new() {}
    #else
    function new()
    {
        throw "KhaBackend: needs the kha library!";
    }
    #end
}

