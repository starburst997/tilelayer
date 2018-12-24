package aze.display;

import aze.display.TileLayer;

import openfl.geom.Matrix;
import openfl.display.Bitmap;
import openfl.display.DisplayObject;
#if (openfl >= "4.0.0")
import openfl.display.Tile;
#end
import openfl.geom.Point;
import openfl.geom.Rectangle;

/**
 * Static tile for TileLayer
 * @author Philippe / http://philippe.elsass.me
 */
class TileSprite extends TileBase
{
	var _tile:String;
	var _indice:Int;
	var size:Rectangle;

	var _offset:Point;

	#if (!flash && openfl >= "4.0.0")
	public var t:Tile;
	#elseif flash
	public var bmp:Bitmap;
	#end

	public function new(layer:TileLayer, tile:String) 
	{
		super(layer);
		
		_indice = -1;
		#if flash
		bmp = new Bitmap();
		#elseif (openfl >= "4.0.0")
		t = new Tile();
		#end
		this.tile = tile;
	}

	override public function init(layer:TileLayer):Void
	{
		this.layer = layer;
		indice = layer.tilesheet.getIndex(tile);
		size = layer.tilesheet.getSize(indice);
	}

	#if flash
	override public function getView():DisplayObject { return bmp; }
	#end

	public var tile(get_tile, set_tile):String;
	inline function get_tile():String { return _tile; }
	function set_tile(value:String):String
	{
		if (_tile != value) {
			_tile = value;
			if (layer != null) init(layer); // update visual
		}
		return value;
	}

	public var indice(get_indice, set_indice):Int;
	inline function get_indice():Int { return _indice; }
	function set_indice(value:Int)
	{
		if (_indice != value)
		{
			_indice = value;
			#if flash
			bmp.bitmapData = layer.tilesheet.getBitmap(value);
			bmp.smoothing = layer.useSmoothing;
			#end
		}
		return value;
	}

	public var height(get_height, null):Float;
	inline function get_height():Float {
		return size.height * _scaleY;
	}

	public var width(get_width, null):Float;
	inline function get_width():Float {
		return size.width * _scaleX;
	}

	public var offset(get_offset, set_offset):Point;
	inline function get_offset():Point { return _offset; }
	function set_offset(value:Point):Point
	{
		if (value == null) _offset = null;
		else _offset = new Point(value.x / layer.tilesheet.scale, value.y / layer.tilesheet.scale);
		return _offset;
	}
}
