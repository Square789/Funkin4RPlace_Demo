import flixel.ui.FlxButton;
import flixel.FlxG;

/*

    FOR MOBILE

*/

class NoteButton extends FlxButton {
    public function new(x:Float = 0, y:Float = 0, noteData:Int = 0, keyAmount:Int = 4) {
        super(x, y);
        var tex = 'noteButtons';
        var image = SkinData.getNoteFile(tex, PlayState.SONG.skinModifier, ClientPrefs.noteSkin);
        frames = Paths.getSparrowAtlas(image);
        var colors = CoolUtil.coolArrayTextFile(Paths.txt('note_colors'))[keyAmount-1];
        animation.addByPrefix('idle', colors[noteData], 0, false);
        animation.play('idle');
        antialiasing = ClientPrefs.globalAntialiasing;
        setGraphicSize(Std.int(FlxG.width / keyAmount), Std.int(FlxG.height * (3/4)));
        updateHitbox();
        alpha = 0.5;
        label = null;
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);

        if (pressed) {
            alpha = 0.25;
        } else {
            alpha = 0.5;
        }
    }

    override function updateStatusAnimation() {}
}