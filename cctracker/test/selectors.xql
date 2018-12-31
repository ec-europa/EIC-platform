(:declare default element namespace "http://www.w3.org/1999/xhtml";:)

declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xt = "http://ns.inria.org/xtiger";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare function local:gen-cell( $name as xs:string, $input as element() ) {
  <div class="row-fluid">
    <div class="span12">
     <div class="a-cell-label a-gap" style="width:200px; margin-left=0">
       <p class="a-cell-legend">{$name}</p>
     </div>
     <div class="a-cell-body" style="margin-left:225px">
      { $input }
      </div>
    </div>
  </div>
};

declare function local:gen-choices( $name as xs:string, $output as xs:string ) {
  <div class="row-fluid">
    <div class="span12">
     <div class="a-cell-label a-gap" style="width:200px; margin-left=0">
       <p class="a-cell-legend">{$name}</p>
     </div>
     <div class="a-cell-body" style="margin-left:225px">
      { $output }
      </div>
    </div>
  </div>
};

let $lang := 'en'
let $selectors := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[not(parent::Group)]
return
  <site:view>
    <site:content>
      <div xmlns="http://www.w3.org/1999/xhtml">
        <div class="row-fluid" style="margin-bottom: 2em">
          <h1>Case Tracker Selector Test</h1>
          <p>Use this page to control application selectors generated from Global Information</p>
        </div>
        <h2>Selection</h2>
        {
        for $s in $selectors
        order by string($s/@Test)
        return
          local:gen-cell(string($s/@Test), form:gen-selector-for(string($s/@Name), $lang, ";multiple=yes;xvalue=ValueRef;typeahead=yes"))
        }
        <h2>Serialization</h2>
        {
        for $s at $i in $selectors
        order by string($s/@Test)
        return
          let $txt := display:gen-name-for($s/@Name, $s//*[local-name(.) eq $s/@Value], $lang)
          return
            local:gen-choices(string($s/@Test), $txt)
        }
      </div>
    </site:content>
  </site:view>


