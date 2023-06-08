package;

import CoolUtil.d2r;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.tweens.misc.VarTween;
import flixel.util.FlxArrayUtil;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import haxe.ds.ArraySort;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

import CoolUtil.PointStruct;
import ChainEffects;
import TextHelper;

using StringTools;


// Hallowed be thy name.
private final STANDARD_FONT:String = "VCR OSD Mono";
private final STANDARD_FONT_SIZE:Int = 28;

// === Utilities start ===

class RevRange {
	private var cur:Int;
	private var stop:Int;

	public function new(start:Int, stop:Int) {
		this.cur = start;
		this.stop = stop;
	}

	public function hasNext():Bool {
		return cur > stop;
	}

	public function next() {
		return cur--;
	}
}

class FinishableVarTween extends VarTween {
	public function instaFinishAndCancel() {
		if (!finished) {
			// Snippets taken and mushed together from FlxTween.update and VarTween.update
			if (Math.isNaN(_propertyInfos[0].startValue)) {
				setStartValues();
			}

			if (!_running) {
				_running = true;
				if (onStart != null) {
					onStart(this);
				}
			}
			percent = 1.00;
			scale = backward ? 0 : 1;

			if (active) {
				for (info in _propertyInfos) {
					Reflect.setProperty(info.object, info.field, info.startValue + info.range * scale);
				}
			}
		}

		// Fragment from `FlxTween.finish`
		executions += 1;
		if (onComplete != null) {
			onComplete(this);
		}

		cancel();
	}

	// This couldn't possibly go wrong!
	public static function finTween(obj:Dynamic, values:Dynamic, duration:Float = 1, ?options:TweenOptions) {
		var tween = new FinishableVarTween(options, FlxTween.globalManager);
		tween.tween(obj, values, duration);
		return FlxTween.globalManager.add(tween);
	}
}


typedef SpriteDissipatorEntry = {spr:FlxSprite, remainingTime:Float}
class SpriteDissipator implements IFlxDestroyable {
	// Composition instead of inheritance solely to not have the name
	// "velocity" shadowed
	public var group:FlxSpriteGroup;
	private var _nextSpawn:Float;
	private var _initialAlpha:Float;
	private var _spawnDelay:Float;
	private var _target:FlxSprite;
	private var _activeSprites:Array<SpriteDissipatorEntry>;
	public var dissipTime:Float;
	public var direction:Float;
	public var velocity:Float;
	public var initialDisplacement:Float;
	/**
	 * Whether the dissipator should continuously spawn new sprites.
	 **/
	 public var active:Bool;

	public function new(target:FlxSprite, spawnDelay:Float, dissipTime:Float, count:Int) {
		active = true;
		group = new FlxSpriteGroup(0.0, 0.0, count);
		_spawnDelay = _nextSpawn = spawnDelay;
		_activeSprites = [];
		_target = target;
		_initialAlpha = target.alpha;
		this.dissipTime = dissipTime;

		for (_ in 0...count) {
			var sprite = new FlxSprite();
			sprite.loadGraphicFromSprite(target);
			sprite.kill();
			group.add(sprite);
		}
	}

	public function update(dt:Float) {
		group.update(dt);

		var i = 0;
		while (i < _activeSprites.length) {
			_activeSprites[i].remainingTime -= dt;
			if (_activeSprites[i].remainingTime <= 0.0) {
				_activeSprites[i].spr.kill();
				FlxArrayUtil.swapAndPop(_activeSprites, i);
				continue;
			}
			_activeSprites[i].spr.alpha = FlxMath.bound(
				_activeSprites[i].remainingTime / dissipTime, 0.0, _initialAlpha
			);
			_activeSprites[i].spr.scale.y = FlxMath.bound(
				_activeSprites[i].remainingTime / dissipTime, 0.0, 1.0
			);
			i += 1;
		}

		if (!active) {
			return;
		}

		_nextSpawn -= dt;
		while (_nextSpawn <= 0.0 && group.countDead() > 0) {
			_nextSpawn += _spawnDelay;
			var newbie = group.getFirstAvailable();
			newbie.revive();
			_activeSprites.push({spr: newbie, remainingTime: dissipTime});

			newbie.setPosition(_target.x, _target.y);
			newbie.scale.copyFrom(_target.scale);
			newbie.angle = _target.angle;
			newbie.velocity.copyFrom(new FlxPoint(0.0, -velocity).rotateByDegrees(direction));
			var tmp = new FlxPoint(0.0, -initialDisplacement).rotateByDegrees(direction);
			newbie.x += tmp.x;
			newbie.y += tmp.y;

			newbie.alpha = _initialAlpha;
			newbie.scale.y = 1.0;
		}
		_nextSpawn = Math.max(_nextSpawn, -100000.0); // who cares
	}

	public function destroy() {
		_activeSprites.resize(0);
		group.destroy();
	}
}

// === Utilities end ===

enum QuoteEffectId {CHAIN_EFFECTS; RANDOM_QUOTE_ARG_UPDATE; HEARTBEAT; TWEEN; PLAY_SOUND; FLICKER;}

abstract class QuoteEffectUpdater {
	private var objs:Array<FlxSprite>;

	public function new(objs:Array<FlxSprite>) {
		this.objs = objs;
	}

	public abstract function update(dt:Float):Void;
}

abstract class QuoteEffect {
	public abstract function getId():QuoteEffectId;

	public function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> { return []; }

	/**
	 * Alters the properties of a quote. If you change it, it should be copied beforehand.
	 * It is also a bad idea to modify the effects as they are typically being iterated over
	 * while this method is called.
	 */
	public function alterQuote(in_:Quote):Quote { return in_; }
}


class ChainEffectsUpdater extends QuoteEffectUpdater {
	private var shader:RuntimeShader;

	public function new(objs:Array<FlxSprite>, shader:RuntimeShader) {
		super(objs);
		this.shader = shader;
	}

	public function update(dt:Float) {
		shader.data.time.value[0] += dt;
	}
}
class ChainEffects extends QuoteEffect {
	var effects:Array<ChainEffect>;
	var shaderSource:Null<String>;
	private var isTimeShader:Bool;

	public function new(effects:Array<ChainEffect>) {
		this.effects = effects;
		this.shaderSource = null;
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.CHAIN_EFFECTS; }

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		// Using the same shader for multiple sprites did not work out as the TextureSize
		// uniforms were bad. This creates possibly dozens of shaders per credits screen but oh well
		if (shaderSource == null) {
			shaderSource = ChainEffectShaderGenerator.buildFragmentSource(effects, true);
		}
		var updaters:Array<QuoteEffectUpdater> = [];
		for (spr in sprites) {
			var shader = new RuntimeShader(shaderSource);
			ChainEffectShaderGenerator.setNonHardcodableUniforms(shader, effects);
			if (Reflect.hasField(shader.data, "time")) {
				shader.data.time.value = [0.0];
				updaters.push(new ChainEffectsUpdater(null, shader));
			}
			spr.shader = shader;
		}
		return updaters;
	}
}

typedef HeartbeatQuoteEffectOptions = {intensity:Float, beatTime:Float}
/**
 * Formula stolen from u/lucasvb in this thread:
 * https://www.reddit.com/r/Physics/comments/30royq/whats_the_equation_of_a_human_heart_beat/
 */
private function heartbeatEase(x:Float):Float {
	return (
		0.1*(Math.exp(-Math.pow(x+0.5, 2) / (2*0.06)) + Math.exp(-Math.pow(x-0.5, 2) / (2*0.06))) +
		(1.0 - Math.abs(x / 0.15) - x) * Math.exp(-Math.pow(7*x, 2) / 2)
	);
}
class HeartbeatQuoteEffect extends QuoteEffect {
	var options:HeartbeatQuoteEffectOptions;

	public function new(?options:Null<HeartbeatQuoteEffectOptions>) {
		this.options = options == null ? {intensity: 1.15, beatTime: 0.4} : options;
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.HEARTBEAT; }

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		for (spr in sprites) {
			FlxTween.tween(
				spr,
				{"scale.x": options.intensity, "scale.y": options.intensity},
				options.beatTime,
				{ease: heartbeatEase, type: LOOPING}
			);
		}
		return [];
	}
}

class RandomeQuoteArgUpdateQuoteEffect extends QuoteEffect {
	var choices:Array<_QuoteArgs>;

	public function new(?choices:Null<Array<_QuoteArgs>>) {
		this.choices = choices ?? [{}];
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.RANDOM_QUOTE_ARG_UPDATE; }
	public override function alterQuote(in_:Quote):Quote {
		var args = in_.getQuoteArgs();
		var choice = CoolUtil.randomChoice(choices);
		for (f in Reflect.fields(choice)) {
			Reflect.setField(args, f, Reflect.field(choice, f));
		}
		return new Quote(args);
	}
}

typedef TweenQuoteEffectOptions = {values:Dynamic, ?duration:Float, ?ease:EaseFunction, ?type:FlxTweenType}
class TweenQuoteEffect extends QuoteEffect {
	var values:Dynamic;
	var duration:Float;
	var ease:EaseFunction;
	var type:FlxTweenType;

	public function new(options:TweenQuoteEffectOptions) {
		this.values = options.values;
		this.duration = options.duration == null ? 1.0 : options.duration;
		this.ease = options.ease == null ? FlxEase.linear : options.ease;
		this.type = options.type == null ? FlxTweenType.ONESHOT : options.type;
	}

	final public function getId():QuoteEffectId { return QuoteEffectId.TWEEN; }

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		for (spr in sprites) {
			FlxTween.tween(spr, values, duration, {ease: ease, type: type});
		}
		return [];
	}
}

enum FlickerQuoteEffectUpdaterState {HIDDEN; FLICKER_IN; SHOWN; FLICKER_OUT;}
typedef RandomizableTime = {?standard:Float, ?randomOffset:{a:Float, b:Float}}
typedef FlickerQuoteEffectOptions = {
	var ?initialStates:Null<{c:Array<FlickerQuoteEffectUpdaterState>, ?w:Array<Float>}>;
	var ?initialTime:Null<RandomizableTime>;
	var ?hideTime:Null<RandomizableTime>;
	var ?showTime:Null<RandomizableTime>;
	var ?transitionTime:Null<RandomizableTime>;
}
class FlickerQuoteEffectUpdater extends QuoteEffectUpdater {
	private var state:FlickerQuoteEffectUpdaterState;
	private var currentStateTime:Float;
	private var currentStatePassedTime:Float;
	private var hideTime:RandomizableTime;
	private var showTime:RandomizableTime;
	private var transitionTime:RandomizableTime;

	public function new(objs:Array<FlxSprite>, options:FlickerQuoteEffectOptions) {
		super(objs);

		this.hideTime = options.hideTime;
		this.showTime = options.showTime;
		this.transitionTime = options.transitionTime;

		state = FlxG.random.getObject(options.initialStates.c, options.initialStates.w);
		var starterStateTime = options.initialTime.standard != null ?
			options.initialTime.standard :
			getStateTime(state);
		var starterOffset = options.initialTime.randomOffset != null ?
			FlxG.random.float(options.initialTime.randomOffset.a, options.initialTime.randomOffset.b) :
			0.0;
		currentStateTime = starterStateTime + starterOffset;
		currentStatePassedTime = 0.0;

		update(0.0);
	}

	private inline function getNextState(s:FlickerQuoteEffectUpdaterState):FlickerQuoteEffectUpdaterState {
		return switch (state) {
			case HIDDEN: FLICKER_IN; case FLICKER_IN: SHOWN; case SHOWN: FLICKER_OUT; case FLICKER_OUT: HIDDEN;
		}
	}

	private inline function getStateTime(s:FlickerQuoteEffectUpdaterState):Float {
		var struct = switch (state) { case HIDDEN: hideTime; case SHOWN: showTime; case _: transitionTime; }
		return struct.standard + (
			struct.randomOffset != null ? FlxG.random.float(struct.randomOffset.a, struct.randomOffset.b) : 0.0
		);
	}

	public function update(dt:Float) {
		currentStatePassedTime += dt;
		while (currentStatePassedTime > currentStateTime) {
			currentStatePassedTime -= currentStateTime;
			state = getNextState(state);
			currentStateTime = Math.max(0.01, getStateTime(state));
		}
		var x:Float = currentStatePassedTime / currentStateTime;
		var visible = switch (state) {
			case HIDDEN: false;
			case SHOWN: true;
			case FLICKER_IN:  (Math.sin(x * 20) + 4*Math.pow(x, 3) + Math.sin(x * 120)) > 1.0;
			case FLICKER_OUT: (Math.sin(x * 20) + 4*Math.pow(x, 3) + Math.sin(x * 120)) <= 1.0;
		}
		for (text in objs) {
			text.visible = visible;
		}
	}
}
class FlickerQuoteEffect extends QuoteEffect {
	private var options:FlickerQuoteEffectOptions;

	final public function getId():QuoteEffectId { return QuoteEffectId.FLICKER; }

	public function new(?options:Null<FlickerQuoteEffectOptions>) {
		if (options == null)                          options = {};
		if (options.initialStates == null)            options.initialStates = {c: [HIDDEN]};
		if (options.initialTime == null)              options.initialTime = {};
		if (options.hideTime == null)                 options.hideTime = {};
		if (options.hideTime.standard == null)        options.hideTime.standard = 2.0;
		if (options.showTime == null)                 options.showTime = {};
		if (options.showTime.standard == null)        options.showTime.standard = 2.0;
		if (options.transitionTime == null)           options.transitionTime = {};
		if (options.transitionTime.standard == null)  options.transitionTime.standard = 0.5;
		this.options = options;
	}

	public override function apply(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		return [new FlickerQuoteEffectUpdater(sprites, options)];
	}
}


enum abstract QuoteLocation(Int) to Int {
	var QUOTE_FIELD;
	var BEHIND_NAME;
}

private class QuoteFieldSlot {
	private var initialPosition:PointStruct;
	public var currentPosition:PointStruct;
	private var owner:CreditsState;

	public function new(owner:CreditsState) {
		initialPosition = {x: 0.0, y: 0.0};
		currentPosition = {x: 0.0, y: 0.0};
		this.owner = owner;
	}

	public function setInitial(x:Float, y:Float) {
		initialPosition.x = currentPosition.x = x;
		initialPosition.y = currentPosition.y = y;
	}

	public function advance(by:Float):Bool {
		currentPosition.y += by;
		currentPosition.x = initialPosition.x - owner.getXDifferenceOnSlope(currentPosition.y - initialPosition.y);
		return shouldContinue();
	}

	public function adjustAndAdvance(sprite:FlxSprite):Bool {
		return advance(sprite.height);
	}

	public function shouldContinue():Bool {
		return currentPosition.y < FlxG.height;
	}
}

// This slot grows to the right instead and lays stuff out behind the name, treating its
// position as the lower left instead of the upper left, which is why adjusting only
// has an effect on it.
private class BehindNameSlot extends QuoteFieldSlot {
	public override function advance(by:Float):Bool {
		return shouldContinue();
	}

	public override function adjustAndAdvance(sprite:FlxSprite):Bool {
		sprite.y -= sprite.height;
		currentPosition.x += sprite.width;
		return shouldContinue();
	}

	public override function shouldContinue() {
		return currentPosition.x < FlxG.width;
	}
}

typedef QuoteImageInfo = {
	var name:String;
	var ?animated:Null<Bool>;
	var ?frameW:Null<Int>;
	var ?frameH:Null<Int>;
	var ?fps:Null<Float>;
	var ?scale:Null<Float>;
}
typedef CompleteImageInfo = {name:String, animated:Bool, frameW:Int, frameH:Int, fps:Float, scale:Float}

typedef _QuoteArgs = {
	var ?text:Null<String>;
	var ?image:Null<QuoteImageInfo>;
	var ?textSize:Null<Int>;
	var ?bold:Null<Bool>;
	var ?font:Null<String>;
	var ?color:Null<FlxColor>;
	var ?effects:Null<Array<QuoteEffect>>;
	var ?linebreak:Null<Bool>;
	var ?postPadding:Null<Int>;
	var ?location:Null<QuoteLocation>;
}
class Quote {
	public var text(default, null):String;
	public var image(default, null):Null<CompleteImageInfo>;
	public var textSize(default, null):Int;
	public var bold(default, null):Bool;
	public var font(default, null):String;
	public var color(default, null):FlxColor;
	public var effects(default, null):Array<QuoteEffect>;
	public var linebreak(default, null):Bool;
	public var postPadding(default, null):Int;
	public var location(default, null):QuoteLocation;

	public function new(args:_QuoteArgs) {
		this.text =        args.text ?? "null";
		this.image =       args.image == null ? null : {
			name:     args.image.name,
			animated: args.image.animated ?? false,
			frameW:   args.image.frameW ?? 0,
			frameH:   args.image.frameH ?? 0,
			scale:    args.image.scale ?? 1.0,
			fps:      args.image.fps ?? 24.0,
		}

		this.textSize =    args.textSize ?? STANDARD_FONT_SIZE;
		this.bold =        args.bold ?? false;
		this.font =        args.font ?? STANDARD_FONT;
		this.color =       args.color ?? FlxColor.WHITE;
		this.effects = [];
		if (args.effects != null) {
			var seen:Map<QuoteEffectId, Bool> = [for (x in QuoteEffectId.createAll()) x => false];
			for (e in args.effects) {
				if (!seen[e.getId()]) {
					seen[e.getId()] = true;
					this.effects.push(e);
				}
			}
		}

		this.linebreak =   args.linebreak ?? true;
		this.postPadding = args.postPadding ?? 16;
		this.location =    args.location ?? QuoteLocation.QUOTE_FIELD;
	}

	public function getQuoteArgs():_QuoteArgs {
		return {
			text: text, image: image, textSize: textSize, bold: bold,
			font: font, color: color, linebreak: linebreak, postPadding: postPadding, effects: effects,
		};
	}

	public function applyEffectsTo(sprites:Array<FlxSprite>):Array<QuoteEffectUpdater> {
		return [for (effect in effects) for (u in effect.apply(sprites)) u];
	}

	/**
	 * Returns a possibly altered quote, since there's effects that may just do it randomly.
	 */
	public function alterQuote() {
		var x = this;
		for (e in effects) {
			x = e.alterQuote(x);
		}
		return x;
	}
}

private class NameSpriteProducer {
	public function new() {}
	public function makeName(x:Float, y:Float, name:String):FlxSprite {
		var alphabet = new TitleCardFont(0, 0, name, false, false, 0, 1.5);
		// NOTE: The alphabet (TitleCardFont) will be raised by its height, however i want its
		// text's baseline to stay in the same place. At 0.5 it's 8px too much, at 1.5 it's 24px, at 2.5 40px
		// so, place the alphabet 24px lower to counteract that.
		alphabet.setPosition(x, y + (1.5 * 16));
		return alphabet;
	}
}

private class MauriiNameSpriteProducer extends NameSpriteProducer {
	override function makeName(x:Float, y:Float, name:String) {
		var name = new FlxText(x, y, 0, name);
		name.bold = true;
		name.setFormat("Inter", 60, FlxColor.RED, RIGHT, OUTLINE, FlxColor.BLACK);
		// As before, screw with the height a bit in order to make it look accurate.
		// The fontsize is 60, but the text's reported height is 77. Who knows what's going on.
		name.y += (name.height - 60);
		return name;
	}
}


private class Role {
	public static final ARTIST:Role =         new Role("artist");
	public static final CONCEPT_ARTIST:Role = new Role("concept_artist");
	public static final ANIMATOR:Role =       new Role("animator");
	public static final COMPOSER:Role =       new Role("composer");
	public static final PROGRAMMER:Role =     new Role("programmer");
	public static final CHARTER:Role =        new Role("charter");
	public static final DIRECTOR:Role =       new Role("director");
	public static final VOICE_ACTOR:Role =    new Role("voice_actor");
	public static final MISCELLANEOUS:Role =  new Role("miscellaneous");

	public var animationName(default, null):String;
	public var displayString(default, null):String;

	private function new(animationName:String, ?displayString:Null<String>) {
		this.animationName = animationName;
		this.displayString = displayString == null ?
			~/(^| |_|-)([a-z])/g.map(
				animationName,
				(r) -> {
					var wasProbablyStart = r.matched(1) == null || r.matched(1).length == 0;
					return (wasProbablyStart ? "" : " ") + r.matched(2).toUpperCase();
				}
			) :
			displayString;
	}
}
private final ROLES = [
	Role.ARTIST, Role.CONCEPT_ARTIST, Role.ANIMATOR, Role.COMPOSER, Role.PROGRAMMER, Role.CHARTER,
	Role.DIRECTOR, Role.VOICE_ACTOR, Role.MISCELLANEOUS
];


private class Representation {
	public static final PORTRAIT = new Representation(16, "credits/portraits/", 1, PortraitRepresentationSpriteGroup, 0);
	public static final ICON     = new Representation(2,  "credits/icons/",     3, IconRepresentationSpriteGroup,     1);

	public var quoteLimit(default, null):Int;
	public var imagePath(default, null):String;
	public var memberDisplayCount(default, null):Int;
	public var representationGroupClass(default, null):Class<RepresentationSpriteGroup>;
	public var priority(default, null):Int;

	private function new(
		quoteLimit:Int,
		imagePath:String,
		memberDisplayCount:Int,
		representationGroupClass:Class<RepresentationSpriteGroup>,
		priority:Int
	) {
		this.quoteLimit = quoteLimit;
		this.imagePath = imagePath;
		this.memberDisplayCount = memberDisplayCount;
		this.representationGroupClass = representationGroupClass;
		this.priority = priority;
	}
}


private class CreditBlob {
	public var name:String;
	public var roles:Array<Role>;
	public var representation:Representation;
	public var representationImageName:Null<String>;
	public var quotes:Array<Quote>;
	public var color:FlxColor;
	public var links:Array<{link:String, iconName:String}>;
	public var offset:PointStruct;
	public var image:Null<FlxGraphic>;
	public var nameSpriteProducer:NameSpriteProducer;

	public function new(
		name:String,
		roles:Array<Role>,
		representation:Representation,
		representationImageName:Null<String>,
		quotes:Array<_QuoteArgs>,
		color:FlxColor,
		?links:Null<Array<String>>,
		?offset:Null<PointStruct>,
		?nameSpriteProducer:Null<NameSpriteProducer>
	) {
		this.name = name;
		this.roles = roles;
		this.representation = representation;
		this.representationImageName = representationImageName;

		var ultimateArgs:Array<_QuoteArgs> = [];
		if (quotes.length < 1) {
			ultimateArgs = [{text: "null"}];
		} else if (quotes.length > representation.quoteLimit) {
			ultimateArgs = quotes.slice(0, representation.quoteLimit + 1);
		} else {
			ultimateArgs = quotes;
		}
		this.quotes = [for (a in ultimateArgs) new Quote(a)];

		this.color = color;
		if (links == null) {
			this.links = [];
		} else {
			this.links = [for (link in links) {link: link, iconName: extractIconNameFromLink(link)}];
		}
		this.offset = offset == null ? {x: 0, y: 0} : offset;

		if (representationImageName != null) {
			this.image = Paths.image(representation.imagePath + representationImageName);
		} else {
			this.image = null;
		}

		this.nameSpriteProducer = nameSpriteProducer == null ? new NameSpriteProducer(): nameSpriteProducer;
	}

	private static function extractIconNameFromLink(link:String):String {
		var urlRe = ~/(?:[a-z0-9-]+?\.)*([a-z0-9-]+?\.[a-z0-9]{1,24})/; // literally who cares, good enough
		if (!urlRe.match(link)) {
			return "generic";
		}
		return switch (urlRe.matched(1)) {
			case "twitter.com":
				"twitter";
			case "youtube.com" | "youtu.be":
				"youtube";
			case "github.com":
				"github";
			case "reddit.com" | "redd.it":
				"reddit";
			case "steamcommunity.com" | "steampowered.com" | "s.team":
				"steam";
			case "spriters-resource.com":
				"spriters-resource";
			case "linktr.ee":
				"linktree";
			case "newgrounds.com":
				"newgrounds";
			case _:
				"generic";
		}
	}
}

/**
 * Full house and full backyard shed. Delegated to function as `CreditBlob`s load images.
 * Should really be turned into a bunch of .jsons
 */
private function makeCredits():Array<{name:String, members:Array<CreditBlob>}> { return [
	{
		name: "Funkin' 4 r/place Team",
		members: [
			new CreditBlob(
				"Sir Sins",
				[Role.DIRECTOR, Role.CHARTER, Role.CONCEPT_ARTIST],
				Representation.PORTRAIT,
				"sir_sins",
				[
					{
						text: (
							"If you're reading this, then you must be interested in the people behind the mod, hm? " +
							"Well, let's have a chat.\n\n" +
							"I'm Sir Sins, the person who made the original post on Reddit back when r/place " +
							"happened. Never would've thought it'd come this far, and that the dev team would turn " +
							"into a massive friend group, but hey, you think I'm complaining?\n\n" +
							"Mod's nice and all, but I have a far greater appreciation for the people I met on the " +
							"way, AKA, the rest of the dev team. Go check their quotes, see what they have to say " +
							"and enjoy the mod, if you will...\n\n" +
							"Once the keeper of chaos, always the keeper of chaos. Thanks for playing!"
						),
						//// color: FlxColor.PURPLE, // For the hue shifting to work //// nvm looks terrible
						effects: [
							new ChainEffects([
								new AberrationGlitchEffect({baseIntensity: 2.0, intensityVariance: 3.0, goNegative: false}),
								new HueShiftEffect({cycleSpeed: 0.5}), //// shifting the aberration however actually looks nice
							]),
						],
					},
				],
				0x9203EE,
				{x: 59, y: 55}
			),
			new CreditBlob(
				"DangDoodle",
				[Role.COMPOSER, Role.ANIMATOR, Role.VOICE_ACTOR],
				Representation.PORTRAIT,
				"doodle",
				[
					{text: "Just straight up chilling, go with the flow."},
					{image: {name: "doodle", animated: true, frameW: 96, frameH: 96, fps: 10}},
				],
				0x17B9F9,
				["youtube.com/c/DangDoodle", "twitter.com/DangDoodleMusic"],
				{x: 139, y: 122}
			),
			new CreditBlob(
				"Captain",
				[Role.DIRECTOR, Role.ARTIST, Role.CHARTER],
				Representation.PORTRAIT,
				"captain",
				[
					{text: (
						"yknow i dont typically write like this, but since its a special occasion, i suppose " +
						"i shall. i am very thankful to have gotten the opportunity to meet all these " +
						"talented people in such a short amount of time. f4rp has taught me many lessons " +
						"throughout its development and i hope each and every one of my new friends have a " +
						"successful life in whatever they choose to do. thank you f4rp for all of the " +
						"opportunities, and friends, you have given me"
					)},
					{image: {name: "captain_signature"}},
					{text: "[NON-DEMO CONTENT REDACTED] sweeeeps!"},
				],
				0x5C92FF,
				[
					"https://steamcommunity.com/id/Funny_Captain/",
					"https://www.spriters-resource.com/submitter/CaptainGame17/",
				],
				{x: 123, y: 140}
			),
			new CreditBlob(
				"CoolingTool",
				[Role.PROGRAMMER],
				Representation.PORTRAIT,
				"coolingtool",
				[
					{
						text: "lalalllalalalalalalalalalalalallalalalaallalalalalalaallalalalalalalalalalalalalalala",
						effects: [new ChainEffects([new ScrollEffect({speed: [256.0, 0.0]})])],
						linebreak: false,
					},
					{text: "https://youtu.be/GYqkKnM2nrA"},
					{text: "LEGO set 31031 only for $11.99, buy now! (Ages 6-12)"},
					{text: "duke the java mascot my beloved"},
					{text: "shoutout to my homeboy ntsc270"},
					{
						text: "unpleasant gradient",
						effects: [new ChainEffects([
							new HGradientEffect({colors: [0x1FCC2A, 0xFD30F9, 0x99520F]}),
						])],
					}
				],
				0x9BCA3C,
				["https://twitter.com/CoolingTool", "https://youtu.be/GYqkKnM2nrA"],
				{x: 170, y: 415}
			),
			new CreditBlob(
				"Edds",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"edds",
				[
					{text: "I took a while making portraits, my bad... lol"},
					{image: {name: "ben_n_plush_pep"}},
				],
				0x9F6498,
				["https://twitter.com/TiredEdd"],
				{x: 132, y: 198}
			),
			new CreditBlob(
				"Micah",
				[Role.COMPOSER],
				Representation.PORTRAIT,
				"micah",
				[{text: "I make certified hood classics"}],
				0x2468EF,
				["https://www.youtube.com/@msvi09official"],
				{x: 140, y: 90}
			),
			new CreditBlob(
				"Pale Artist",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"pale_artist",
				[
					{
						text: (
							"Your name is NEPETA LEIJON.\n\n" +
							"You live in a CAVE that is also a HIVE, but still mostly just a CAVE. You like to engage " +
							"in FRIENDLY ROLE PLAYING, but not the DANGEROUS KIND. Never the DANGEROUS KIND. It's TOO " +
							"DANGEROUS! Too many of your good friends have gotten hurt that way.\n\n" +
							"Your daily routine is dangerous enough as it is. You prowl the wilderness for GREAT " +
							"BEASTS, and stalk them and take them down with nothing but your SHARP CLAWS AND TEETH! " +
							"You take them back to your cave and EAT THEM, and from time to time, WEAR THEIR PELTS FOR " +
							"FUN. You like to paint WALL COMICS using blood and soot and ash, depicting EXCITING TALES " +
							"FROM THE HUNT! And other goofy stories about you and your numerous pals. Your best pal of " +
							"all is A LITTLE BOSSY, and people wonder why you even bother with him. But someone has to " +
							"keep him pacified. If not you, then who? Everyone has an important job to do.\n\n" +
							"Your trolltag is arsenicCatnip and :33 < *your sp33ch precedes itself with the face of " +
							"your lusus who is pawssibly the cutast and purrhaps the bestest kitty you have ever " +
							"s33n!*\n\n" +
							"What will you do?"
						),
						textSize: 16,
						font: "Courier New",
						bold: true,
					},
					{text: "Follow me on TWITTER @Pale_Artist_"},
				],
				0xFFFFFF,
				["https://twitter.com/Pale_Artist_"],
				{x: 134, y: 123}
			),
			new CreditBlob(
				"Scyrulean",
				[Role.ARTIST, Role.ANIMATOR],
				Representation.PORTRAIT,
				"scyrulean",
				[
					{
						text: "A Mischief-Mischief, a Chaos-Chaos...!",
						effects: [new ChainEffects([new HGradientEffect({colors: [0x009BFF, 0xFFFFFF]})])],
					},
				],
				0x009BFF,
				null,
				{x: 54, y: 161}
			),
			new CreditBlob(
				"JBMagination",
				[Role.COMPOSER, Role.PROGRAMMER],
				Representation.PORTRAIT,
				"jbm",
				[{text: "<3", effects: [new HeartbeatQuoteEffect({intensity: 1.35, beatTime: 0.72})]}],
				0x42E36B,
				["https://jbmagination.com/"],
				{x: 119, y: 146}
			),
			new CreditBlob(
				"daftbrained",
				[Role.ARTIST, Role.ANIMATOR],
				Representation.PORTRAIT,
				"daftbrained",
				[
					{
						text: (
							"I should put an unreasonable amount of text in this because" +
							[for (_ in 0...85) ""].join(" its funny")
						),
					},
				],
				0x504027,
				null,
				{x: 120, y: 202}
			),
			new CreditBlob(
				"Parasy",
				[Role.CHARTER],
				Representation.PORTRAIT,
				"parasy",
				[
					{
						text: (
							"Hiya! I'm the Mania charter for this mod, alongside the charter for some of the " +
							"Normal difficulties."
						)
					},
					{
						text: (
							"I'd like to say first of all, make sure to check out the other difficulties, as we " +
							"all put a lot of love into these charts regardless of their difficulty. Regardless, " +
							"I hope you enjoyed the charts that you played! Thanks a lot for playing!"
						)
					},
				],
				0xFFA7F0,
				["https://www.youtube.com/@314Pirasy"],
				{x: 120, y: 374}
			),
			new CreditBlob(
				"Johntak",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"johntak",
				[{text: "what if i killed you"}],
				0xFFAE36,
				["https://www.youtube.com/watch?v=Wb3UrJjAac4"],
				{x: 141, y: 277}
			),
			new CreditBlob(
				"Syembol",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"syembol",
				[
					{text: "its pronounced symbol not see-yembol or whatever damned pronounciation you guys have"},
					{text: "Kenny from South Park working on an FNF mod. No questions asked."},
				],
				0xFF8920,
				["https://twitter.com/BolSyem"],
				{x: 149, y: 259}
			),
			new CreditBlob(
				"Square789",
				[Role.PROGRAMMER],
				Representation.PORTRAIT,
				"square",
				[
					{text: "wololo"},
					{
						text: (
							"Thanks to EpicGamer from the Haxe Discord for crushing an annoying " +
							"shader issue within 5 minutes of looking at it!"
						),
					},
					{text: "And thank you for playing :D", postPadding: 32},
					{
						text: "[SHAMELESS PLU- I MEAN SPONSORED MESSAGE]",
						effects: [new ChainEffects([new AberrationGlitchEffect(
							{baseIntensity: 2.0, intensityVariance: 1.0, goNegative: false}
						)])],
						textSize: 20,
						postPadding: 0,
					},
					{
						text: "I'm rewriting FNF in Python, coming out Q3 2024 at this rate (Check my Github!)",
						postPadding: 42,
					},
					{
						text: "",
						color: 0xFFB2A8A8,
						effects: [new RandomeQuoteArgUpdateQuoteEffect([
							{text: "Fun fact: This quote is randomly chosen!"},
							{text: "Fun fact: OpenFL is somewhat stuck on a GLSL version from 2004!"},
							{text: "Fun fact: Your front door's lock quality is rather substandard!"},
							{text: "Fun fact: Bielefeld does not exist!"},
							{text: "Fun fact: I am bad at my job!"},
							{text: "Fun fact: I wrote the menu you are enjoying right now!"},
							{text: "Fun fact: All tech infrastructure is held together by duct tape!"},
							{text: "Fun fact: It's strings all the way down!"},
							{text: "Fun fact: There is nothing you can do about it!"},
							{text: "Fun fact: FNF code is the best spaghetti i've ever had!"},
							{
								text: (
									"Fun fact: Wer sagt denn, dass ich, wenn ich das hier trink', morgens 'nen " +
									"Schädel hab'?"
								),
							},
							{text: "Fun fact: Null Object Reference!"},
							{text: "Fun fact: Segmentation fault!"},
							{text: "Fun fact: Object reference not set to an instance of an object!"},
							{text: "Fun fact: Up, up, down, down, left, right, left, right, B, A!"},
							{text: "Fun fact: You are not immune to propaganda!"},
							// This is a funny reference, but for people who don't get the funny reference it may
							// be juuuuust a bit weird so commenting out of doom of death
							// {text: "Fun fact: When the beat drops, I'm going to fucking kill myself."},
							{text: "Fun fact: Your casual match is ready!"},
							{text: "Fun fact: A monad is a monoid in the category of endofunctors!"},
							{text: "Fun fact: FICSIT does not waste!"},
							{text: "Fun fact: Objects in mirror are closer than they appear!"},
							{text: "Fun fact: It's a chronic buildup of my favorite bio-dust!"},
							{text: "Fun fact: surveillance nanobots in your floorboards pry them out"},
							{text: "Fun fact: Four plus four plus four is twelve."},
							{text: "Fun fact: Epstein did not kill himself!"},
							{text: "Fun fact: thog dont caare"},
							{text: "Fun fact: You missed your Spanish lesson today.\n\nYou know what happens now."},
							{text: "Fun fact: I found the source of the ticking! It's a pipe bomb!"},
							{text: "Fun fact: I'm pretty much out of fun facts."},
							{text: "Fun fact: The more references i cram in here, the less funny it gets!"},
							{text: "Fun fact: The Area 51 Snack Bar Sucks"},
							{
								text: (
									"Fun fact: Only after shoehorning achievement popups into MusicBeatState and " +
									"painfully sprinkling extra camera code around just for them, i noticed it " +
									"would've been possible to use `addChild` to add these above the actual game."
								),
							},
							{
								text: (
									"Fun fact: I think this menu is a performance nightmare.\n" +
									"But hey, that slanted text sure makes up for it!"
								),
							},
							{text: "Fun fact: This took a long time."},
							{text: "Fun fact: The most mundane stuff veils the most time-consuming workload."},
							{
								text: (
									"Fun fact: I wrote a hideously overengineered per-achievement data " +
									"storage, loading and defaulting mechanism with adventurous type validation " +
									"and access notation and that ended up unused." +
									"Most definitely for the best."
								),
							},
							{text: "Fun fact: This quote has been added only so i had a commit for testing!"},
							{text: "Fact: The Fact Sphere is always right!"},
							{text: "You are worth it."},
							{text: "You have angered the gods!"},
							{text: "This is our fault!"},
							{text: "You're cute!"},
							{
								text: (
									"I was thinking about why so many in the radical left participate " +
									"in \"speedrunning\"."
								),
							},
							{text: "Arstotzka so great, passport not required!"},
							{text: "Real Yakuza use a gamepad."},
							{text: "YOU'RE WINNER!"},
							{text: "I may be stupid,"},
							{text: "I don't much like the tone of your voice!"},
							{text: "I don't get it."},
							{text: "THERE'S NO FENCE ON THIS FENCE!"},
							{
								text: (
									"The end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never " +
									"the end is never the end is never the end is never the end is never "
								),
							},
							{text: "You make even the devil cry!"},
							{text: "At least there is Ceda Cedovic!"},
							{text: "snake_case forever!"},
							{text: "I like elephants and God likes elephants. Here's a, uh... a realistic elephant."},
							{text: "410,757,864,530 LINTER WARNINGS!"},
							{text: "Overengineering extravaganza!"},
							{
								text: (
									"SUPER.\n HOT.\nSUPER.\n HOT.\nSUPER.\n HOT.\nSUPER.\n HOT.\nSUPER.\n HOT.\n" +
									"SUPER.\n HOT."
								),
							},
							{text: "Hello World!"},
							{text: "#C$L&S@\n02402488"},
							{text: "for (u in effectUpdaters) {\n    u.update(dt);\n}"},
							{text: "I can't feel my beard! HEEELP!"},
							{text: "AAAHHHH! I NEEEEED A MEDIC BAG!"},
							{text: "Seymour! The house is on fire!"},
							{text: "Blessed be the regulations."},
							{text: "| || || |_"},
							{text: "This was a triumph."},
							{text: "He was my best friend, but he owed me seven dollars!"},
							{
								text: (
									"In this moment, I am euphoric. Not because of any phony god's blessing.\n" +
									"But because I am enlightened by my own intelligence"
								),
							},
							{text: "Thanks, and have fun!"},
							{text: "Have i truly become quadliteral?"},
							{text: "RIP r/gayspiderbrothel!"},
							{text: "Oh, SHUT UP about the bloody mushrooms already! Move it, team!"},
							{text: "God, these pretzels suck! How's your day been, buddy?"},
							{text: "Guys, the thermal drill. Go get it!"},
							{
								text: (
									"I'd just like to interject for a moment. What you're referring to as Linux, " +
									"is in fact, GNU/Linux, or as I've recently taken to calling it, GNU plus " +
									"Linux. Linux is not an operating system unto itself, but rather another free" +
									"component of a fully functioning GNU system made useful by the GNU corelibs, " +
									"shell utilities and vital system components comprising a full OS as defined by " +
									"POSIX.\n" +
									"Many computer users run a modified version of the GNU system every day, " +
									"without realizing it."
								),
							},
							{
								text: (
									"I feel ashamed. Again and again. Nothing to give. And no one to blame.\n" +
									"During the daaaaay, I guess I'm okay."
								),
							},
							{text: "Löckelle postera, lorsca undula kalit.\nLöckelle karakto, baldeni."},
							{text: "Enjoying the ride?"},
							{text: "Reticulating splines..."},
							{text: "\"git commit --amend\" my beloved"},
							{text: "THANK YOU FOR PARTICIPATING\nIN THIS\nENRICHMENT CENTER ACTIVITY!!"},
							{text: "Program received signal SIGSEGV 0x4007fc13 in _IO_FRESH_MOVES"},
							{text: "Hasta la vista! Feliz Navidad! Hasta gazpacho!"},
							{
								text: (
									"WARNING !!!\nyou appear to be incompatible with: THE WORLD\n" +
									"please contact TECH SUPPORT in...\nTHE INFORMATION SUPERHIGHWAY"
								),
							},
							{
								text: (
									"+ PROJECTILE BOOST\n+ PROJECTILE BOOST\n+ PROJECTILE BOOST\n" +
									"+ PROJECTILE BOOST\n+ PROJECTILE BOOST\n+ ENRAGED\n+ PROJECTILE BOOST\n" +
									"+ DISRESPECT\n+ PROJECTILE BOOST"
								),
							},
							{
								text: (
									"If i had a nickel for every time a game in my Steam library made the only " +
									"robot character in its player character roster non-binary, i'd have two " +
									"nickels; which isn't a lot, but it's weird that it happened twice."
								),
							},
							{
								text: (
									"Funding for this program was made possible by the corporation for public " +
									"broadcasting and by annual financial support from viewers like you."
								),
							},
							{text: "I miss my wife, Tails. I miss her a lot. I'll be back."},
							{text: "understand(/*The*/Concept.of(\"LOVE\"));"},
							{
								text: (
									"Well, there are only 99,999 chips here, but they don't call me Lenny the " +
									"Lenient for nothin'. Go on through."
								),
							},
							{text: "^_^"},
							{text: "\\o/"},
							{text: ">download desktop app\n>look inside\n>browser"},
							{text: "Have you tried turning it off and on again?"},
							{text: "[451 Unavailable for legal reasons]"},
							{text: "Stealth is an option."},
							{
								text: (
									"Twisting, turning, I am searching high and low\n" +
									"Locks and keys prevent me from letting go\n" +
									"Through this maze discover my failing heart\n\n" +
									"Didya make it out? Please tell me how."
								),
								textSize: 26,
							},
							{
								text: "WASSO WASSO WASSUUUP BITCONNEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE",
								linebreak: false,
							},
							{image: {name: "google"}},
							{text: "Pick up that can."},
							{text: "enum Bool\n{\n    True,\n    False,\n    FileNotFound\n}"},
							{text: "Me when there'll be greyscale-and-red-as-only-accent-color art at the function:"},
							{text: "<3 Sähikäismenninkkäinen <3"},
							{text: "No, no, i don't really think"},
						])],
					},
				],
				0xAA0000,
				["https://github.com/Square789"],
				{x: 136, y: 120}
			),
			new CreditBlob(
				"EmolgaGamer",
				[Role.ARTIST, Role.CONCEPT_ARTIST],
				Representation.PORTRAIT,
				"emolga",
				[
					{image: {name: "emolga0"}, postPadding: 4},
					{image: {name: "emolga1"}, postPadding: 4},
					{image: {name: "emolga2"}, postPadding: 4},
					{image: {name: "emolga3"}},
					{image: {name: "emolga4"}, postPadding: 4},
					// Turns out trying to shoehorn bitmap fonts into all of this is a pain not worth it,
					// so just typed it out in GIMP with font size 32 ez
					// {
					// 	text: (
					// 		"See, I am doing a new thing!\n" +
					// 		"Now it springs up; do you not perceive it?\n" +
					// 		"I am making a way in the wilderness\n" +
					// 		"and streams in the wasteland."
					// 	),
					// 	font: "pokemon-dp-pro",
					// 	isBitmapFont: true,
					// 	postPadding: 12,
					// },
					// {text: "    - Isaiah 43:19, NIV", font: "pokemon-dp-pro", isBitmapFont: true},
				],
				0xFAFF00,
				["https://reddit.com/user/dz0907"],
				{x: 83, y: 320}
			),
			new CreditBlob(
				"Lunsar",
				[Role.ANIMATOR],
				Representation.PORTRAIT,
				"lunsar",
				[{"text": "professional representative from the hyuns dojo community"}],
				0x0044FF,
				["https://youtube.com/@Lunsar", "https://twitter.com/LunsarXD"],
				{x: 138, y: 198}
			),
			new CreditBlob(
				"remagic",
				[Role.CHARTER],
				Representation.PORTRAIT,
				"remagic",
				[
					{
						text: (
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n" +
							"CONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\nCONDUCTOR WE HAVE A PROBLEM\n"
						),
					}
				],
				0x00FF00,
				{x: 144, y: 133}
			),
			new CreditBlob(
				"Kirbo",
				[Role.DIRECTOR],
				Representation.PORTRAIT,
				"kirbo",
				[
					{
						text: (
							"Follow me on Twitter and support me on Kofi.\n" +
							"For more of my artwork, follow me on Instagram and Kofi under the same name @StellarKirbo"
						)
					},
					{image: {name: "crackbaby"}},
				],
				0x008FF8,
				["https://twitter.com/StellarKirbo", "https://ko-fi.com/StellarKirbo"],
				{x: 166, y: 133}
			),
			new CreditBlob(
				"Ray",
				[Role.ANIMATOR, Role.ARTIST],
				Representation.PORTRAIT,
				"ray",
				[
					{text: "Hey it's me mr funnyman aka RayTheMaymay I do things follow me on twitter"},
					{
						image: {name: "ray", animated: true, frameW: 16, frameH: 16, fps: 8, scale: 2.0},
						location: QuoteLocation.BEHIND_NAME,
					},
				],
				0xDD2222,
				["https://twitter.com/TheMarioWriter"],
				{x: 186, y: 215}
			),
			new CreditBlob(
				"Jospi",
				[Role.COMPOSER, Role.CHARTER],
				Representation.PORTRAIT,
				"jospi",
				[
					{
						text: (
							"I don't know where I'd be without this mod team. It's been an incredible experience " +
							"working with all of these amazing people, being able to make friends, and having some " +
							"funny experiences along the way. I'd like to thank everyone here for all the fun " +
							"times, and you for playing the mod. :]"
						),
						effects: [new TweenQuoteEffect({values: {alpha: 0.5}, duration: 2.6, type: FlxTweenType.PINGPONG})],
					},
				],
				0xC905FF,
				["https://www.youtube.com/@JospiMusic"],
				{x: 81, y: 120}
			),
			new CreditBlob(
				"ThaumcraftMC",
				[Role.PROGRAMMER],
				Representation.PORTRAIT,
				"thaumcraft",
				[
					{text: "Shout-out to everyone who supported us during r/place, y'all are the real ones."},
					{text: "No Lua, HTML5 sucks."},
				],
				0x00FF00,
				["https://twitter.com/ThaumcraftMC"],
				{x: 144, y: 140}
			),
			new CreditBlob(
				"Maurii",
				[Role.ARTIST],
				Representation.PORTRAIT,
				"maurii",
				[
					{text: "funniguy"},
					{text: "Sexy music guy although I didn't do shit for this mod"},
					{text: "hey you should play Marlo..."},
				],
				0xFF5757,
				["https://twitter.com/TheMaurii64"],
				{x: 99, y: 135},
				new MauriiNameSpriteProducer()
			),
			new CreditBlob(
				"GoddessAwe",
				[Role.COMPOSER],
				Representation.ICON,
				"goddessawe",
				[{text: "Menu music and co-created Enough"}],
				0xE9338F,
				["https://www.youtube.com/@awe9037", "https://twitter.com/GoddessAwe"],
				{x: 0, y: 0}
			),
			new CreditBlob(
				"Ronezkj15",
				[Role.COMPOSER],
				Representation.ICON,
				"ronez",
				[{text: "Helped out with [FUTURE NON-DEMO CONTENT]"}],
				0x1B4BBE,
				["https://www.youtube.com/@Ronezkj15"]
			),
			new CreditBlob(
				"Churgney Gurgney",
				[Role.COMPOSER],
				Representation.ICON,
				"churgney",
				[{text: "Mixing Assistance"}],
				0x605F5A,
				["https://twitter.com/gurgney"]
			),
			new CreditBlob(
				"Daniel",
				[Role.ARTIST, Role.PROGRAMMER],
				Representation.PORTRAIT,
				"daniel",
				[
					{
						text: "please let me out of here, it's so cold",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({initialStates: {c:[SHOWN]}, initialTime: {standard: 1.0}})],
					},
					{
						text: "they do not feed me, just get me out",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 2.0, b: 6.0}},
							showTime: {randomOffset: {a: -0.3, b: 0.3}},
						})],
					},
					{
						text: "i dont know how much longer i can stay here, please",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 2.0, b: 5.0}},
							showTime: {randomOffset: {a: 0.0, b: 1.0}},
							hideTime: {randomOffset: {a: 0.0, b: 1.0}},
						})],
					},
					{
						text: "they all forgot",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 0.0, b: 3.0}},
							showTime: {randomOffset: {a: 0.0, b: 2.0}},
							hideTime: {randomOffset: {a: 0.0, b: 1.0}},
						})],
					},
					{
						text: "close the game now i cant take it anymore",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 3.0, b: 7.0}},
							showTime: {randomOffset: {a: 0.0, b: 3.0}},
							hideTime: {randomOffset: {a: 0.0, b: 1.0}},
						})],
					},
					{
						text: "can you hear me?",
						color: 0x5AFFFFFF,
						effects: [new FlickerQuoteEffect({
							initialTime: {randomOffset: {a: 7.0, b: 8.0}},
							showTime: {standard: 6.0},
							hideTime: {standard: 4.0, randomOffset: {a: 0.0, b: 3.0}},
						})],
					},
				],
				0x000000
			),
		],
	},
	{
		name: "Special Thanks",
		members: [
			new CreditBlob(
				"Saruky",
				[Role.COMPOSER],
				Representation.ICON,
				"saruky",
				[{text: "BF Chromatic in [FUTURE NON-DEMO CONTENT]"}],
				0x4800FF,
				["https://linktr.ee/Saruky"],
			),
			new CreditBlob(
				"Philliplol",
				[Role.COMPOSER],
				Representation.ICON,
				"philliplol",
				[{text: "Eduardo Chromatic"}],
				0x2141E4,
				["https://twitter.com/philiplolz"],
			),
			new CreditBlob(
				"Esther Christo",
				[Role.VOICE_ACTOR],
				Representation.ICON,
				"esther_christo",
				[{text: "Monika Chromatic in Consume"}],
				0xAF5CAC,
				["https://twitter.com/carimellevo"],
			),
			new CreditBlob(
				"Ninjamuffin",
				[Role.PROGRAMMER],
				Representation.ICON,
				"ninjamuffin99",
				[{text: "Supported our mission on r/place + [FUTURE NON-DEMO CONTENT]"}],
				0xCF2D2D,
				["https://twitter.com/ninja_muffin99"]
			),
			new CreditBlob(
				"Thriftman",
				[Role.COMPOSER],
				Representation.ICON,
				"thriftman",
				[{text: "[FUTURE NON-DEMO CONTENT]"}],
				0xBBABF2,
				["https://thriftman.newgrounds.com"]
			),
			new CreditBlob(
				"Wandaboy",
				[Role.COMPOSER],
				Representation.ICON,
				"wandaboy",
				[{text: "[FUTURE NON-DEMO CONTENT]"}],
				0x3944A2,
				["https://wandaboy.newgrounds.com"]
			),
			new CreditBlob(
				"Flarewire",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"flarewire",
				[{text: "Funk Mix BF / 8BF Permission [NOT IN DEMO]"}],
				0xD13236,
				["https://www.youtube.com/@Flarewire"]
			),
			new CreditBlob(
				"Big Man!",
				[Role.COMPOSER],
				Representation.ICON,
				"big_man",
				[{text: "Bubbo Permission"}],
				0xFFC90E,
				{x: -18, y: 0}
			),
			new CreditBlob(
				"RubberRoss",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"rubberross",
				[{text: "Supported our mission on r/place"}],
				0xFF293A,
				["https://www.youtube.com/@RubberRoss"]
			),
			new CreditBlob(
				"Indie Alliance",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"indie_alliance",
				[{text: "Supported our mission on r/place"}],
				0xFFFFFF
			),
			new CreditBlob(
				"DJ Grooves",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"djgrooves",
				[{text: "Assembled the original group DM after Sir Sins made the original post."}],
				0xFAA218,
			),
			new CreditBlob(
				"The Spectators",
				[Role.MISCELLANEOUS],
				Representation.ICON,
				"spectators",
				[
					{text: "Spook, Macaroni Boi, Hunter, Sugar, Mango, Ara-Fox, Lespede, Memermaster, Amelia"},
					{
						text: (
							"Thanks for watching the mod dev! Your presence in the server is greatly appreciated, " +
							"we love you guys lol."
						)
					}
				],
				0xFFFFFF
			),
		],
	},
	{
		name: "Psych Engine Extra",
		members: [
			new CreditBlob(
				"Starmapo",
				[Role.PROGRAMMER, Role.ARTIST],
				Representation.ICON,
				"star",
				[{text: "Main Programmer/Artist of Psych Engine Extra"}],
				0xFFDE46,
				["https://github.com/Starmapo"]
			),
			new CreditBlob(
				"KadeDev",
				[Role.PROGRAMMER],
				Representation.ICON,
				"kade",
				[{text: "Kade Engine Creator (Some code taken from there) [NON-AFFILIATED]"}],
				0x64A250,
				["https://twitter.com/kade0912"]
			),
			new CreditBlob(
				"Leather128",
				[Role.PROGRAMMER],
				Representation.ICON,
				"leather",
				[{text: "Leather Engine Creator (Some code taken from there) [NON-AFFILIATED]"}],
				0x01A1FF,
				["https://www.youtube.com/channel/UCbCtO-ghipZessWaOBx8u1g"]
			),
			new CreditBlob(
				"srPerez",
				[Role.PROGRAMMER], // taken from twitter bio
				Representation.ICON,
				"perez",
				[{text: "Original 6K+ designs [NON-AFFILIATED]"}],
				0xFBCA20,
				["https://twitter.com/NewSrPerez"]
			),
			new CreditBlob(
				"GitHub Contributors",
				[Role.PROGRAMMER],
				Representation.ICON,
				"github",
				[{text: "Pull Requests to Psych Engine [NON-AFFILIATED]"}],
				0x546782,
				["https://github.com/ShadowMario/FNF-PsychEngine/pulls"]
			),
		],
	},
	{
		name: "Psych Engine Team",
		members: [
			new CreditBlob("Shadow Mario", [Role.PROGRAMMER], Representation.ICON, "shadowmario", [{text: "Main Programmer of Psych Engine"}], 0x444444, ["https://twitter.com/Shadow_Mario_"]),
			new CreditBlob("RiverOaken", [Role.ANIMATOR, Role.ARTIST], Representation.ICON, "river", [{text: "Main Artist/Animator of Psych Engine"}], 0xB42F71, ["https://twitter.com/RiverOaken"]),
			new CreditBlob("shubs", [Role.PROGRAMMER], Representation.ICON, "shubs", [{text: "Additional Programmer of Psych Engine"}], 0x5E99DF, ["https://twitter.com/yoshubs"]),
			// Originally bbp sat in an explicit ex-programmer category, but i mean the flavor text should be enough to signal that
			new CreditBlob("bb-panzu", [Role.PROGRAMMER], Representation.ICON, "bb", [{text: "Ex-Programmer of Psych Engine"}], 0x3E813A, ["https://twitter.com/bbsub3"]),
		],
	},
	{
		name: "Engine Contributors",
		members: [
			new CreditBlob("iFlicky", [Role.COMPOSER], Representation.ICON, "flicky", [{text: "Composer of Psync and Tea Time; made the dialog sounds"}], 0x9E29CF, ["https://twitter.com/flicky_i"]),
			new CreditBlob("SqirraRNG", [Role.PROGRAMMER], Representation.ICON, "sqirra", [{text: "Crash handler and base code for the chart editor's waveform"}], 0xE1843A, ["https://twitter.com/gedehari"]),
			new CreditBlob("PolybiusProxy", [Role.PROGRAMMER], Representation.ICON, "proxy", [{text: ".mp4 video loader extension"}], 0xDCD294, ["https://twitter.com/polybiusproxy"]),
			new CreditBlob("KadeDev", [Role.PROGRAMMER], Representation.ICON, "kade", [{text: "Fixed some cool stuff in the chart editor and other PRs"}], 0x64A250, ["https://twitter.com/kade0912"]),
			new CreditBlob("Keoiki", [Role.ARTIST], Representation.ICON, "keoiki", [{text: "Note splash animations"}], 0xD2D2D2, ["https://twitter.com/Keoiki_"]),
			new CreditBlob("Nebula the Zorua", [Role.PROGRAMMER], Representation.ICON, "nebula", [{text: "LuaJIT fork and some Lua reworks"}], 0x7D40B2, ["https://twitter.com/Nebula_Zorua"]),
			new CreditBlob("Smokey", [Role.PROGRAMMER], Representation.ICON, "smokey", [{text: "Spritemap texture support"}], 0x483D92, ["https://twitter.com/Smokey_5_"]),
		],
	},
	{
		name: "Funkin' Crew",
		members: [
			new CreditBlob("ninjamuffin99", [Role.PROGRAMMER], Representation.ICON, "ninjamuffin99", [{text: "Programmer of Friday Night Funkin'"}], 0xCF2D2D, ["https://twitter.com/ninja_muffin99"]),
			new CreditBlob("PhantomArcade", [Role.ANIMATOR, Role.ARTIST], Representation.ICON, "phantomarcade", [{text: "Animator of Friday Night Funkin'"}], 0xFADC45, ["https://twitter.com/PhantomArcade3K"]),
			new CreditBlob("evilsk8r", [Role.ARTIST], Representation.ICON, "evilsk8r", [{text: "Artist of Friday Night Funkin'"}], 0x5ABD4B, ["https://twitter.com/evilsk8r"]),
			new CreditBlob("Kawai Sprite", [Role.COMPOSER], Representation.ICON, "kawaisprite", [{text: "Composer of Friday Night Funkin'"}], 0x378FC7, ["https://twitter.com/kawaisprite"]),
		],
	}
]; }


typedef RepresentationGroup = {
	/**
	 * Representation mode. Representation.PORTRAIT Implies members.length == 1. Implies. Not the other way round.
	 */
	representation:Representation,

	/**
	 * RepresentationGroups always exist as part of a PackedCreditGroup array. The element at this
	 * position in the flattened variant of this structure is equal to members[0], and this increasingly goes
	 * for all other members of the RepresentationGroup too.
	 */
	absIdxStart:Int,

	/**
	 * The people in this RepresentationGroup.
	 */
	members:Array<CreditBlob>,
}

typedef PackedCreditGroup = {
	/**
	 * Name of the credit group.
	 */
	name:String,
	/**
	 * The representation groups in this packed credit group.
	 */
	reprGroups:Array<RepresentationGroup>,
}

typedef PCGIndexStruct = {pcgIdx:Int, repgIdx:Int, memIdx:Int}


private class SidebarMemberData {
	public var yPaddingBelow:Float;
	public var yPaddingAbove:Float;
	public var finishableTweens:Array<FinishableVarTween>;

	public function new(yPaddingBelow:Float = 0.0, yPaddingAbove:Float = 0.0) {
		this.yPaddingBelow = yPaddingBelow;
		this.yPaddingAbove = yPaddingAbove;
		this.finishableTweens = [];
	}
}

typedef FinishableTweenOptions = {
	var ?onStart:Null<FlxTween->Void>;
	var ?onUpdate:Null<FlxTween->Void>;
	var ?onComplete:Null<FlxTween->Void>;
	var ?onlyUpdateOnComplete:Null<Bool>;
	var ?duration:Null<Float>;
	var ?ease:Null<EaseFunction>;
}

typedef FinishableTweenSetupInfo = {
	propStruct:Dynamic,
	?options:FinishableTweenOptions,
}


class CreditsSidebarMember extends FlxBasic {
	public var yPaddingBelow:Float;
	public var yPaddingAbove:Float;
	public var finishableTweens:Array<FinishableVarTween>;
	public var obj(default, null):FlxSprite;

	public function new(object:FlxSprite, yPaddingBelow:Float = 0.0, yPaddingAbove:Float = 0.0) {
		super();
		this.yPaddingBelow = yPaddingBelow;
		this.yPaddingAbove = yPaddingAbove;
		this.finishableTweens = [];
		this.obj = object;
	}

	public override function update(dt:Float) {
		obj.update(dt);
	}

	public override function draw() {
		obj.draw();
	}

	public override function destroy() {
		obj.destroy(); obj = null;
		finishableTweens.resize(0); finishableTweens = null;
	}
}

class CreditsSidebar extends FlxTypedGroup<CreditsSidebarMember> {
	private final SLIM_ENTRY_HEIGHT = 8;
	private final EXTENDED_ENTRY_HEIGHT = 38;
	private final ENTRY_PADDING_BELOW = 2.0;
	private final HIDDEN_ENTRY_X = -58;
	private final CO_PACKGROUP_ENTRY_X = -50;
	private final CO_REPGROUP_ENTRY_X = -42;
	private final ENTRY_SLIDE_DURATION:Float = 0.22;
	private final ENTRY_EXPAND_DURATION:Float = 0.08; // Also Contract duration
	private final ENTRY_ANIMATION_NAMES = [for (role in ROLES) role.animationName].concat(["unknown", "slim"]);

	private var selectedEntry:Int = -1;

	/**
	 * Not all elements in the sidebar correspond to a selectable person.
	 * This array has as many elements as there are people and maps them to their actual index in `members`.
	 */
	private var entryIdxToMemberIdxArray:Array<Int>;

	/**
	 * The member others should orient around.
	 */
	private var anchorMemberIdx:Int;

	private var owner:CreditsState;

	public override function new(owner:CreditsState) {
		super(0);

		this.owner = owner;

		entryIdxToMemberIdxArray = [];

		var frames = Paths.getSparrowAtlas("credits/sidebar");
		var curY:Float = SLIM_ENTRY_HEIGHT;
		for (group in owner.packedCreditGroups) {
			var text = new FlxText(-128, curY, 128, group.name, 12);
			add(new CreditsSidebarMember(text, 0, SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW));

			for (repGroup in group.reprGroups) {
				for (mem in repGroup.members) {
					var entry = new FlxSprite(HIDDEN_ENTRY_X, curY);
					entry.frames = frames;
					for (a in ENTRY_ANIMATION_NAMES) {
						entry.animation.addByNames(a, [a], 1, false);
					}
					entry.animation.play("slim");
					entry.color = mem.color;
					entry.origin.set(0, 0);

					entryIdxToMemberIdxArray.push(this.length);
					add(new CreditsSidebarMember(entry, SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW));

					curY += SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW;
				}
			}
			curY += 12;
		}

		anchorMemberIdx = 0;
	}

	public override function update(dt:Float) {
		// Each element has a vertical pushdown and pushup factor.
		super.update(dt);
		if (members.length == 0) {
			return;
		}

		for (i in new RevRange(anchorMemberIdx - 1, -1)) {
			var mem = members[i];
			var nxtMem = members[i + 1];
			mem.obj.y = nxtMem.obj.y - (mem.yPaddingBelow + nxtMem.yPaddingAbove);
		}
		for (i in (anchorMemberIdx + 1)...members.length) {
			var mem = members[i];
			var prvMem = members[i - 1];
			mem.obj.y = prvMem.obj.y + prvMem.yPaddingBelow + mem.yPaddingAbove;
		}
	}

	private function startEntryTweenlikes(entryIdx:Int, tweenlikeSetup:Array<FinishableTweenSetupInfo>) {
		startMemberTweenlikes(entryIdxToMemberIdxArray[entryIdx], tweenlikeSetup);
	}

	private function startMemberTweenlikes(memberIdx:Int, tweenlikeSetup:Array<FinishableTweenSetupInfo>) {
		var tarr = members[memberIdx].finishableTweens;
		for (t in tarr) {
			t.instaFinishAndCancel();
			//t.cancel(); // cancel alone breaks some stuff
		}
		tarr.resize(0);

		for (tsd in tweenlikeSetup) {
			var options:FinishableTweenOptions = tsd.options == null ? {} : tsd.options;
			// == true cause it can be null?
			var onComplete = options.onlyUpdateOnComplete == true ? options.onUpdate : options.onComplete;

			var t = FinishableVarTween.finTween(
				members[memberIdx],
				tsd.propStruct,
				options.duration == null ? ENTRY_SLIDE_DURATION : options.duration,
				{
					onStart: options.onStart,
					onUpdate: options.onUpdate,
					onComplete: onComplete,
					ease: options.ease,
				}
			);
			tarr.push(t);
		}
	}

	public function instantlyFinishTweens() {
		for (m in members) {
			for (t in m.finishableTweens) {
				t.instaFinishAndCancel();
			}
			m.finishableTweens.resize(0);
		}
	}

	public function setSelectedIndex(newIdx:Int) {
		var reprGroupChanged = false;
		var packedGroupChanged = false;
		// Remember: packedGroupChanged implies reprGroupChanged
		var initializing = selectedEntry == -1;

		var nloc = owner.memberIdxToPackedGroupIdx[newIdx];

		if (!initializing) {
			var oloc = owner.memberIdxToPackedGroupIdx[selectedEntry];
			packedGroupChanged = oloc.pcgIdx != nloc.pcgIdx;
			reprGroupChanged = packedGroupChanged || oloc.repgIdx != nloc.repgIdx;

			var entriesToRetreat:Array<Int> = [];
			var retreatX:Int = CO_REPGROUP_ENTRY_X;
			if (packedGroupChanged) {
				var oldPcg = owner.packedCreditGroups[oloc.pcgIdx];
				var _oldPcgLastReprGroup = oldPcg.reprGroups[oldPcg.reprGroups.length - 1];
				var oldPcgAbsStart = oldPcg.reprGroups[0].absIdxStart;
				var oldPcgAbsEnd = _oldPcgLastReprGroup.absIdxStart + _oldPcgLastReprGroup.members.length;

				// Make text of old pcg disappear
				var pcgTextIdx = entryIdxToMemberIdxArray[oldPcgAbsStart] - 1;
				members[pcgTextIdx].yPaddingBelow = members[pcgTextIdx].obj.height + 2;
				startMemberTweenlikes(
					pcgTextIdx,
					[
						{propStruct: {"obj.x": -128}},
						{propStruct: {yPaddingBelow: 0}, options: {ease: FlxEase.quadOut}},
					]
				);

				// Retreat all entries of old pcg
				retreatX = HIDDEN_ENTRY_X;
				entriesToRetreat = [for (i in oldPcgAbsStart...oldPcgAbsEnd) i];
			} else if (reprGroupChanged) {
				var oldRepg = owner.packedCreditGroups[oloc.pcgIdx].reprGroups[oloc.repgIdx];
				// Retreat entries of old repr group go to common packgroup level
				retreatX = CO_PACKGROUP_ENTRY_X;
				entriesToRetreat = [for (i in (oldRepg.absIdxStart)...(oldRepg.absIdxStart + oldRepg.members.length)) i];
			}
			for (i in entriesToRetreat) {
				if (i != selectedEntry) {
					startEntryTweenlikes(i, [{propStruct: {"obj.x": retreatX}}]);
				}
			}

			// Move old entry back more complicatedly
			var prevMember = members[entryIdxToMemberIdxArray[selectedEntry]];
			prevMember.yPaddingBelow = EXTENDED_ENTRY_HEIGHT + ENTRY_PADDING_BELOW;
			prevMember.obj.animation.play("slim");
			prevMember.obj.scale.y = (cast(EXTENDED_ENTRY_HEIGHT, Float) / SLIM_ENTRY_HEIGHT);
			startEntryTweenlikes(
				selectedEntry,
				[
					{propStruct: {"obj.x": retreatX}, options:    {ease: FlxEase.quartOut}},
					{
						propStruct: {"obj.scale.y": 1.0, yPaddingBelow: SLIM_ENTRY_HEIGHT + ENTRY_PADDING_BELOW},
						options:    {duration: ENTRY_EXPAND_DURATION}
					},
				]
			);
		} else {
			reprGroupChanged = true;
			packedGroupChanged = true;
		}

		var newPcg = owner.packedCreditGroups[nloc.pcgIdx];
		var newRepg = newPcg.reprGroups[nloc.repgIdx];
		var firstNewRepg = newPcg.reprGroups[0];
		var lastNewRepg = newPcg.reprGroups[newPcg.reprGroups.length - 1];
		if (packedGroupChanged) {
			// Index hackery; this is the group name text of the new packed group.
			// Make text slide in
			var pcgTextIdx = entryIdxToMemberIdxArray[firstNewRepg.absIdxStart] - 1;
			var slidingTextMem = members[pcgTextIdx];
			slidingTextMem.yPaddingBelow = 0.0;
			startMemberTweenlikes(
				pcgTextIdx,
				[
					{propStruct: {"obj.x": 0}},
					{propStruct: {yPaddingBelow: slidingTextMem.obj.height + 2}, options: {ease: FlxEase.quadIn}},
				]
			);

			// Get all entries that should be at the common packgroup level on it
			for (i in (firstNewRepg.absIdxStart)...(lastNewRepg.absIdxStart + lastNewRepg.members.length)) {
				if (i < newRepg.absIdxStart || i >= (newRepg.absIdxStart + newRepg.members.length)) {
					startEntryTweenlikes(i, [{propStruct: {"obj.x": CO_PACKGROUP_ENTRY_X}}]);
				}
			}
		}
		if (reprGroupChanged) {
			// Tween all entries in the current reprgroup that aren't the selected entry onto the reprgroup level
			for (i in (newRepg.absIdxStart)...(newRepg.absIdxStart + newRepg.members.length)) {
				if (i != newIdx) {
					startEntryTweenlikes(i, [{propStruct: {"obj.x": CO_REPGROUP_ENTRY_X}}]);
				}
			}
		}

		// Finally, tween the grand star of the show to 0, have its animation pop up and make it flow to the absolute y
		var newAnimation = (
			newRepg.members[nloc.memIdx].roles.length > 0 ?
				newRepg.members[nloc.memIdx].roles[0].animationName :
				"unknown"
		);
		var member = members[entryIdxToMemberIdxArray[newIdx]];
		member.obj.animation.play(newAnimation);
		member.obj.scale.y = cast(SLIM_ENTRY_HEIGHT, Float) / EXTENDED_ENTRY_HEIGHT;
		member.yPaddingBelow = ENTRY_PADDING_BELOW + SLIM_ENTRY_HEIGHT;
		startEntryTweenlikes(
			newIdx,
			[
				{propStruct: {"obj.x": 0}, options:    {ease: FlxEase.quartOut}},
				{
					propStruct: {
						"obj.y": FlxG.height / 4,
						"obj.scale.y": 1.0,
						yPaddingBelow: EXTENDED_ENTRY_HEIGHT + ENTRY_PADDING_BELOW,
					},
					options:    {duration: ENTRY_EXPAND_DURATION}
				},
			]
		);

		selectedEntry = newIdx;
		anchorMemberIdx = entryIdxToMemberIdxArray[newIdx];

		if (initializing) {
			instantlyFinishTweens();
		}
	}
}

class MeasurerCache implements IFlxDestroyable {
	// If only haxe had nice-to-use tuples as key or something but hey
	private var _map:Map<String, Map<Int, ITextMeasurer>>;
	public function new() {
		this._map = new Map<String, Map<Int, ITextMeasurer>>();
	}

	public function get(font:String, size:Int, bold:Bool) {
		var secondKey:haxe.Int32 = (size & 0xFFFF) | ((bold ? 1 : 0) << 16);
		_maybeCreateMap(font);
		if (!_map[font].exists(secondKey)) {
			_map[font][secondKey] = new TextMeasurer(font, size, bold);
		}
		return _map[font][secondKey];
	}

	private function _maybeCreateMap(font:String) {
		if (!_map.exists(font)) {
			_map[font] = new Map<Int, ITextMeasurer>();
		}
	}

	public function destroy() {
		for (m in _map) {
			for (tm in m) {
				tm.destroy();
			}
			m.clear(); m = null;
		}
		_map.clear(); _map = null;
	}
}

abstract class RepresentationSpriteGroup extends FlxSpriteGroup {
	private var owner:CreditsState;
	private var effectUpdaters:Array<QuoteEffectUpdater>;
	private var quoteSlots:Array<QuoteFieldSlot>;

	public function new(owner:CreditsState) {
		super();
		this.effectUpdaters = [];
		this.owner = owner;
		this.quoteSlots = [new QuoteFieldSlot(owner), new BehindNameSlot(owner)];
	}

	private function addSpritesFromQuote(quote:Quote, space:Float, lineLimit:Int) {
		var slot = quoteSlots[quote.location];
		if (!slot.shouldContinue()) {
			return;
		}

		quote = quote.alterQuote();
		var thisQuotesSprites:Array<FlxSprite> = [];

		if (quote.image != null) {
			var sprite = new FlxSprite(slot.currentPosition.x, slot.currentPosition.y,);
			if (quote.image.animated) {
				sprite.loadGraphic(
					Paths.image('credits/quote_images/${quote.image.name}'),
					true,
					quote.image.frameW,
					quote.image.frameH
				);
				sprite.animation.add("main", [for (i in 0...(sprite.frames.numFrames)) i], quote.image.fps, true);
				sprite.animation.play("main");
			} else {
				sprite.loadGraphic(Paths.image('credits/quote_images/${quote.image.name}'));
			}
			if (quote.image.scale != 1.0) {
				sprite.scale.set(quote.image.scale, quote.image.scale);
				sprite.updateHitbox();
				sprite.origin.set(0.0, 0.0);
				sprite.offset.set(0.0, 0.0);
			}

			slot.adjustAndAdvance(sprite);

			add(sprite);
			thisQuotesSprites.push(sprite);
		} else {
			// Horrid text splitting and layout code follows
			var lines:Array<String>;
			if (!quote.linebreak) {
				lines = [quote.text.trim()];
			} else {
				lines = splitTextAndWordIntoLines(
					quote.text,
					space,
					owner.measurerCache.get(quote.font, quote.textSize, quote.bold),
					lineLimit
				);
			}

			for (line in lines) {
				var text = new FlxText(slot.currentPosition.x, slot.currentPosition.y, 0, line);
				text.alpha = quote.color.alphaFloat;
				text.setFormat(quote.font, quote.textSize, quote.color, LEFT);
				if (quote.bold) {
					text.addFormat(new FlxTextFormat(null, true));
				}

				add(text);
				thisQuotesSprites.push(text);

				if (!slot.adjustAndAdvance(text)) {
					break;
				}
			}
		}
		slot.advance(quote.postPadding);

		for (updater in quote.applyEffectsTo(thisQuotesSprites)) {
			effectUpdaters.push(updater);
		}
	}

	private function addSpritesFromQuotes(quotes:Array<Quote>, space:Float, lineLimit:Int = 32) {
		for (quote in quotes) {
			addSpritesFromQuote(quote, space, lineLimit);
		}
	}

	private function addSpritesForName(
		name:String, producer:NameSpriteProducer, slot:QuoteLocation = QuoteLocation.BEHIND_NAME
	) {
		var slot = quoteSlots[slot];
		// var tmp = new FlxSprite(slot.currentPosition.x, slot.currentPosition.y);
		var nameSprite = producer.makeName(slot.currentPosition.x, slot.currentPosition.y, name);
		if (slot.adjustAndAdvance(nameSprite)) {
			add(nameSprite);
		}
		// CoolUtil.InflatedPixelSpriteExt.makeInflatedPixelGraphic(tmp, 0xFFFF0000, 256, 2);
		// add(tmp);
	}

	public override function destroy() {
		forEach((spr) -> { FlxTween.cancelTweensOf(spr); });
		effectUpdaters = null;
		super.destroy();
	}

	public override function update(dt:Float) {
		super.update(dt);
		for (u in effectUpdaters) {
			u.update(dt);
		}
	}

	/**
	 * Re-and dehighlights a repgroup's members when he representation group has
	 * not changed, but the selected member has.
	 * `oldIdx` may be -1.
	 */
	public abstract function newIndex(oldIdx:Int, newIdx:Int):Void;
	public abstract function getPillarY(memberIdx:Int):Float;
}

class PortraitRepresentationSpriteGroup extends RepresentationSpriteGroup {
	public function new(rg:RepresentationGroup, owner:CreditsState) {
		super(owner);

		var person = rg.members[0];
		var portrait = new FlxSprite(person.offset.x, person.offset.y, person.image);
		portrait.antialiasing = true;
		portrait.pixelPerfectRender = true;
		add(portrait);

		quoteSlots[QUOTE_FIELD].setInitial(520, 148);
		quoteSlots[BEHIND_NAME].setInitial(526, 128);
		addSpritesForName(person.name, person.nameSpriteProducer);
		addSpritesFromQuotes(person.quotes, FlxG.width - 520 - 32);
	}

	// Getting a new index in portrait groups makes no sense, ignore.
	public function newIndex(oldIdx:Int, newIdx:Int) {}
	public function getPillarY(_:Int):Float {
		return 128;
	}
}

class IconRepresentationSpriteGroup extends RepresentationSpriteGroup {
	private var memberStart:Map<Int, Int>;
	// We found it: The worst variable name.
	// "creditsMemberIdxAsInTeamMemberToActualSpriteGroupMemberMapIdx" would probably be
	// better but i dont care

	public function new(rg:RepresentationGroup, owner:CreditsState) {
		super(owner);

		memberStart = new Map<Int, Int>();
		for (i => person in rg.members) {
			memberStart[i] = length;
			var yHeadstart = i * 180;
			var leftStart = 164 - owner.getXDifferenceOnSlope(yHeadstart);

			var icon:FlxSprite = new FlxSprite(
				leftStart + person.offset.x, 96 + yHeadstart + person.offset.y, person.image
			);
			icon.alpha = 0.4;
			add(icon);

			var textX = 180 + leftStart - owner.getXDifferenceOnSlope(64);
			var nameX = 180 + leftStart;
			quoteSlots[QUOTE_FIELD].setInitial(textX, 160 + yHeadstart);
			quoteSlots[BEHIND_NAME].setInitial(nameX, 144 + yHeadstart);
			addSpritesForName(person.name, person.nameSpriteProducer);
			addSpritesFromQuotes(person.quotes, Math.max(100, FlxG.width - textX - 20), 3);
		}
	}

	public function newIndex(oldIdx:Int, newIdx:Int) {
		if (oldIdx != -1) {
			members[memberStart[owner.memberIdxToPackedGroupIdx[oldIdx].memIdx]].alpha = 0.4;
		}
		members[memberStart[owner.memberIdxToPackedGroupIdx[newIdx].memIdx]].alpha = 1.0;
	}

	public function getPillarY(localMemberIdx:Int):Float {
		return 144 + localMemberIdx * 180;
	}
}

class EdgeCutoffShader extends FlxShader {
	@:glFragmentSource('
		#pragma header

		#define uv openfl_TextureCoordv

		uniform float angle;

		// Imagine simple slopes in the end parts of the sprite with the classic
		// formula m*x + b;
		// Simply calculate whether this pixel is under/over that slope, and alpha
		// out accordingly.
		// This only works when the sprite is rotated in a 0..90 or 180..270 deg angle
		// Too bad!

		void main() {
			float ar_correction = openfl_TextureSize.x / openfl_TextureSize.y;
			float m = tan(radians(angle)) * ar_correction;
			if (
				( (uv.x * m)              > (1.0 - uv.y)) ||
				(((uv.x * m) + (1.0 - m)) < (1.0 - uv.y))
			) {
				gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
			} else {
				gl_FragColor = flixel_texture2D(bitmap, uv);
			}
		}
	')

	public function new(angle:Float) {
		super();
		this.angle.value = [angle];
	}
}

/**
 * The slanted text things displaying links and member roles.
 */
class Pillar extends FlxSpriteGroup {
	public var bg:FlxSprite;
	public var evenedY(default, null):Float;

	public function new(width:Int, height:Int, angle:Float) {
		super();

		bg = new FlxSprite(0, 0).makeGraphic(width, height, FlxColor.BLACK);
		bg.origin.set(0, 0);
		bg.angle = angle;
		bg.shader = new EdgeCutoffShader(angle);
		add(bg);

		evenedY = Math.cos(d2r(angle)) * bg.height;
	}

	public function clearContents() {
		for (i in 1...members.length) {
			if (members[i] != null) {
				members[i].destroy();
				members[i] = null;
			}
		}
	}
}


class CreditsState extends MusicBeatState {
	private final HOLD_SCROLL_TRIGGER_TIME = 0.4;
	private final HOLD_TIME_INI = 0.18;
	private final HOLD_TIME_HORIZON = 0.09;
	private final ELEMENT_ANGLE = 5.625;
	private final ROLE_PILLAR_WIDTH = 186;
	private final LINK_PILLAR_WIDTH = 50;
	private final PILLAR_HEIGHT = 768;

	/**
	 * Index of selected member. If -1, state has just been created.
	 */
	var selectedMemberIdx:Int;

	/**
	 * Index of selectected link.
	 */
	var selectedLinkIdx:Int;
	var availableLinks:Array<{link:String, screenLocation:PointStruct}>;
	var linkSelectorStripeTopYLoss:Int;
	var linkSelectorStripe:FlxSprite;
	var linkSelectorStripeDissipator:SpriteDissipator;

	/**
	 * Group to place the custom representation sprite groups in.
	 */
	var representationSpriteGroupContainer:FlxGroup;

	/**
	 * Sprite group containing sprites for the displayed people.
	 */
	var representationSpriteGroup:Null<RepresentationSpriteGroup>;

	/**
	 * Slightly translucent black sprite to make text better readable.
	 */
	var backgroundDarkener:FlxSprite;

	/**
	 * Group containing the role pillar thing. First element is the background sprite,
	 * the rest is dynamic and based on the selected person's roles.
	 */
	var rolePillar:Pillar;

	/**
	 * Like the role pillar, just for the link icons.
	 */
	var linkPillar:Pillar;

	var sidebar:CreditsSidebar;

	public var measurerCache:MeasurerCache;

	public var packedCreditGroups:Array<PackedCreditGroup>;

	/**
	 * Maps a specific person to their packed credits group's index and sub-index therein.
	 */
	public var memberIdxToPackedGroupIdx:Array<PCGIndexStruct>;

	private var holdTimer:HoldTimer;

	// This all could be a substate but that comes with its own annoyances.
	// Both of these are just spritegroups so i can run .visible on them with ease lol
	private var linkOpenerOverlay:FlxSpriteGroup;
	private var linkOpenerOverlayArrows:FlxSpriteGroup;
	private var linkOpenerOverlayShown:Bool;
	private var linkOpenerOverlayText:FlxText;

	public override function create() {
		super.create();

		selectedMemberIdx = -1;
		selectedLinkIdx = -1;
		availableLinks = [];

		packedCreditGroups = [];
		memberIdxToPackedGroupIdx = [];
		var absIdx = 0;
		for (cgIdx => group in makeCredits()) {
			var curRepGroupArray:Array<RepresentationGroup> = [];
			var curPcg = {name: group.name, reprGroups: curRepGroupArray};
			var membCopy = group.members.copy();
			// ArraySort.sort(membCopy, (a, b) -> a.representation.priority - b.representation.priority);
			var memIdx = 0;
			while (memIdx < membCopy.length) {
				var representation = membCopy[memIdx].representation;
				var slc = membCopy.slice(memIdx, memIdx + representation.memberDisplayCount);
				for (i in 0...slc.length) {
					memberIdxToPackedGroupIdx.push({pcgIdx: cgIdx, repgIdx: curRepGroupArray.length, memIdx: i});
				}
				curRepGroupArray.push({representation: representation, absIdxStart: absIdx, members: slc});
				memIdx += slc.length;
				absIdx += slc.length;
			}
			packedCreditGroups.push(curPcg);
		}

		var bg = new FlxSprite(0, 0).loadGraphic(Paths.image("credits/background"));
		add(bg);

		var topLetterbox = new FlxSprite().makeGraphic(1536, 384, FlxColor.BLACK, false);
		var bottomLetterbox = new FlxSprite().makeGraphic(1536, 384, FlxColor.BLACK, false);
		backgroundDarkener = new FlxSprite().makeGraphic(1024, 1024, FlxColor.BLACK, false);

		for (thing in [topLetterbox, bottomLetterbox, backgroundDarkener]) {
			thing.antialiasing = true;
			thing.angle = ELEMENT_ANGLE;
		}
		topLetterbox.y = -320;
		bottomLetterbox.setPosition(-24, 658);

		backgroundDarkener.alpha = 0.8;

		representationSpriteGroupContainer = new FlxGroup(1);
		representationSpriteGroup = null;
		measurerCache = new MeasurerCache();
		sidebar = new CreditsSidebar(this);

		var linkOpenerOverlayDimmer = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		linkOpenerOverlayDimmer.alpha = 0.64;
		linkOpenerOverlayDimmer.visible = false;

		var linkOpenerOverlayBackground = new FlxSprite().makeGraphic(960, 420, FlxColor.BLACK);
		linkOpenerOverlayBackground.angle = 8;
		linkOpenerOverlayBackground.shader = new EdgeCutoffShader(8);
		linkOpenerOverlayBackground.screenCenter();

		linkOpenerOverlayArrows = new FlxSpriteGroup(2);
		for (o in [
			{n: "left",  x: linkOpenerOverlayBackground.x - 24},
			{n: "right", x: linkOpenerOverlayBackground.x + linkOpenerOverlayBackground.width - 16},
		]) {
			var f = new FlxSprite(o.x);
			f.frames = Paths.getSparrowAtlas("menu_arrows");
			f.frame = f.frames.getByName('long_${o.n}');
			f.screenCenter(Y);
			linkOpenerOverlayArrows.add(f);
		}

		linkOpenerOverlayText = new FlxText(0, 0, 720);
		linkOpenerOverlayText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, FlxTextAlign.CENTER);
		linkOpenerOverlayText.visible = false;

		linkOpenerOverlay = new FlxSpriteGroup();
		linkOpenerOverlay.add(linkOpenerOverlayDimmer);
		linkOpenerOverlay.add(linkOpenerOverlayBackground);
		linkOpenerOverlay.add(linkOpenerOverlayArrows);
		linkOpenerOverlay.add(linkOpenerOverlayText);
		linkOpenerOverlay.visible = false;

		rolePillar = new Pillar(ROLE_PILLAR_WIDTH, PILLAR_HEIGHT, ELEMENT_ANGLE);
		linkPillar = new Pillar(LINK_PILLAR_WIDTH, PILLAR_HEIGHT, ELEMENT_ANGLE);

		linkSelectorStripeTopYLoss = 1; // Whatever, hardcoded. I am overengineering this 32px strip shut uuuuuup
		// Math.floor(Math.sin(d2r(ELEMENT_ANGLE)) * 32);
		linkSelectorStripe = new FlxSprite().makeGraphic(6, 32 + linkSelectorStripeTopYLoss, FlxColor.WHITE);
		linkSelectorStripe.origin.set(0, 0);
		linkSelectorStripe.angle = ELEMENT_ANGLE;
		linkSelectorStripe.alpha = 0.4;
		linkSelectorStripe.visible = false;
		linkSelectorStripe.shader = new EdgeCutoffShader(ELEMENT_ANGLE);

		linkSelectorStripeDissipator = new SpriteDissipator(linkSelectorStripe, 0.48, 0.32, 4);
		linkSelectorStripeDissipator.direction = 270;
		linkSelectorStripeDissipator.velocity = 22.0;
		linkSelectorStripeDissipator.initialDisplacement = 4;
		for (sprite in linkSelectorStripeDissipator.group.members) {
			sprite.shader = new EdgeCutoffShader(ELEMENT_ANGLE);
		}

		add(backgroundDarkener);
		add(bottomLetterbox);
		add(topLetterbox);
		add(representationSpriteGroupContainer);
		add(sidebar);
		add(rolePillar);
		add(linkPillar);
		add(linkSelectorStripeDissipator.group);
		add(linkSelectorStripe);
		add(linkOpenerOverlay);

		holdTimer = new HoldTimer(HOLD_SCROLL_TRIGGER_TIME, HOLD_TIME_INI, HOLD_TIME_HORIZON, 0.5);
		holdTimer.listen(controls.ui_downP, controls.ui_down, changeDisplayedEntry, 1);
		holdTimer.listen(controls.ui_upP, controls.ui_up, changeDisplayedEntry, -1);
		linkOpenerOverlayShown = false;

		// initial display. Cheaty since -1 + 1 = 0 so the first entry is displayed
		changeDisplayedEntry(1);
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (FlxG.sound.music.volume < 0.7) {
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
		}

		linkSelectorStripeDissipator.update(elapsed);

		if (linkOpenerOverlayShown) {
			if (controls.ACCEPT) {
				CoolUtil.browserLoad(availableLinks[selectedLinkIdx].link);
				linkOpenerOverlayShown = false;
				linkOpenerOverlay.visible = false;
				return;
			} else if (controls.BACK) {
				linkOpenerOverlayShown = false;
				linkOpenerOverlay.visible = false;
				return;
			}

			if (controls.UI_LEFT_P != controls.UI_RIGHT_P) {
				changeSelectedLink(controls.UI_LEFT_P ? -1 : 1);
				setLinkOpenerOverlayText();
			}

			return;
		}

		if (controls.ACCEPT) {
			if (selectedLinkIdx >= 0 && selectedLinkIdx < availableLinks.length) {
				linkOpenerOverlayShown = true;
				setLinkOpenerOverlayText();
				linkOpenerOverlay.visible = true;
				linkOpenerOverlayArrows.visible = availableLinks.length > 1;
				return;
			}
		}
		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.7);
			MusicBeatState.switchState(new MainMenuF4rpState(true));
			return;
		}

		holdTimer.update(elapsed);

		if (controls.UI_LEFT_P != controls.UI_RIGHT_P) {
			changeSelectedLink(controls.UI_LEFT_P ? -1 : 1);
		}

	}

	private function reloadRepresentationSpriteGroup(rg:RepresentationGroup) {
		// Not doing this will leak memory terrifyingly fast
		if (representationSpriteGroupContainer.length > 0) {
			representationSpriteGroupContainer.members[0].destroy();
			representationSpriteGroupContainer.clear();
		}

		representationSpriteGroup = Type.createInstance(rg.representation.representationGroupClass, [rg, this]);
		representationSpriteGroupContainer.add(representationSpriteGroup);
	}

	private function changeDisplayedEntry(by:Int) {
		var newSelectedMemberIdx = CoolUtil.wrapModulo(selectedMemberIdx + by, memberIdxToPackedGroupIdx.length);
		var shouldReloadRepresentationGroup = false;
		var shouldChangeRepresentationMode = false;
		var oldSelectedMemberidx = selectedMemberIdx;

		var newLocation:PCGIndexStruct = memberIdxToPackedGroupIdx[newSelectedMemberIdx];
		var newPCG:PackedCreditGroup = packedCreditGroups[newLocation.pcgIdx];
		var newRG:RepresentationGroup = newPCG.reprGroups[newLocation.repgIdx];
		var oldLocation:Null<PCGIndexStruct> = null;
		var oldPCG:Null<PackedCreditGroup> = null;
		var oldRG:Null<RepresentationGroup> = null;

		if (oldSelectedMemberidx != -1) {
			oldLocation = memberIdxToPackedGroupIdx[oldSelectedMemberidx];
			oldPCG = packedCreditGroups[oldLocation.pcgIdx];
			oldRG = oldPCG.reprGroups[oldLocation.repgIdx];

			shouldReloadRepresentationGroup = (
				oldLocation.pcgIdx != newLocation.pcgIdx || oldLocation.repgIdx != newLocation.repgIdx
			);
			shouldChangeRepresentationMode = oldRG.representation != newRG.representation;
		} else {
			shouldReloadRepresentationGroup = true;
			shouldChangeRepresentationMode = true;
		}

		sidebar.setSelectedIndex(newSelectedMemberIdx);

		if (shouldChangeRepresentationMode) {
			changeRepresentationMode(newRG.representation);
		}
		if (shouldReloadRepresentationGroup) {
			reloadRepresentationSpriteGroup(newRG);
			representationSpriteGroup.newIndex(-1, newSelectedMemberIdx);
		} else {
			representationSpriteGroup.newIndex(selectedMemberIdx, newSelectedMemberIdx);
		}

		updatePillarsAndLinks(newSelectedMemberIdx);

		selectedMemberIdx = newSelectedMemberIdx;
	}

	private function changeRepresentationMode(newMode:Representation) {
		switch (newMode) {
		// For the backgroundDarkener i could certainly do trigonometry and find the perfect
		// new position considering its angle but nah
		case Representation.ICON:
			backgroundDarkener.setPosition(284, -40);
		case Representation.PORTRAIT:
			backgroundDarkener.setPosition(460, -20);
		}
	}

	private function updatePillarsAndLinks(newMemberIndex:Int) {
		// Logic kinda breaks down here again. Oh well.
		var mem = getMemberByIndex(newMemberIndex);

		var desiredY = representationSpriteGroup.getPillarY(memberIdxToPackedGroupIdx[newMemberIndex].memIdx);
		var linkY = mem.links.length > 0 ? desiredY : -1;
		rolePillar.clearContents();
		linkPillar.clearContents();
		rolePillar.setPosition(1152 - getXDifferenceOnSlope(desiredY), desiredY - rolePillar.evenedY);
		linkPillar.setPosition(1152 - LINK_PILLAR_WIDTH - 8 - getXDifferenceOnSlope(linkY), linkY - linkPillar.evenedY);

		var lastY:Float = rolePillar.evenedY;
		for (i in new RevRange(FlxMath.minInt(3, mem.roles.length - 1), -1)) {
			// 1st role tends to be the most important one and people read from top-to-bottom 99%
			// of the time, so reverse these
			var role = mem.roles[i];
			var icon = new FlxSprite(4, lastY - (4.0 + 32.0));
			icon.x = -getXDifferenceOnSlope(icon.y);
			icon.frames = Paths.getSparrowAtlas("credits/role_icons");
			icon.frame = icon.frames.getByName(role.animationName);

			var text = new FlxText(0, 0, 0, role.displayString, 16);
			text.y = icon.y + ((icon.height - text.height) / 2);
			text.x = (4 + icon.width) - getXDifferenceOnSlope(text.y);

			lastY = icon.y; // gotta do this before as FlxSpriteGroup modifies its members' positions
			rolePillar.add(icon);
			rolePillar.add(text);
		}

		availableLinks.resize(0);
		lastY = linkPillar.evenedY;
		for (i in 0...FlxMath.minInt(3, mem.links.length)) {
			var linkInfo = mem.links[i];
			var y = lastY - (4.0 + 32.0);
			lastY = y;
			var icon = new FlxSprite((LINK_PILLAR_WIDTH - 32 - 6) - getXDifferenceOnSlope(y), y);
			icon.frames = Paths.getSparrowAtlas("credits/link_icons");
			icon.frame = icon.frames.getByName(linkInfo.iconName);
			linkPillar.add(icon);
			availableLinks.push(
				{link: linkInfo.link, screenLocation: {x: icon.x, y: icon.y}}
			);
		}

		setSelectedLink(availableLinks.length > 0 ? 0 : -1);
	}

	private function setSelectedLink(idx:Int) {
		if (idx < 0) {
			selectedLinkIdx = -1;
			linkSelectorStripe.visible = linkSelectorStripeDissipator.active = false;
			return;
		}

		selectedLinkIdx = idx;
		var link = availableLinks[idx];
		linkSelectorStripe.setPosition(
			link.screenLocation.x - linkSelectorStripe.width - 2.0,
			link.screenLocation.y - linkSelectorStripeTopYLoss
		);
		linkSelectorStripe.visible = linkSelectorStripeDissipator.active = true;
	}

	private function changeSelectedLink(by:Int) {
		if (availableLinks.length == 0) {
			setSelectedLink(-1);
		} else {
			setSelectedLink(CoolUtil.wrapModulo(selectedLinkIdx + by, availableLinks.length));
		}
	}

	private function setLinkOpenerOverlayText() {
		var visit = controls.getFirstFormattedInputName(Controls.Control.ACCEPT);
		var cancel = controls.getFirstFormattedInputName(Controls.Control.BACK);
		linkOpenerOverlayText.text = (
			'Visit?:\n${availableLinks[selectedLinkIdx].link}\n\n[$visit] Yes - [$cancel] Cancel'
		);
		linkOpenerOverlayText.screenCenter();
	}

	/**
	 * Object movement on the X axis for keeping it aligned with that tilted
	 * text background view thing
	 */
	public function getXDifferenceOnSlope(distance:Float) {
		return (distance * Math.sin(d2r(ELEMENT_ANGLE))) / Math.cos(d2r(ELEMENT_ANGLE));
	}

	/**
	 * Returns a member's CreditBlob by absolute index, no hassle with the index struct.
	 */
	public inline function getMemberByIndex(idx:Int):Null<CreditBlob> {
		var idxStruct = memberIdxToPackedGroupIdx[idx];
		return packedCreditGroups[idxStruct.pcgIdx].reprGroups[idxStruct.repgIdx].members[idxStruct.memIdx];
	}
}
