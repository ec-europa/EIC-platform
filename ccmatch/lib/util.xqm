xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   Utilities

   September 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace misc = "http://oppidoc.com/ns/misc";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace display = "http://oppidoc.com/oppidum/display" at "display.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../oppidum/lib/compat.xqm";

(: ======================================================================
   Replace legacy content with new content if it exists otherwise
   inserts new content into parent and returns success message
   Note that if no new content is provided returns success w/o updating legacy content
   ======================================================================
:)
declare function misc:save-content-silent( $parent as element(), $legacy as element()?, $new as element()? ) as element()* {
  if ($new) then
    if ($legacy) then (
      update replace $legacy with $new
    ) else (
      update insert $new into $parent
    )
  else
    ()
};

(: ======================================================================
   Returns file extension from filename normalized to lower case
   FIXME: the request API does not allow to directly get file mime type,
   hence we try to deduce it from the file name
   ======================================================================
:)
declare function misc:get-extension( $filename as xs:string ) as xs:string
{
  let $fn := normalize-space($filename)
  let $unparsed-extension := lower-case((text:groups($fn, '\.(\w+)$'))[2])
  return
    replace($unparsed-extension, 'jpg', 'jpeg')
    (: special jpg handling for xdb:store to get correct mime-type :)
};

(: ======================================================================
   Checks extension is compatible with sequence of accepted extensions
   Returns an error string or empty
   TODO: localize error message
   ======================================================================
:)

declare function misc:check-extension( $extension as xs:string, $accept as xs:string* ) as xs:string?
{
  if (empty(fn:index-of($accept, $extension))) then
    concat('File format ', upper-case($extension), ' not supported, please upload only ',
      string-join($accept, ' or '), ' files')
  else
    ()
};

(: ======================================================================
   Deletes binary resources referenced by a resource element (like Photo 
   or CV-File) including alternative file. Does not delete the resource element.
   ====================================================================== 
:)
declare function misc:delete-resource ( $base-uri as xs:string, $col-name as xs:string, $resource as element()?, $alt as xs:string? ) {
  let $col-uri := concat($base-uri, '/', $col-name)
  return
    for $r in $resource
    let $file-ref := string($r)
    return
      if (xdb:collection-available($col-uri)) then (
        (: deletes resource binary file :)
        if (util:binary-doc-available(concat($col-uri, '/', $file-ref))) then
          xdb:remove($col-uri, $file-ref)
        else
          (),
        (: deletes resource alternate binary file such as 1-thumb.jpeg :)
        if (exists($alt)) then 
          let $alt-ref := concat(substring-before($file-ref, '.'), $alt, '.', substring-after($file-ref, '.'))
          return
            if (util:binary-doc-available(concat($col-uri, '/', $alt-ref))) then
              xdb:remove($col-uri, $alt-ref)
            else
              ()
        else 
          ()
        )
      else
        ()
};

(: ======================================================================
   Updates or creates an entry for a binary resource file inside a person's
   Resources record
   Clean up previous entry (including binary resource file) from database
   ======================================================================
:)
declare function misc:update-resource ( $col-uri as xs:string, $filename as xs:string, $name as xs:string, $person as element(), $alt as xs:string? ) {
  let $legacy := $person/Resources/*[local-name(.) eq $name]
  let $delete := string($legacy)
  return
    if ($legacy) then (
      update value $legacy with $filename,
      if ($legacy/@Date) then (: defensive :)
        update value $legacy/@Date with string(current-dateTime())
      else
        update insert attribute { 'Date' } { current-dateTime() } into $legacy,
      if (util:binary-doc-available(concat($col-uri, '/', $delete))) then (: cleanup previous binary file :)
        (
        xdb:remove($col-uri, $delete),
        if ($alt) then 
          let $more := replace($delete, '\.', concat($alt, '.'))
          return
            if (util:binary-doc-available(concat($col-uri, '/', $more))) then (: clean up alternative file, e.g -thumb image file :)
              xdb:remove($col-uri, $more)
            else
              ()
        else
          ()
        )
      else
        ()
      )
    else
      let $resources := $person/Resources
      let $entry := element { $name } { attribute { 'Date' } { current-dateTime() }, $filename }
      return
        if ($resources) then
          update insert $entry into $resources
        else
          update insert <Resources>{ $entry }</Resources> into $person
};

(: ======================================================================
   Streams binary file or returns a 404
   Returns very long duration Cache-Control header
   The cache-scope should indicate public or private depending if 
   the resource can be cached by proxy servers or not
   ======================================================================
:)
declare function misc:get-binary-file( $file-uri as xs:string, $mime as xs:string, $cache-scope as xs:string? ) {
  if (util:binary-doc-available($file-uri)) then
    let $file := util:binary-doc($file-uri)
    return (
      if ($cache-scope) then (
        response:set-header('Pragma', 'x'),
        (: to prevent Pragme: no-cache header :)
        response:set-header('Cache-Control', concat($cache-scope, ', max-age=900000'))
        )
      else
        (),
      response:stream-binary($file, $mime)
    )
  else
    ( "Erreur 404 (no file)", response:set-status-code(404) )
};

(: ======================================================================
   Returns current counter variable value and increment it for next time
   Lazy creation of counter variable set to 1 if it does not exists
   Pre-condition: Variables element in global information collection
   ======================================================================
:)
declare function misc:increment-variable( $name as xs:string ) as xs:string {
  let $var := fn:collection($globals:global-info-uri)/Variables/Variable[Name = $name]
  let $value := $var/Value
  let $cur := if ($value castable as xs:integer) then xs:integer($value) else ()
  return
    if (not(empty($cur))) then (
      update value $value with ($cur + 1),
      string($cur)
      )
    else (: lazy creation - for minimal installation :)
      let $start := 1
      let $seed := <Variable><Name>{ $name }</Name><Value>{ $start + 1 }</Value></Variable>
      return (
        if (empty($var)) then
          update insert $seed into fn:collection($globals:global-info-uri)/Variables
        else if ($value) then (: non numerical initial value - should never happen ? :)
          update value $value with ($start + 1)
        else
          update insert $seed/Value into $var,
        string($start)
        )
};

(: ======================================================================
   Basic collection name sharding algorithm for resources identified
   with a numerical index. Returns a 4 digits collection name starting
   at 0000 where to store the resource
   ======================================================================
:)
declare function misc:gen-collection-name-for ( $i as xs:double ) as xs:string {
  let $bucket := ($i mod 10000) idiv 50
  return
    concat(
       string-join((for $i in 1 to (4 - string-length(string($bucket))) return '0'),
                   ''),
       $bucket
       )
};

(: ======================================================================
   Creates the $path hierarchy of collections directly below the $base-uri collection.
   The $path is a relative path not starting with '/'
   The $base-uri collection MUST be available.
   Returns the database URI to the terminal collection whatever the outcome.
   ======================================================================
:)
declare function misc:create-collection-lazy ( $base-uri as xs:string, $path as xs:string, $user as xs:string, $group as xs:string, $perms as xs:string ) as xs:string*
{
  let $set := tokenize($path, '/')
  return (
    for $t at $i in $set
    let $parent := concat($base-uri, '/', string-join($set[position() < $i], '/'))
    let $path := concat($base-uri, '/', string-join($set[position() < $i + 1], '/'))
    return
     if (xdb:collection-available($path)) then
       ()
     else
       if (xdb:collection-available($parent)) then
         if (xdb:create-collection($parent, $t)) then
           compat:set-owner-group-permissions($path, $user, $group, $perms)
         else
           ()
       else
         (),
    concat($base-uri, '/', $path)
    )[last()]
};

(: ======================================================================
   High-level function to dereference one or more reference elements
   Returns a new element tag containing all unreferenced refs
   Dereferences picking up a selectors list from global-information
   The list name is derived from conventions on the element's name
   ======================================================================
:)
declare function misc:gen_display_name( $refs as element()*, $tag as xs:string ) as element()? {
  if ($refs) then
    let $driver := local-name($refs[1])
    let $root := substring-before($driver, 'Ref')
    let $type :=
      if (ends-with($root, 'y')) then
        replace($root, 'y$', 'ies')
      else
        concat($root, 's')
    return
      let $label := display:gen-name-for($type, $refs, 'en')
      return
        element { $tag } { $label }
  else
    ()
};

declare function local:gen_display_attribute( $refs as element()* ) as attribute()? {
  if ($refs) then
    let $driver := local-name($refs[1])
    let $root := if (ends-with($driver, 'Ref')) then substring-before($driver, 'Ref') else $driver
    let $type :=
      if (ends-with($root, 'y')) then
        replace($root, 'y$', 'ies')
      else
        concat($root, 's')
    return
      let $label := display:gen-name-for($type, $refs, 'en')
      return
        if ($label) then
          attribute { '_Display' } { $label }
        else
          ()
  else
    ()
};

declare function misc:unreference-date( $node as element()? ) as element()? {
  if ($node) then
    element { local-name($node) }
      {
      let $value := string($node/text())
      return
          (
          attribute { '_Display' } {
            if (string-length($value) > 10) then (: full date time skips time :)
              display:gen-display-date(substring($value, 1, 10), 'en')
            else
              display:gen-display-date($value, 'en')
          },
          $value
          )
      }
  else
    ()
};

(: ======================================================================
   XML Fragment conversion for end user consumption (localization, etc.)
   TODO:
   - add $lang parameter
   ======================================================================
:)
declare function misc:unreference( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element()
        return
          let $tag := local-name($node)
          return
            if (ends-with($tag, 's') and (count($node/*) > 0) and
                (every $c in $node/* satisfies ends-with(local-name($c), 'Ref'))) then
              element { $tag }
                {(
                local:gen_display_attribute($node/*),
                $node/*
                )}
(:            else if (ends-with($tag, 'OfficerRef') or ends-with($tag, 'CoachRef') or ends-with($tag, 'ManagerRef') or ends-with($tag, 'ByRef')) then
              element { $tag }
                {(
                  attribute { '_Display' } { display:gen-person-name($node/text(), 'en') },
                  $node/text()
                )}:)
            else if (ends-with($tag, 'Ref') or ($tag eq 'Country')) then
              element { $tag }
                {(
                local:gen_display_attribute($node),
                $node/text()
                )}
            else if ($tag eq 'Date') then
              misc:unreference-date($node)
            else
              element { $tag }
                { misc:unreference($node/(attribute()|node())) }
      default
        return $node
};

(: ======================================================================
   Returns a deep copy of the nodes sequence removing blacklisted node names
   ======================================================================
:)
declare function misc:filter( $nodes as item()*, $blacklist as xs:string* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element()
        return
          if (local-name($node) = $blacklist) then
            ()
          else
            element { node-name($node) }
              { misc:filter($node/(attribute()|node()), $blacklist) }
      default
        return $node
};

(: ======================================================================
   Tries to complete link if http:// missing
   ======================================================================
:)
declare function misc:gen-link( $link as element()? ) as element()? {
  if ($link) then
    <CV-Link>
      {
      if (starts-with($link, 'http:') or starts-with($link, 'https:')) then
        $link/text()
      else
        concat('http://', $link)
      }
    </CV-Link>
  else
    ()
};

declare function misc:pluralize( $term as xs:string, $nb as xs:integer ) as xs:string {
  if ($nb > 1) then 
    if (ends-with($term, 'y')) then 
      replace($term, 'y$', 'ies')
    else
      concat($term, 's')
  else
    $term
};

(: ======================================================================
   Returns node set containing only nodes in node set with textual
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
