package;

class Utils {
	/**
     * ０埋めした数値文字列を返す
     * @param	n 元の数値
     * @param	digit ゼロ埋めする桁数
     * @return  ゼロ埋めした文字列
     */
	public static function fillZero(n:Int, digit:Int):String {
		var str:String = "" + n;
		return StringTools.lpad(str, "0", digit);
	}
}