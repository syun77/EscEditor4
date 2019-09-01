#! /usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import re
import glob
import json

def usage():
	print("Usage: _convCdbHeader.py [dat.cdb]")

class Writer:
	def __init__(self):
		self.buf = ""
	def write(self, line, tab=0):
		for i in range(tab):
			self.buf += "  "
		self.buf += "%s\n"%line
	def writeKeyValue(self, key, value, comment, tab=0):
		self.write("%s: %s # %s"%(key, value, comment), tab)

def execute(cdb, root):
	f = open(cdb)
	jsonStr = f.read()
	f.close()
	jsonDict = json.loads(jsonStr)
	writer = Writer()
	# 注意書き
	writer.write("############################")
	writer.write("# Generated by '%s'"%os.path.basename(cdb))
	writer.write("# Waring: READ-ONLY")
	writer.write("############################")
	# ■汎用定数
	writer.write("const:")
	for dat in jsonDict["sheets"]:
		# シーン定数を出力
		if dat["name"] == "scenes":
			writer.write("# シーン", 1)
			for line in dat["lines"]:
				writer.writeKeyValue(line["id"], line["value"], line["name"], 1)
			writer.write("", 1)
		# アイテム定数を出力
		if dat["name"] == "items":
			writer.write("# アイテム", 1)
			for line in dat["lines"]:
				writer.writeKeyValue(line["id"], line["value"], line["name"], 1)
			writer.write("", 1)
	# ■フラグ定数
	writer.write("flag:")
	for dat in jsonDict["sheets"]:
		if dat["name"] == "flags":
			for line in dat["lines"]:
				comment = ""
				if "comment" in line:
					comment = line["comment"] # コメントは存在する場合のみ取得
				writer.writeKeyValue(line["id"], line["value"], comment, 1)
	
	path = root + "/common/cdb_header.txt"
	fOut = open(path, "w")
	fOut.write(writer.buf)
	fOut.close()
	
	print("************************")
	print("output: item_header.txt")
	print("************************")

def main(cdb):
	# ルートディレクトリ取得
	root = os.path.dirname(os.path.abspath(__file__))
	execute(cdb, root)

if __name__ == '__main__':
	args = sys.argv
	argc = len(sys.argv)
	if argc < 2:
		# 引数が足りない
		print(args)
		print("Error: Not enough parameter. given=%d require=%d"%(argc, 2))
		usage()
		quit()

	# アイテム.cdb
	cdb = args[1]

	main(cdb)
