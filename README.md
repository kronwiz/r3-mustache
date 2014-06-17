#r3-mustache

Mustache templates renderer for Rebol 3

## Usage

    mustache: import %./mustache.reb

    tpl: to string! read %./template.tpl

    ctxt: [ "thing" "This is a {{field}} in a row." ]
    view: [
      "name" "Chris"
      "just won" "just won"
      "value" 10000
      "taxed_value" 6000
      "in_ca" true
      "field" "field!"
    ]

    mustache/render tpl view ctxt


## Templates

For the template syntax see the [official documentation](http://mustache.github.io/mustache.5.html).

## Examples

What follows are the examples extracted from the official documentation and adapted to Rebol syntax.

A typical Mustache template:

    Hello {{name}}
    You have just won {{value}} dollars!
    {{#in_ca}}
    Well, {{taxed_value}} dollars, after taxes.
    {{/in_ca}}

Given the following block:

    [
      "name" "Chris"
      "value" 10000
      "taxed_value" 6000
      "in_ca" true
    ]

Will produce the following:

    Hello Chris
    You have just won 10000 dollars!
    Well, 6000.0 dollars, after taxes.


### Variables

Template:

    * {{name}}
    * {{age}}
    * {{company}}
    * {{{company}}}

Block:

    [
      "name" "Chris",
      "company" "<b>GitHub</b>"
    ]

Output:

    * Chris
    *
    * &lt;b&gt;GitHub&lt;/b&gt;
    * <b>GitHub</b>


### Sections

**False Values or Empty Lists**

Template:

    Shown.
    {{#person}}
      Never shown!
    {{/person}}

Block:

    [
      "person" false
    ]

Output:

    Shown.

**Non-Empty Lists**

Template:

    {{#repo}}
      <b>{{name}}</b>
    {{/repo}}

Block:

    [
      "repo" [
        [ "name" "resque" ]
        [ "name" "hub" ]
        [ "name" "rip" ]
      ]
    ]

Output:

    <b>resque</b>
    <b>hub</b>
    <b>rip</b>

**Lambdas**

TO BE IMPLEMENTED

Template:

    {{#wrapped}}
      {{name}} is awesome.
    {{/wrapped}}

Block:

    [
      "name" "Willy"
      "wrapped" function [ text render ] [
        ajoin [ "<b>" render text "</b>" ]
      ]
    ]

Output:

    <b>Willy is awesome.</b>

**Non-False Values**

TO BE IMPLEMENTED. By now you can replace non-false values with non-empty list.

Template:

    {{#person?}}
      Hi {{name}}!
    {{/person?}}

Block:

    [
      "person?" [ "name" "Jon" ]
    ]

Output:

    Hi Jon!


### Inverted Sections

Template:

    {{#repo}}
      <b>{{name}}</b>
    {{/repo}}
    {{^repo}}
      No repos :(
    {{/repo}}

Block:

    [
      "repo" []
    ]

Output:

    No repos :(


### Partials

Partials must be contained in the context block passed as a parameter to the `render` function.


## License

This library is copyright by Andrea Galimberti. This library is under the GNU LESSER GENERAL PUBLIC LICENSE Version 3. For more information about using/distributing the library see the `LICENSE` file or go to http://www.gnu.org/copyleft/lesser.html.

The above copyright notice, the licence and the following disclaimer shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES, EXPRESSED OR IMPLIED, WITH REGARD TO THIS SOFTWARE INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

