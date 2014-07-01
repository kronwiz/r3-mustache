REBOL [
	Title: "Mustache templates parser and renderer"
	Author: "Andrea Galimberti"
	Type: 'module
	Name: 'mustache
	Exports: [ render ]
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
						if tpl <> none [
							if file? tpl [ tpl: to string! read tpl ]
							parse-template currchunk/name tpl ctxt partials
						]
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

			; newline immediately following the tag
			any newline currpos: (
				; skip it if it's a section tag
				if find [ section invsection endsection partial ] currchunk/tagtype [
					last-tag-end: ( index? currpos ) - 1
				]
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

	view: first view-stack
	value: select view name

	if :value = none [
		if not head? view-stack [
			return get-value-from-stack-recursive back view-stack name
		]
	]

	; this must be a get-word because if "value" it's a function
	; it must not be evaluated
	:value
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
	dump-output [ function! ]  "function used to output each rendered chunk"
	res-buffer [ block! ]  "buffer to append each rendered chunk to. It's passed to the dump-output function"
] [

	forall parsed-template [
		chunk: first parsed-template

		switch chunk/type [
			text [
				dump-output res-buffer copy/part at template chunk/startpos ( chunk/endpos - chunk/startpos + 1 )
			]

			tag [
				switch chunk/tagtype [
					value [
						value: get-value-from-stack view-stack chunk/name
						if value <> none [
							if string? value [ value: sanitize value ]
							dump-output res-buffer value
						]
					]

					unescaped [
						value: get-value-from-stack view-stack chunk/name
						if value <> none [ dump-output res-buffer value ]
					]

					unescapedb [
						value: get-value-from-stack view-stack chunk/name
						if value <> none [ dump-output res-buffer value ]
					]

					section [
						value: get-value-from-stack view-stack chunk/name
						if all [ :value <> none :value <> false ] [
							either not block? :value [
								; the content of "value" is not false: its actual value doesn't
								; really matter. Nonetheless we have to add it to view-stack
								; because the endsection chunk is expecting a value to pop from
								; the stack.
								append/only view-stack reduce [ "__dummy__" :value ]

								either function? :value [
									c: first chunk/children
									tstart: c/startpos
									c: last chunk/children
									tend: c/endpos
									text: copy/part at template tstart ( tend - tstart + 1 )
									; the function in "value" is called with the unparsed section text,
									; the original view and context passed to the render call.
									dump-output res-buffer value text first view-stack ctxt
								] [
									res-buffer: render-recursive template chunk/children view-stack ctxt parsed-templates-list :dump-output res-buffer
								]
							] [
								; if value is not a list of blocks it's transformed to a list
								; with itself as the first and only block. This is done to be
								; compatible with the loop below.
								if all [ not empty? value not block? first value ] [
									value: reduce [ value ]
								]

								; the content of "value" is a list of blocks. We put each block as the
								; last item in the view-stack, each time replacing the previous one, so
								; that the view-stack grows only by one item.
								forall value [
									either head? value [
										append/only view-stack first value
									] [
										change/only back tail view-stack first value
									]

									res-buffer: render-recursive template chunk/children view-stack ctxt parsed-templates-list :dump-output res-buffer
								]
							]
						]
					]

					invsection [
						value: get-value-from-stack view-stack chunk/name
						if any [ value = none value = false all [ series? value empty? value ] ] [
							append/only view-stack reduce [ "__dummy__" value ]
							res-buffer: render-recursive template chunk/children view-stack ctxt parsed-templates-list :dump-output res-buffer
						]
					]

					endsection [
						take/last view-stack
					]

					partial [
						ptpl: select parsed-templates-list chunk/name
						if ptpl <> none [
							tpl: select ctxt chunk/name
							if file? tpl [ tpl: to string! read tpl ]
							res-buffer: render-recursive tpl ptpl view-stack ctxt parsed-templates-list :dump-output res-buffer
						]
					]
				]
			]
		]
	]

	res-buffer
]


get-output-func: function [
	{Returns a function that outputs the results of the rendering process}
	type [ word! ]  "Type of function to return"
] [
	switch/default type [
		stream [
			function [
				{This version immediately prints the value without adding it to a buffer}
				buffer [ block! ]  "Buffer to add the value to"
				value  "Value to be dumped"
			] [
				prin value
			]
		]
	] [
		; in the default case we use the function that appends the value to a buffer
		function [
			{This version adds the value to the buffer}
			buffer [ block! ]  "Buffer to add the value to"
			value  "Value to be added"
		] [
			append buffer value
		]
	]
]


render: function [
	{Renders the template according to the values provided in "view". Returns the result as a string.}
	template [ string! file! ]  "string buffer or file name containing the mustache template"
	view [ block! ]  "hash-type block with values identified by names (keys)"
	ctxt [ block! ]  "hash-type block with partial templates identified by names"
	/stream  "if specified the result is not retured, but it's printed to standard output during rendering"
] [

	if file? template [
		template: to string! read template
	]

	view-stack: copy []
	append/only view-stack view

	parsed-templates: parse-template "__main__" template ctxt copy []

	dump-output: get-output-func either stream [ 'stream ] [ 'buffer ]
	ptpl: select parsed-templates "__main__"
	ajoin render-recursive template ptpl view-stack ctxt parsed-templates :dump-output copy []
]


; =========================================================
; sanitize function
; extracted from RSP Preprocessor
; Author: "Christopher Ross-Gill"
; Source: http://reb4.me/r3/rsp
; Docs: http://www.ross-gill.com/page/RSP_Text_Preprocessor
; =========================================================

sanitize: use [ascii html* extended][
	html*: exclude ascii: charset ["^/^-" #"^(20)" - #"^(7E)"] charset {&<>"}
	extended: complement charset [#"^(00)" - #"^(7F)"]

	func [text [any-string!] /local char][
		parse/all form text [
			copy text any [
				text: some html*
				| change #"<" "&lt;" | change #">" "&gt;" | change #"&" "&amp;"
				| change #"^"" "&quot;" | remove #"^M"
				| remove copy char extended (char: rejoin ["&#" to integer! char/1 ";"]) insert char
				| remove copy char skip (char: rejoin ["#(" to integer! char/1 ")"]) insert char
			]
		]
		any [text copy ""]
	]
]

