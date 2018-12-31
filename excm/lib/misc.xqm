xquery version "3.0";
(: --------------------------------------
   EXCM - Miscellaneous utilities module

   Miscellaneaous functions

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   October 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace misc = "http://oppidoc.com/ns/miscellaneous";

import module namespace globals = "http://oppidoc.com/ns/globals" at "globals.xqm";

(: ======================================================================
   Return key property value in module or empty sequence
   TODO: could be moved to a configuration.xqm module in the future
   ====================================================================== 
:)
declare function misc:get-property( $module as xs:string, $key as xs:string ) as xs:string? {
  globals:doc('settings')/Settings/Module[Name eq $module]/Property[Key eq $key]/Value
};

(: ======================================================================
   Return key property value in module or default value
   TODO: see above
   ====================================================================== 
:)
declare function misc:get-property( $module as xs:string, $key as xs:string, $default as xs:string ) as xs:string? {
  fn:head((globals:doc('settings')/Settings/Module[Name eq $module]/Property[Key eq $key]/Value, $default))
};

(: ======================================================================
   Return true if key property is value in module, false otherwise
   Module properties are defined in settings.xml configuration
   TODO: see above
   ====================================================================== 
:)
declare function misc:assert-property( $module as xs:string, $key as xs:string, $value as xs:string* ) as xs:boolean {
  let $prop := globals:doc('settings')/Settings/Module[Name eq $module]/Property[Key eq $key]/Value
  return 
    exists($prop) and ($prop = $value)
};

(: ======================================================================
   Log an error string depending on settings.xml configuration
   TODO: support alternative console logging ?
   ====================================================================== 
:)
declare function misc:log-error( $msg as item()* ) {
  if (misc:assert-property('logging', 'output', 'log4j')) then
    util:log-app('error', 'excm.app', $msg)
  else
    ()
};

(: ======================================================================
   Log a debug message depending on settings.xml configuration
   TODO: support alternative console logging ?
   ====================================================================== 
:)
declare function misc:log-debug( $msg as item()* ) {
  if (misc:assert-property('logging', 'output', 'log4j')) then
    util:log-app('debug', 'excm.app', $msg)
  else
    ()
};

(: ======================================================================
   Return node set containing only nodes in node set with textual
   content (note: attribute is not enough to qualify node for inclusion)
   ====================================================================== 
:)
declare function misc:prune( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element()
        return
          if ($node/@_Prune eq 'none') then
            element { local-name($node) } { $node/attribute()[local-name(.) ne '_Prune'], $node/node() }
          else if (empty($node/*) and normalize-space($node) ne '') then (: LEAF node with text content :)
            $node
          else if (some $n in $node//* satisfies normalize-space($n) ne '') then
            let $tag := local-name($node)
            return
              element { $tag }
                { $node/attribute(), misc:prune($node/node()) }
          else
            ()
      default
        return $node
};
