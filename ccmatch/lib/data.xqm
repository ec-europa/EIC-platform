xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   Utilities for data adpatation

   September 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace data = "http://oppidoc.com/ns/ccmatch/data";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

(: ======================================================================
   Converts skills facets into Skills elements for writing to database 
   ======================================================================
:)
  declare function local:encode-1-skills( $name as xs:string, $skills as element()* ) as element()* {
  <Skills For="{ $name }">
    {
    for $cur in $skills[. ne '']
    let $key := tokenize(local-name($cur), '_')[last()]
      return
        <Skill For="{ $key }">{ $cur/text() }</Skill>
    }
  </Skills>
};

declare function local:encode-2-skills( $skills as element() ) as element() {
  <Skills For="{ local-name($skills) }">
    {
    for $top in distinct-values(for $n in $skills/* return tokenize(local-name($n), '_')[2])
    return
      local:encode-1-skills($top, $skills/*[tokenize(local-name(.), '_')[2] eq $top])
    }
  </Skills>
};

declare function data:encode-skills( $skills as element() ) as element()? {
  let $depth := count(tokenize(local-name($skills/*[1]), '_'))
  return
  if ($depth eq 2) then
    local:encode-1-skills(local-name($skills), $skills/*)
  else if ($depth eq 3) then
    local:encode-2-skills($skills)
  else
    ()
};
