package polymod.backends;

#if nme
#end

class NMEBackend implements IBackend
{
    #if nme
    function new() {}
    #else
    function new()
    {
        throw "NMEBackend: needs the nme library!";
    }
    #end
}

