import test.ScriptedStage;
import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

class Stage //extends Sprite
{
  static var stageData:Array<Stage> = null;

  var test:Stage;

	public var stageId:String = "UNKNOWN";
	public var stageName:String = "UNKNOWN";

	public function new(id:String)
	{
    //super();
    trace('Initializing Stage: $id');
		// No-op constructor.
    this.stageId = id;
	}

  static final MAGENTA = 0xFFFF00FF;
  public function create() {
    var baseBg = new Bitmap(new BitmapData(480, 360, false, MAGENTA));
    //addChild(baseBg);
  }

  /**
   * Constructs all the metadata for the stage to keep in memory.
   */
  public static function initStageData() {
    stageData = [];

    /*
    // var stageList = ScriptedStage.listScriptClasses();

    for (stageClassName in stageList) {
      trace('Found stage class: $stageClassName');

      // This stage ID will be used if the class doesn't set one.
      var defaultStageId = 'STAGE_${Std.random(256)}';
      var stageInst = ScriptedStage.init(stageClassName, defaultStageId);
      if (stageInst == null) {
        trace('Failed to initialize stage class: $stageClassName');
        continue;
      }
      stageData.push(stageInst);
    }

    stageData = [];
    var stageList = PolymodScriptClass.listScriptClassesExtendingClass(Stage);
    for (stageClassName in stageList) {
      var stageInst:AbstractScriptClass = PolymodScriptClass.createScriptClassInstance(stageClassName, []);
      // This gives us an AbstractScriptClass instead of a Stage but we should be able to cast it.
      if (stageInst != null) {
        var castedStage = cast stageInst;
        stageData.push(castedStage);
      } else {
        trace('Stage.initStageData: Could not create instance of $stageClassName, got null');
      }
    }
    trace('Stage.initStageData: ${stageData.length} stages found');
    */
  }

  /**
   * Provides a list of all stage names, indexed by their ID.
   */
  public static function listStages():Map<String, String> {
    var result:Map<String, String> = new Map<String, String>();
    if (stageData == null) {
      trace('Stage.listStages: stageData is null');
      return result;
    }
    for (stage in stageData) {
      if (stage != null) {
        trace('Stage.listStages: adding stage ${stage.stageId}');
        result.set(stage.stageId, stage.stageName);
      } else {
        trace('Stage.listStages: stage is null');
      }
    }
    return result;
  }
}
