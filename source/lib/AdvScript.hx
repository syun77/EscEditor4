package lib;

import flixel.FlxG;
import openfl.Assets;

/**
 * ADVゲーム用スクリプト
 **/
class AdvScript {

  // ■定数
  public static inline var RET_CONTINUE:Int = 0;
  public static inline var RET_YIELD:Int    = 1;
  public static inline var RET_EXIT:Int     = 2;

  // 代入演算子
  public static inline var ASSIGN_NON:Int = 0x00;
  public static inline var ASSIGN_ADD:Int = 0x01;
  public static inline var ASSIGN_SUB:Int = 0x02;
  public static inline var ASSIGN_MUL:Int = 0x03;
  public static inline var ASSIGN_DIV:Int = 0x04;
  public static inline var ASSIGN_BIT:Int = 0x10;


  // 変数の最大数
  public static inline var MAX_VAR:Int = 16;

  // ■スタティック

  // ■公開変数
  // ・フラグ関連
  public var funcLengthBit:Void -> Int      = null; // フラグの最大数
  public var funcSetBit:Int -> Bool -> Void = null; // フラグの設定
  public var funcGetBit:Int -> Bool         = null; // フラグの取得
  // ・変数関連
  public var funcLengthVar:Void -> Int     = null; // 変数の最大数
  public var funcSetVar:Int -> Int -> Void = null; // 変数の設定
  public var funcGetVar:Int -> Int         = null; // 変数の取得

  // ■メンバ変数
  // スクリプトデータ
  var _data:Array<String>;
  // 実行カウンタ
  var _pc:Int;
  // 終了コードが見つかったかどうか
  var _bEnd:Bool;
  // システムコマンド定義
  var _sysTbl:Map<String,Array<String>->Void>;
  // ユーザコマンド定義
  var _userTbl:Map<String,Array<String>->Int>;
  // ログを出力するかどうか
  var _bLog:Bool = false;
  // フラグ
  var _bits:Array<Bool>;
  // 変数
  var _vars:Array<Int>;

  // 実行中の関数名
  var _funcName:String = null;
  // コールスタック
  var _callStack:Array<Int>;

  public function lengthBit():Int {
    if(funcLengthBit != null) {
      return funcLengthBit();
    }
    return _bits.length;
  }
  public function setBit(idx:Int, v:Int):Void {
    if(idx < 0 || lengthBit() <= idx) {
      // 範囲外
      throw 'Error: bit out of range %${idx}';
    }
    var b = (v != 0);
    if(funcSetBit != null) {
      funcSetBit(idx, b);
      return;
    }
    _bits[idx] = b;
  }
  public function getBit(idx:Int):Int {
    if(idx < 0 || lengthBit() <= idx) {
      // 範囲外
      throw 'Error: bit out of range %${idx}';
    }
    if(funcGetBit != null) {
      return funcGetBit(idx) ? 1 : 0;
    }
    return _bits[idx] ? 1 : 0;
  }
  public function lengthVar():Int {
    if(funcLengthVar != null) {
      return funcLengthVar();
    }
    return _vars.length;
  }
  public function setVar(idx:Int, v:Int):Void {
    if(idx < 0 || lengthVar() <= idx) {
      // 範囲外
      throw 'Error: var out of range $$${idx}';
    }
    if(funcSetVar != null) {
      funcSetVar(idx, v);
      return;
    }
    _vars[idx] = v;
  }
  public function getVar(idx:Int):Int {
    if(idx < 0 || lengthVar() <= idx) {
      // 範囲外
      throw 'Error: var out of range $$${idx}';
    }
    if(funcGetVar != null) {
      return funcGetVar(idx);
    }
    return _vars[idx];
  }

  // 変数スタック
  var _stack:List<Int>;
  public function popStack():Int {
    return _stack.pop();
  }
  public function pushStack(v:Int):Void {
    _stack.push(v);
  }
  public function pushStackBool(b:Bool):Void {
    _stack.push(if(b) 1 else 0);
  }

  /**
   * 指定の関数を探す
   * @param name 関数名
   * @return Bool 存在する場合は true
   */
  public function searchFunction(name:String):Bool {
    var addr = _searchFunction(name);
    return addr >= 0;
  }

  /**
   * 指定のアドレスにジャンプする
   * @param address アドレス番号
   */
  public function jumpAddress(address:Int):Void {
    _jump(address);
  }

  /**
   * 指定の関数名に直接ジャンプする
   */
  public function jumpFunction(name:String):Bool {
    var addr = _searchFunction(name);
    if(addr < 0) {
      if(_bLog) {
        trace('[Error] Not find function: ${name}');
      }
      return false; // 見つからなかった
    }
    else {
      _jump(addr + 1); // "FUNC_START" の次のアドレスから開始
      return true;
    }
  }

  /**
   * コンストラクタ
   **/
  public function new(cmdTbl:Map<String,Array<String>->Int>, filepath:String=null) {
    if(filepath != null) {
      // 読み込み
      load(filepath);
    }

    // システムテーブル登録
    _sysTbl = [
      "BOOL"  => _BOOL,
      "INT"   => _INT,
      "SET"   => _SET,
      "ADD"   => _ADD,
      "SUB"   => _SUB,
      "MUL"   => _MUL,
      "DIV"   => _DIV,
      "NEG"   => _NEG,
      "BIT"   => _BIT,
      "VAR"   => _VAR,
      "EQ"    => _EQ,
      "NE"    => _NE,
      "LE"    => _LE,
      "LESS"  => _LESS,
      "GE"    => _GE,
      "AND"   => _AND,
      "OR"    => _OR,
      "NOT"   => _NOT,
      "GREATER" => _GREATER,
      "IF"    => _IF,
      "ELIF"  => _IF,
      "GOTO"  => _GOTO,
      "WHILE" => _WHILE,
      "RETURN" => _RETURN,
      "END"   => _END,
      "FUNC_START" => _FUNC_START,
      "FUNC_END"   => _FUNC_END,
    ];

    _userTbl = cmdTbl;
    _stack   = new List<Int>();
    _vars    = new Array<Int>();
    for(i in 0...MAX_VAR) {
      _vars.push(0);
    }

    _funcName = null;
    _callStack = new Array<Int>();
  }

  /**
   * 読み込み
   **/
  public function load(filepath):Void {
    var scr:String = Assets.getText(filepath);
    if(scr == null) {
      // 読み込み失敗
      FlxG.log.warn("AdvScript.load() scr is null. file:'" + filepath + "''");
      return;
    }

    // 変数初期化
    _data = scr.split("\n");
    _pc   = 0;
    _bEnd = false;
  }

  /**
   * ログを有効化するかどうか
   **/
  public function setLog(b:Bool):Void {
    _bLog = b;
  }

  /**
   * 実行カウンタを最初に戻す
   **/
  public function resetPc():Void {
    _pc = 0;
    _bEnd = false;
  }

  /**
   * 終了したかどうか
   **/
  public function isEnd():Bool {
    if(_bEnd) {
      return true;
    }
    return _pc >= _data.length;
  }

  /**
   * 更新
   **/
  public function update():Void {
    while(isEnd() == false) {
      var ret = _loop();
      if(ret == RET_YIELD) {
        // いったん抜ける
        break;
      }
      else if(ret == RET_EXIT) {
        // 強制終了する
        _bEnd = true;
        break;
      }
    }
  }

  /**
   * ループ
   **/
  private function _loop():Int {
    var line = _data[_pc];
    if(line == "") {
      // 空行
      _pc++;
      return RET_CONTINUE;
    }

    var d = line.split(",");
    _pc++;
    var cmd = d[0];
    var param = d.slice(1);

    var ret = RET_CONTINUE;

    if(_sysTbl.exists(cmd)) {
      // システム関数
      _sysTbl[cmd](param);
      ret = RET_CONTINUE;
    }
    else {
      if(_userTbl.exists(cmd) == false) {
        throw 'Error: Not found command = ${cmd}';
      }
      // ユーザー定義関数
      ret = _userTbl[cmd](param);
    }

    return ret;
  }

  /**
   * 指定の関数名を探す
   */
  private function _searchFunction(name:String):Int {
    for(i in 0..._data.length) {
      var line = _data[i];
      var d = line.split(",");
      var cmd = d[0];
      if(cmd != "FUNC_START") {
        continue;
      }
      var func = d[1];
      if(name == func) {
        return i+1; // 関数名を見つけた (スクリプト上のアドレスは+1)
      }
    }

    return -1; // 見つからなかった
  }

  private function _BOOL(param:Array<String>):Void {
    var p0 = Std.parseInt(param[0]) != 0;
    if(_bLog) {
      trace('[SCRIPT] BOOL ${p0}');
    }
    pushStack(p0 ? 1 : 0);
  }
  private function _INT(param:Array<String>):Void {
    var p0 = Std.parseInt(param[0]);
    if(_bLog) {
      trace('[SCRIPT] INT ${p0}');
    }
    pushStack(p0);
  }
  private function _SET(param:Array<String>):Void {
    var op  = Std.parseInt(param[0]);
    var idx = Std.parseInt(param[1]);
    var val = popStack();
    var result = 0;
    var isBit = (op == ASSIGN_BIT);
    if(isBit) {
      result = getBit(idx);     
    }
    else {
      result = getVar(idx); 
    }
    var log = "";
    switch(op) {
      case ASSIGN_NON:
        result = val;
        log = '$$${idx}=${val}';
      case ASSIGN_ADD:
        log = '$$${idx} ${result}+${val}=${result+val}';
        result += val;
      case ASSIGN_SUB:
        log = '$$${idx} ${result}-${val}=${result-val}';
        result -= val;
      case ASSIGN_MUL:
        log = '$$${idx} ${result}*${val}=${result*val}';
        result *= val;
      case ASSIGN_DIV:
        log = '$$${idx} ${result}/${val}=${Std.int(result/val)}';
        result = Std.int(result / val);
      case ASSIGN_BIT:
        result = val;
        log = '%${idx}=${result != 0}';
    }
    if(_bLog) {
      trace('[SCRIPT] SET ${log}');
    }

    if(isBit) {
      setBit(idx, result);
    }
    else {
      setVar(idx, result);
    }
  }

  private function _ADD(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] ADD ${left} + ${right} => push ${left+right}');
    }
    pushStack(left + right);
  }

  private function _SUB(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] SUB ${left} - ${right} => push ${left-right}');
    }
    pushStack(left - right);
  }

  private function _MUL(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] MUL ${left} * ${right} => push ${left*right}');
    }
    pushStack(left * right);
  }

  private function _DIV(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] DIV ${left} / ${right} => push ${Std.int(left/right)}');
    }
    pushStack(Std.int(left / right));
  }

  private function _NEG(param:Array<String>):Void {
    var val = popStack();
    if(_bLog) {
      trace('[SCRIPT] NEG ${val} => push ${-val}');
    }
    pushStack(-val);
  }

  private function _BIT(param:Array<String>):Void {
    var idx = Std.parseInt(param[0]);
    var bit = getBit(idx);
    pushStack(bit);
    if(_bLog) {
      trace('[SCRIPT] BIT %${idx} is ${bit != 0}');
    }
  }

  private function _VAR(param:Array<String>):Void {
    var idx = Std.parseInt(param[0]);
    var val = getVar(idx);
    pushStack(val);
    if(_bLog) {
      trace('[SCRIPT] VAR $$${idx} is ${val}');
    }
  }

  // '=='
  private function _EQ(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] EQ ${left} == ${right}');
    }
    pushStackBool(left == right);
  }

  // '!='
  private function _NE(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] NE ${left} != ${right}');
    }
    pushStackBool(left != right);
  }

  // '<'
  private function _LE(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] LE ${left} < ${right}');
    }
    pushStackBool(left < right);
  }
  // '<='
  private function _LESS(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] LESS ${left} < ${right}');
    }
    pushStackBool(left <= right);
  }
  // '>'
  private function _GE(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] GE ${left} > ${right}');
    }
    pushStackBool(left > right);
  }
  // '>='
  private function _GREATER(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] GREATER ${left} >= ${right}');
    }
    pushStackBool(left >= right);
  }
  // '&&'
  private function _AND(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] AND ${left} && ${right}');
    }
    pushStackBool(left != 0 && right != 0);
  }
  // '||'
  private function _OR(param:Array<String>):Void {
    var right = popStack();
    var left  = popStack();
    if(_bLog) {
      trace('[SCRIPT] OR ${left} || ${right}');
    }
    pushStackBool(left != 0 || right != 0);
  }

  // '!'
  private function _NOT(param:Array<String>):Void {
    var right = popStack();
    if(_bLog) {
      trace('[SCRIPT] NOT ${right}');
    }
    pushStackBool((right != 0) == false);
  }

  private function _IF(param:Array<String>):Void {
    var val = popStack();
    if(_bLog) {
      trace('[SCRIPT] IF ${val}');
    }
    if(val == 0) {
      // 演算結果が偽なのでアドレスジャンプ
      var address = Std.parseInt(param[0]);
      _jump(address);
    }
  }

  private function _GOTO(param:Array<String>):Void {
    var address = Std.parseInt(param[0]);
    if(_bLog) {
      trace('[SCRIPT] GOTO ${address}');
    }
    _jump(address);
  }

  private function _WHILE(param:Array<String>):Void {
    /*
    var val = popStack();
    if(_bLog) {
      trace('[SCRIPT] WHILE ${val}');
    }
    if(val == 0) {
      // 演算結果が偽なのでアドレスジャンプ
      var address = Std.parseInt(param[0]);
      _jump(address);
    }
    */
  }

  private function _jump(address:Int):Void {
    if(_bLog) {
      trace('[SCRIPT] JUMP now(${_pc}) -> next(${address})');
    }

    // アドレスは -1 した値
    _pc = address - 1;
  }

  private function _RETURN(param:Array<String>):Void {
    if(_bLog) {
      trace("[SCRIPT] RETURN");
      trace("- - - - - - - - - -");
    }
    // TODO: ひとまず終了とする
    _bEnd = true;
  }
  private function _END(param:Array<String>):Void {
    if(_bLog) {
      trace("[SCRIPT] END");
      trace("-------------------");
    }
    _bEnd = true;
  }

  private function _FUNC_START(param:Array<String>):Void {
    if(_bLog) {
      trace("[SCRIPT] FUNC_START");
    }
    _bEnd = true; // 通常は呼び出されないので終了する
  }

  private function _FUNC_END(param:Array<String>):Void {
    if(_bLog) {
      trace("[SCRIPT] FUNC_END");
    }
    if(_callStack.length == 0) {
      _bEnd = true; // 直接呼び出しの場合は終了する
    }
    else {
      var addr = _callStack.pop(); // コールスタックがある場合は復帰する
      _pc = addr /*+ 1*/; // 呼び出しの次のアドレス
    }
  }

}
