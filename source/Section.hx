package;

typedef SwagSection =
{
	var sectionNotes:Array<Array<Dynamic>>;
	var lengthInSteps:Int;
	var mustHitSection:Bool;
	var ?gfSection:Bool;
	var ?bpm:Float;
	var ?changeBPM:Bool;
	var timeSignature:Array<Int>;
	var ?changeSignature:Bool;
	var ?altAnim:Bool;
	#if MULTI_KEY_ALLOWED
	var ?changeKeys:Bool;
	var ?playerKeys:Int;
	var ?opponentKeys:Int;
	#end
}