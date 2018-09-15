import openfl.utils.Assets;
import ScriptRunner.Script;

class MyScriptRunner extends ScriptRunner
{
    public var updateScore:Script;
    public var updateBee:Script;
    public var updateFlower:Script;
    public var init:Script;
    public var emptyFlower:Script;

    public function new()
    {
        super();
        
        updateScore = load("updateScore", Assets.getText("data/updateScore.txt"));
        updateBee = load("updateBee", Assets.getText("data/updateBee.txt"));
        updateFlower = load("updateFlower", Assets.getText("data/updateFlower.txt"));
        init = load("init", Assets.getText("data/init.txt"));
        emptyFlower = load("emptyFlower", Assets.getText("data/emptyFlower.txt"));
    }
}