#
#
#           nph
#        (c) Copyright 2023 Jacek Sieka
#           The Nim compiler
#        (c) Copyright 2018 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# * yaml formatting for the nph-specific fields

import
  "."/[phast, phlexer, phlineinfos, phoptions, phmsgs],
  "$nim"/compiler/[rodutils],
  std/[intsets, strutils]

proc addYamlString*(res: var string, s: string) =
  # We have to split long strings into many ropes. Otherwise
  # this could trigger InternalError(111). See the ropes module for
  # further information.
  res.add "\""
  for c in s:
    case c
    of '\0' .. '\x1F', '\x7F' .. '\xFF':
      res.add("\\u" & strutils.toHex(ord(c), 4))
    of '\"', '\\':
      res.add '\\' & c
    else:
      res.add c

  res.add('\"')

proc makeYamlString(s: string): string =
  result.addYamlString(s)

proc lineInfoToStr(conf: ConfigRef, info: TLineInfo): string =
  result.add "["
  result.addYamlString(toFilename(conf, info))
  result.addf ", $1, $2]", [toLinenumber(info), toColumn(info)]

proc treeToYamlAux(
    res: var string,
    conf: ConfigRef,
    n: PNode,
    marker: var IntSet,
    indent: int,
    maxRecDepth: int,
) =
  if n == nil:
    res.add("null")
  else:
    var istr = spaces(indent * 4)
    res.addf("kind: $1" % [makeYamlString($n.kind)])
    if maxRecDepth != 0:
      if conf != nil:
        res.addf("\n$1info: $2", [istr, lineInfoToStr(conf, n.info)])

      if n.prefix.len > 0:
        res.addf("\n$1prefix:", [istr])
        for i in 0 ..< n.prefix.len:
          res.addf("\n$1  - $2", [istr, makeYamlString($(n.prefix[i]))])

      if n.mid.len > 0:
        res.addf("\n$1mid:", [istr])
        for i in 0 ..< n.mid.len:
          res.addf("\n$1  - $2", [istr, makeYamlString($(n.mid[i]))])

      case n.kind
      of nkCharLit .. nkUInt64Lit:
        res.addf("\n$1intVal: $2", [istr, $(n.intVal)])
      of nkFloatLit .. nkFloat128Lit:
        res.addf("\n$1floatVal: $2", [istr, n.floatVal.toStrMaxPrecision])
      of nkStrLit .. nkTripleStrLit:
        res.addf("\n$1strVal: $2", [istr, makeYamlString(n.strVal)])
      of nkIdent:
        if n.ident != nil:
          res.addf("\n$1ident: $2", [istr, makeYamlString(n.ident.s)])
        else:
          res.addf("\n$1ident: null", [istr])
      of nkCommentStmt:
        res.addf("\n$1\"comment\": $2", [istr, makeYamlString(n.strVal)])
      else:
        if n.len > 0:
          res.addf("\n$1sons:", [istr])
          for i in 0 ..< n.len:
            res.addf("\n$1  - ", [istr])
            res.treeToYamlAux(conf, n[i], marker, indent + 1, maxRecDepth - 1)

      if n.postfix.len > 0:
        res.addf("\n$1postfix:", [istr])
        for i in 0 ..< n.postfix.len:
          res.addf("\n$1  - $2", [istr, makeYamlString($n.postfix[i])])

proc treeToYaml*(
    conf: ConfigRef, n: PNode, indent: int = 0, maxRecDepth: int = -1
): string =
  var marker = initIntSet()
  result.treeToYamlAux(conf, n, marker, indent, maxRecDepth)
