REBOL []

mustache: import %../src/mustache.reb

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

;pt: mustache/parse-template "__main__" tpl ctxt []
;print mold pt

mustache/render tpl view ctxt

