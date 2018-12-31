xquery version "1.0";
(: --------------------------------------
   -------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
  
let $cmd := request:get-attribute('oppidum.command')
let $ua := request:get-header('user-agent')
let $cno := tokenize($cmd/@trail,'/')[2]
let $project := collection('/db/sites/cctracker/projects')/Project[FormerCaseNo eq $cno]/Id
let $ano := tokenize($cmd/@trail,'/')[4]
let $act := if ($ano ne '') then $project/../Cases/Case[No eq '1']/Activities/Activity[No eq $ano] else ()
return
  if ($project) then
    (
    oppidum:add-message('INFO', 'The case tracker has been updated. Please update your bookmarks accordingly.', true()),
    <Redirect>{oppidum:redirect(concat($cmd/@base-url,'projects/', $project, '/cases/', 1, if ($act) then concat('/activities/', $ano) else ()))}</Redirect>
    )[last()]
  else
    (
    oppidum:add-message('INFO', 'The case tracker has been updated and the address cannot be reached. Please update your bookmarks accordingly.', true()),
    <Redirect>{oppidum:redirect(concat($cmd/@base-url,'stage'))}</Redirect>
    )[last()]