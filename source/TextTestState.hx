import flash.text.TextFormat;
import flixel.FlxG;
import flixel.text.FlxText;


// THIS SHIT DOESN'T WORK! WHY? HAS I EVER?

// @Square789: Technically unused, but i'll keep it around for future experimenting

private class BetterFlxText extends FlxText {
	private override function copyTextFormat(from:TextFormat, to:TextFormat, withAlign:Bool = true) {
		if (withAlign) {
			to.align = from.align;
		}
		to.blockIndent = from.blockIndent;
		to.bold = from.bold;
		to.bullet = from.bullet;
		to.color = from.color;
		to.font = from.font;
		to.indent = from.indent;
		to.kerning = from.kerning;
		to.leading = from.leading;
		to.leftMargin = from.leftMargin;
		to.letterSpacing = from.letterSpacing;
		to.rightMargin = from.rightMargin;
		to.size = from.size;
		to.tabStops = from.tabStops;
		to.target = from.target;
		to.underline = from.underline;
		to.url = from.url;
	}
}


class TextTestState extends MusicBeatState {
	private var text:BetterFlxText;

	public override function create() {
		super.create();
		FlxG.mouse.visible = true;

		text = new BetterFlxText(40, 40, 300);
		text.text = "balls";
		text.textField.appendText("The TextField class is used to create display objects for "
			+ "text display and input. All dynamic and input text fields in a SWF file "
			+ "are instances of the TextField class. You can use the TextField class "
			+ "to perform low-level text rendering. However, in Flex, you typically use "
			+ "the Label, Text, TextArea, and TextInput controls to process text. "
			+ "You can give a text field an instance name in the Property inspector "
			+ "and use the methods and properties of the TextField class to manipulate it with ActionScript. "
			+ "TextField instance names are displayed in the Movie Explorer and in the Insert "
			+ "Target Path dialog box in the Actions panel.\n\n"
			+ "To create a text field dynamically, use the TextField constructor.\n\n"
			+ "The methods of the TextField class let you set, select, and manipulate "
			+ "text in a dynamic or input text field that you create during authoring or at runtime.\n\n");

		// text.textField.htmlText = "<p>The TextField class is used to create display objects for "
		// 	+ "text display and input. All dynamic and input text fields in a SWF file "
		// 	+ "are instances of the TextField class. You can use the TextField class "
		// 	+ "to perform low-level text rendering. However, in Flex, you typically use "
		// 	+ "the Label, Text, TextArea, and TextInput controls to process text. "
		// 	+ "You can give a text field an instance name in the Property inspector "
		// 	+ "and use the methods and properties of the TextField class to manipulate it with ActionScript. "
		// 	+ "TextField instance names are displayed in the Movie Explorer and in the Insert "
		// 	+ "Target Path dialog box in the Actions panel.</p>"
		// 	+ "<p>To create a text field dynamically, use the TextField constructor.</p>"
		// 	+ "<p>The methods of the TextField class let you set, select, and manipulate "
		// 	+ "text in a dynamic or input text field that you create during authoring or at runtime.</p>";

		@:privateAccess text.regenGraphic();

		add(text);
	}

	public override function update(dt:Float) {
		super.update(dt);

		if (controls.BACK) {
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		if (FlxG.mouse.justPressed) {
			var mp = FlxG.mouse.getPosition();
			var cidx = text.textField.getCharIndexAtPoint(mp.x - text.x, mp.y - text.y);
			// trace('${mp.x}, ${mp.y}, $cidx');
			if (cidx != -1) {
				var pgStart = text.textField.getFirstCharInParagraph(cidx);
				var pgEnd = pgStart + text.textField.getParagraphLength(cidx) - 2;
				trace('$pgStart...$pgEnd ${text.textField.getParagraphLength(cidx)}');
				@:private
				if (text.textField.getTextFormat(pgStart).size == 8) {
					var fmt = new FlxTextFormat();
					@:privateAccess {
					fmt.format.size = 12;
					fmt.format.leftMargin = 12;
					fmt.format.indent = 24;
					}
					text.addFormat(fmt, pgStart, pgEnd);
				} else {
					var fmt = new FlxTextFormat();
					@:privateAccess {
					fmt.format.size = 8;
					fmt.format.leftMargin = 0;
					fmt.format.indent = 0;
					}
					text.addFormat(fmt, pgStart, pgEnd);
				}

				// This is certainly needed; otherwise the height won't be updated in time
				// for regenGraphic and the graphic displaying the text is missized.
				@:privateAccess text.applyFormats(text._formatAdjusted);
			}
		}
	}
}
