REBOL [
	Title: "Mustache templates parser and renderer"
	Author: "Andrea Galimberti"
	Rights: http://www.gnu.org/copyleft/lesser.html
	Home: http://github.com/kronwiz/r3-mustache
]


; symbols found in a template

openbrace: #"^(7B)"     ; {
pound: #"#"
slash: #"/"
caret: #"^(5E)"         ; ^
bang: #"!"
greaterthan: #">"
equal: #"="
ampersand: #"&"
tagstart: "^(7B)^(7B)"  ; {{
tagend: "^(7D)^(7D)"    ; }}


; the atomic unit used to represent a piece of the structure obtained by
; parsing a template

tplchunk: make object! [
	name: none     ; tag name if type is 'tag, otherwise none
	type: none     ; chunk type
	tagtype: none  ; tag type if type is 'tag, otherwise none
	startpos: 0    ; starting position in template
	endpos: 0      ; ending position in template
	children: []   ; list of section children nodes
]


parse-template: function [
	{Parses a template and returns a block containing a representation of the template and its partials}
	name [ string! ]      "template name"
	template [ string! ]  "template string"
	ctxt [ block! ]       "context containing the partial templates"
	partials [ block! ]   "a block which the parsed template is appended to"
] [

	chunklist: copy []
	append partials reduce [ name chunklist ]
	last-tag-end: 0
	tagname: none
	parent-stack: copy []
	parent: chunklist

	parse template [
		some [
			; tag start
			to tagstart currpos: (
				currpos: index? currpos
				; in this case there's some text between the last tag
				; and the current tag
				if ( currpos - last-tag-end ) > 1 [
					currchunk: make tplchunk [
						type: 'text
						startpos: last-tag-end + 1
						endpos: currpos - 1
					]
					append parent currchunk
				]
	
				; then begin processing the tag
				currchunk: make tplchunk [
					type: 'tag
					startpos: currpos + 2
				]
				append parent currchunk
			)
			tagstart

			; tag name
			copy tagname to tagend (
				currchunk/tagtype: switch/default first tagname reduce [
					openbrace [ 'unescapedb ]
					ampersand [ 'unescaped ]
					pound [ 'section ]
					slash [ 'endsection ]
					caret [ 'invsection ]
					bang [ 'comment ]
					greaterthan [ 'partial ]
					equal [ 'setdelimiter ]
				] [
					'value
				]

				currchunk/name: either currchunk/tagtype <> 'value [
					next tagname
				] [
					tagname
				]

				switch currchunk/tagtype [
					; if we're opening a section next chunks go as children of the
					; new section
					section [
						append/only parent-stack parent
						parent: currchunk/children
					]

					; the same for inverted sections
					invsection [
						append/only parent-stack parent
						parent: currchunk/children
					]

					; if we're closing a section we have to pop the last parent
					; from the stack to end adding children to the section and go up
					; one level.
					; The endsection chunk also is moved up one level: it mustn't be
					; a child of its own section.
					endsection [
						take/last parent ; remove the endsection chunk from the section
						parent: take/last parent-stack ; move up one level in the stack
						append parent currchunk ; add the endsection chunk in the parent level
					]

					partial [
						tpl: select ctxt currchunk/name
						if tpl <> none [ parse-template currchunk/name tpl ctxt partials ]
					]
				]
			)

			; tag end
			tagend currpos: (
				currpos: index? currpos
				currchunk/endpos: currpos - 3
				last-tag-end: currpos - 1
				if currchunk/tagtype = 'unescapedb [ last-tag-end: currpos ]
			)
		]
	]

	if last-tag-end < length? template [
		currchunk: make tplchunk [
			type: 'text
			startpos: last-tag-end + 1
			endpos: length? template
		]
		append parent currchunk
	]

	return partials
]


get-value-from-stack-recursive: function [
	{Returns the value of the key "name" checking recursively the stack "view-stack".
This function represents one iteration and mustn't be called directly.}
	view-stack [ block! ]  "series of blocks containing name-value pairs positioned at the correct level"
	name [ string! ]  "name of the key to check for"
] [

	;print [ "**** name:" name ]
	;print mold view-stack

	view: first view-stack
	value: select view name

	;print [ "** view:" mold view ]

	if value = none [
		if not head? view-stack [
			return get-value-from-stack-recursive back view-stack name
		]
	]

	value
]


get-value-from-stack: function [
	{Returns the value of the key "name" checking recursively the stack "view-stack"}
	view-stack [ block! ]  "series of blocks containing name-value pairs"
	name [ string! ]  "name of the key to check for"
] [

	get-value-from-stack-recursive back tail view-stack name
]


render-recursive: function [
	{Renders a template or part thereof (section, partial).
This function represents one iteration in the rendering process and mustn't be called directly.}
	template [ string! ]  "string buffer containing the mustache template or partial in its orignal form"
	parsed-template [ block! ]  "structure representing the template after parsing"
	view-stack [ block! ]  "stack of view blocks"
	ctxt [ block! ]  "hash-type block with partial templates identified by names"
	parsed-templates-list [ block! ]  "hash-type block with the structures of partials after parsing"
] [

	forall parsed-template [
		chunk: first parsed-template

		switch chunk/type [
			text [
				prin copy/part at template chunk/startpos ( chunk/endpos - chunk/startpos + 1 )
			]

			tag [
				switch chunk/tagtype [
					value [
						value: get-value-from-stack view-stack chunk/name
						; TODO: here we should escape HTML markers
						if value <> none [ prin value ]
					]

					unescaped [
						value: get-value-from-stack view-stack chunk/name
						if value <> none [ prin value ]
					]

					unescapedb [
						value: get-value-from-stack view-stack chunk/name
						if value <> none [ prin value ]
					]

					section [
						value: get-value-from-stack view-stack chunk/name
						if all [ value <> none value <> false ] [
							either not series? value [
								; the content of "value" is not false: its actual value doesn't
								; really matter. Nonetheless we have to add it to view-stack
								; because the endsection chunk is expecting a value to pop from
								; the stack.
								append/only view-stack reduce [ "__dummy__" value ]
								render-recursive template chunk/children view-stack ctxt parsed-templates-list
							] [
								; the content of "value" is a list of blocks. We put each block as the
								; last item in the view-stack, each time replacing the previous one, so
								; that the view-stack grows only by one item.
								forall value [
									either head? value [
										append/only view-stack first value
									] [
										change/only back tail view-stack first value
									]

									render-recursive template chunk/children view-stack ctxt parsed-templates-list
								]
							]
						]
					]

					invsection [
						value: get-value-from-stack view-stack chunk/name
						if any [ value = none value = false all [ series? a empty? a ] ] [
							append/only view-stack reduce [ "__dummy__" value ]
							render-recursive template chunk/children view-stack ctxt parsed-templates-list
						]
					]

					endsection [
						take/last view-stack
					]

					partial [
						ptpl: select parsed-templates-list chunk/name
						if ptpl <> none [
							tpl: select ctxt chunk/name
							render-recursive tpl ptpl view-stack ctxt parsed-templates-list
						]
					]
				]
			]
		]
	]
]


render: function [
	{Renders the template according to the values provided in "view"}
	template [ string! ]  "string buffer containing the mustache template"
	view [ block! ]  "hash-type block with values identified by names (keys)"
	ctxt [ block! ]  "hash-type block with partial templates identified by names"
] [

	view-stack: copy []
	append/only view-stack view

	parsed-templates: parse-template "__main__" template ctxt []

	ptpl: select parsed-templates "__main__"
	render-recursive template ptpl view-stack ctxt parsed-templates

	print ""
]

