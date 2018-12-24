package aze.display;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.Sprite;
#if (openfl >= "4.0.0")
import openfl.display.Tilemap;
import openfl.events.Event;
#end
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.Lib;

/**
 * A little wrapper of NME's Tilesheet rendering (for native platform)
 * and using Bitmaps for Flash platform.
 * Features basic containers (TileGroup) and spritesheets animations.
 * @author Philippe / http://philippe.elsass.me
 */
class TileLayer extends TileGroup
{
	static var synchronizedElapsed:Float;

	public var view:Sprite;
	public var useSmoothing:Bool;
	public var useAdditive:Bool;
	public var useAlpha:Bool;
	public var useTransforms:Bool;
	public var useTint:Bool;

	public var tilesheet:TilesheetEx;
	var drawList:DrawList;
	#if (openfl >= "4.0.0")
	var tilemap:Tilemap;
	#end

	public function new(tilesheet:TilesheetEx, width:Int, height:Int, smooth:Bool=true, additive:Bool=false)
	{
		super(this);

		view = new Sprite();
		view.mouseEnabled = false;
		view.mouseChildren = false;

		#if (openfl >= "4.0.0")
		tilemap = new Tilemap(width, height, tilesheet);
		view.addChild(tilemap);
		#end

		this.tilesheet = tilesheet;
		useSmoothing = smooth;
		useAdditive = additive;
		useAlpha = true;
		useTransforms = true;

		drawList = new DrawList();
	}

	public function render(?elapsed:Int)
	{
		#if (openfl >= "4.0.0")
		// TODO: Smarter solution that does not require clearing all tiles each render
		tilemap.removeTiles();
		#end
		drawList.begin(elapsed == null ? 0 : elapsed, useTransforms, useAlpha, useTint, useAdditive);
		renderGroup(this, 0);
		drawList.end();
		#if flash
		view.addChild(container);
		#elseif (openfl < "4.0.0")
		view.graphics.clear();
		tilesheet.drawTiles(view.graphics, drawList.list, useSmoothing, drawList.flags);
		#end
		return drawList.elapsed;
	}

	// TODO: Pass down a matrix
	function renderGroup(group:TileGroup, index:Int, matrix:Matrix = null, r:Float = 0.0, g:Float = 0.0, b:Float = 0.0, a:Float = 1.0)
	{
		if (matrix == null) matrix = new Matrix();

		var list = drawList.list;
		var fields = drawList.fields;
		var offsetTransform = drawList.offsetTransform;
		var offsetRGB = drawList.offsetRGB;
		var offsetAlpha = drawList.offsetAlpha;
		var elapsed = drawList.elapsed;

		matrix.concat(group.matrix);

		#if flash
		group.container.x = m.tx + group.x;
		group.container.y = m.ty + group.y;
		var blend = useAdditive ? BlendMode.ADD : BlendMode.NORMAL;
		#else
		gx += group.x;
		gy += group.y;
		#end
		
		var n = group.numChildren;
		for(i in 0...n)
		{
			var child = group.children[i];
			if (child.animated) child.step(elapsed);

			#if (!flash && openfl < "4.0.0")
			if (!child.visible) continue;
			#end
			
			#if (flash || js || neko)
			var group:TileGroup = Std.is(child, TileGroup) ? cast child : null;
			#else
			var group:TileGroup = cast child;
			#end

			if (group != null) 
			{
				index = renderGroup(group, index, matrix, r, g, b, a);
			}
			else 
			{
				var sprite:TileSprite = cast child;

				#if flash
				if (sprite.parent.visible && sprite.visible && sprite.alpha > 0.0)
				{
					var m = sprite.bmp.transform.matrix;
					m.identity();
					if (sprite.offset != null) m.translate(-sprite.offset.x, -sprite.offset.y);
					m.concat(sprite.matrix);
					m.translate(sprite.x, sprite.y);
					sprite.bmp.transform.matrix = m;
					sprite.bmp.blendMode = blend;
					sprite.bmp.alpha = sprite.alpha;
					sprite.bmp.visible = true;
					// TODO apply tint
				}
				else sprite.bmp.visible = false;
				#elseif (openfl >= "4.0.0")
				if (sprite.parent.visible && sprite.visible && sprite.alpha > 0.0)
				{
					var m = sprite.t.matrix;
					m.identity();
					if (sprite.offset != null) m.translate(-sprite.offset.x, -sprite.offset.y);
					m.concat(sprite.matrix);
					m.concat(matrix);
					sprite.t.matrix = m;
					//sprite.bmp.blendMode = blend;
					sprite.t.alpha = sprite.alpha;
					sprite.t.visible = true;
					sprite.t.id = sprite.indice;
					// TODO apply tint
					// TODO: Smarter solution that does not require re-adding tiles to tilemap
					tilemap.addTile(sprite.t);
				}
				else sprite.t.visible = false;
				#else
				if (sprite.alpha <= 0.0) continue;
				list[index+2] = sprite.indice;
				
				if (sprite.offset != null) 
				{
					var off:Point = sprite.offset;
					if (offsetTransform > 0) {
						var t = sprite.transform;
						list[index] = sprite.x - off.x * t[0] - off.y * t[1] + gx;
						list[index+1] = sprite.y - off.x * t[2] - off.y * t[3] + gy;
						list[index+offsetTransform] = t[0];
						list[index+offsetTransform+1] = t[2];
						list[index+offsetTransform+2] = t[1];
						list[index+offsetTransform+3] = t[3];
					}
					else {
						list[index] = sprite.x - off.x + gx;
						list[index+1] = sprite.y - off.y + gy;
					}
				}
				else {
					list[index] = sprite.x + gx;
					list[index+1] = sprite.y + gy;
					if (offsetTransform > 0) {
						var t = sprite.transform;
						list[index+offsetTransform] = t[0];
						list[index+offsetTransform+1] = t[2];
						list[index+offsetTransform+2] = t[1];
						list[index+offsetTransform+3] = t[3];
					}
				}
				
				if (offsetRGB > 0) {
					list[index+offsetRGB] = sprite.r;
					list[index+offsetRGB+1] = sprite.g;
					list[index+offsetRGB+2] = sprite.b;
				}
				if (offsetAlpha > 0) list[index+offsetAlpha] = sprite.alpha;
				index += fields;
				#end
			}
		}
		drawList.index = index;
		return index;
	}
}


/**
 * @private base tile type
 */
class TileBase
{
	public var layer:TileLayer;
	public var parent:TileGroup;
	public var x:Float;
	public var y:Float;
	public var animated:Bool;
	public var visible:Bool;

	var dirty:Bool;
	var _rotation:Float;
	var _scaleX:Float;
	var _scaleY:Float;
	var _mirror:Int;

	public var alpha:Float;
	public var r:Float;
	public var g:Float;
	public var b:Float;

	#if (!flash && openfl >= "4.0.0")
	var _matrix:Matrix;
	#elseif !flash
	var _transform:Array<Float>;
	#else
	var _matrix:Matrix;
	#end

	public function new(layer:TileLayer)
	{
		this.layer = layer;
		x = y = 0.0;
		visible = true;

		_rotation = 0;
		alpha = _scaleX = _scaleY = 1;
		_mirror = 0;

		#if flash
		_matrix = new Matrix();
		#elseif (openfl >= "4.0.0")
		_matrix = new Matrix();
		#else
		_transform = new Array<Float>();
		#end
		dirty = true;
	}

	public function init(layer:TileLayer):Void
	{
		this.layer = layer;
	}

	public function step(elapsed:Int)
	{
	}

	public var mirror(get_mirror, set_mirror):Int;
	inline function get_mirror():Int { return _mirror; }
	function set_mirror(value:Int):Int 
	{
		if (_mirror != value) {
			_mirror = value;
			dirty = true;
		}
		return value;
	}

	public var rotation(get_rotation, set_rotation):Float;	
	inline function get_rotation():Float { return _rotation; }
	function set_rotation(value:Float):Float 
	{
		if (_rotation != value) {
			_rotation = value;
			dirty = true;
		}
		return value;
	}

	public var scale(get_scale, set_scale):Float;
	inline function get_scale():Float { return _scaleX; }
	function set_scale(value:Float):Float 
	{
		if (_scaleX != value) {
			_scaleX = value;
			_scaleY = value;
			dirty = true;
		}
		return value;
	}

	public var scaleX(get_scaleX, set_scaleX):Float;
	inline function get_scaleX():Float { return _scaleX; }
	function set_scaleX(value:Float):Float 
	{
		if (_scaleX != value) {
			_scaleX = value;
			dirty = true;
		}
		return value;
	}

	public var scaleY(get_scaleY, set_scaleY):Float;
	inline function get_scaleY():Float { return _scaleY; }
	function set_scaleY(value:Float):Float 
	{
		if (_scaleY != value) {
			_scaleY = value;
			dirty = true;
		}
		return value;
	}

	public var color(get_color, set_color):Int;
	function get_color():Int 
	{ 
		return Std.int(r * 256.0) << 16
			+ Std.int(g * 256.0) << 8
			+ Std.int(b * 256.0);
	}
	function set_color(value:Int):Int 
	{
		r = (value >> 16) / 255.0;
		g = ((value >> 8) & 0xff) / 255.0;
		b = (value & 0xff) / 255.0;
		return value;
	}

	#if (!flash && openfl < "4.0.0")
	public var transform(get_transform, null):Array<Float>;
	function get_transform():Array<Float>
	{
		if (dirty == true) 
		{
			dirty = false;
			var dirX:Int = mirror == 1 ? -1 : 1;
			var dirY:Int = mirror == 2 ? -1 : 1;
			var sx:Float = scaleX * layer.tilesheet.scale;
			var sy:Float = scaleY * layer.tilesheet.scale;
			if (rotation != 0) {
				var cos = Math.cos(rotation);
				var sin = Math.sin(rotation);
				_transform[0] = dirX * cos * sx;
				_transform[1] = -dirY * sin * sy;
				_transform[2] = dirX * sin * sx;
				_transform[3] = dirY * cos * sy;
			}
			else {
				_transform[0] = dirX * sx;
				_transform[1] = 0;
				_transform[2] = 0;
				_transform[3] = dirY * sy;
			}
		}
		return _transform;
	}

	#else
	public var matrix(get_matrix, null):Matrix;
	function get_matrix():Matrix 
	{ 
		if (dirty == true)
		{
			dirty = false;
			var tileWidth = width / 2;
			var tileHeight = height / 2;
			var m = _matrix;
			m.identity();
			if (layer.useTransforms) {
				m.scale(scaleX * layer.tilesheet.scale, scaleY * layer.tilesheet.scale);
				if (mirror != 0) {
					if (mirror == 1) { m.scale(-1, 1); m.translate(tileWidth * 2, 0); }
					else if (mirror == 2) { m.scale(1, -1); m.translate(0, tileHeight * 2); }
				}
				if (rotation != 0) {
					m.translate(-tileWidth, -tileHeight);
					m.rotate(rotation);
					m.translate(tileWidth, tileHeight);
				}
			}
			m.translate(-tileWidth, -tileHeight);
		}
		return _matrix;
	}
	#end

	#if flash
	public function getView():DisplayObject { return null; }
	#end
}


/**
 * @private render buffer
 */
private class DrawList
{
	public var list:Array<Float>;
	public var index:Int;
	public var fields:Int;
	public var offsetTransform:Int;
	public var offsetRGB:Int;
	public var offsetAlpha:Int;
	public var flags:Int;
	public var time:Int;
	public var elapsed:Int;
	public var runs:Int;

	public function new() 
	{
		list = new Array<Float>();
		elapsed = 0;
		runs = 0;
	}

	public function begin(elapsed:Int, useTransforms:Bool, useAlpha:Bool, useTint:Bool, useAdditive:Bool) 
	{
		#if (!flash && openfl < "4.0.0")
		flags = 0;
		fields = 3;
		if (useTransforms) {
			offsetTransform = fields;
			fields += 4;
			flags |= Graphics.TILE_TRANS_2x2;
		}
		else offsetTransform = 0;
		if (useTint) {
			offsetRGB = fields; 
			fields+=3; 
			flags |= Graphics.TILE_RGB;
		}
		else offsetRGB = 0;
		if (useAlpha) {
			offsetAlpha = fields; 
			fields++; 
			flags |= Graphics.TILE_ALPHA;
		}
		else offsetAlpha = 0;
		if (useAdditive) flags |= Graphics.TILE_BLEND_ADD;
		#end

		if (elapsed > 0) this.elapsed = elapsed;
		else
		{
			index = 0;
			if (time > 0) {
				var t = Lib.getTimer();
				this.elapsed = cast Math.min(67, t - time);
				time = t;
			}
			else time = Lib.getTimer();
		}
	}

	public function end()
	{
		if (list.length > index) 
		{
			if (++runs > 60) 
			{
				list.splice(index, list.length - index); // compact buffer
				runs = 0;
			}
			else
			{
				while (index < list.length)
				{
					list[index + 2] = -2.0; // set invalid ID
					index += fields;
				}
			}
		}
	}
}
