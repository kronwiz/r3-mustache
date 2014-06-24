REBOL []

mustache: import %../src/mustache.reb

print "*** First template ***"
tpl: to string! read %./template.tpl

ctxt: [ "thing" "This is a {{field}} in a row." ]
view: [
	"name" "Chris"
	"just won" "just won"
	"value" 10000
	"taxed_value" 6000
	;"in_ca" true
	"in_ca" [
		[ "taxed_value" 6000 ]
		[ "taxed_value" 7000 ]
		[ "taxed_value" 8000 ]
	]
	"field" "field!"
]

mustache/render/stream tpl view ctxt

print "^/*** Test escape ***"
tpl: to string! read %./test_escape.tpl
view: [
	"name" "Chris"
	"company" "<b>GitHub</b>"
]
;print mold mustache/parse-template "__main__" tpl [] []
mustache/render/stream tpl view []

print "^/*** Test section false value ***"
tpl: to string! read %./test_section_false_value.tpl
view: reduce [
	"person" false
]
;print mold mustache/parse-template "__main__" tpl [] []
mustache/render/stream tpl view []

print "^/*** Test section non empty list ***"
tpl: to string! read %./test_section_non_empty_list.tpl
view: [
  "repo" [
    [ "name" "resque" ]
    [ "name" "hub" ]
    [ "name" "rip" ]
  ]
]

;print mold mustache/parse-template "__main__" tpl [] []
mustache/render/stream tpl view []

print "^/*** Test section non false value ***"
tpl: to string! read %./test_section_non_false_value.tpl
view: [
  "person?" [ "name" "Jon" ]
]

;print mold mustache/parse-template "__main__" tpl [] []
mustache/render/stream tpl view []

print "^/*** Test inverted section ***"
tpl: to string! read %./test_section_inverted.tpl
view: [
	"repo" []
]
;print mold mustache/parse-template "__main__" tpl [] []
mustache/render/stream tpl view []

print "^/*** Test comment ***"
tpl: to string! read %./test_comment.tpl
view: [
	"repo" []
]
;print mold mustache/parse-template "__main__" tpl [] []
mustache/render/stream tpl view []

print "^/*** Test partial from file ***"
tpl: to string! read %./test_partial_from_file.tpl
ctxt: [
	"subtemplate" %./test_partial_from_file_subtemplate.tpl
]

view: [
	"row" [
		[ "number" 1 ]
		[ "number" 2 ]
		[ "number" 3 ]
		[ "number" 4 ]
	]
]
;print mold mustache/parse-template "__main__" tpl ctxt []
mustache/render/stream tpl view ctxt

