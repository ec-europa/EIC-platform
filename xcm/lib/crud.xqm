xquery version "1.0";

module namespace crud = "http://oppidoc.com/ns/xcm/crud";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/xcm/misc" at "util.xqm";
import module namespace xal = "http://oppidoc.com/ns/xcm/xal" at "xal.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "user.xqm";

declare function crud:get-document( $name as xs:string, $case as element(), $lang as xs:string ) as element() {
  crud:get-document($name, $case, (), $lang)
};

declare function crud:get-document( $name as xs:string, $case as element(), $activity as element()?, $lang as xs:string ) as element() {
  let $src := globals:collection('templates-uri')//Template[@Mode eq 'read'][@Name eq $name]
  return
    if ($src) then
      misc:unreference(util:eval(string-join($src/text(), ''))) (: FIXME: $lang :)
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for read mode'))
};

declare function crud:save-document( $name as xs:string, $case as element(), $form as element() ) as element() {
  crud:save-document($name, $case, (), $form)
};

declare function crud:get-vanilla( $document as xs:string, $case as element(), $activity as element()?, $lang as xs:string ) as element() {
  let $src := globals:collection('templates-uri')//Template[@Mode eq 'read'][@Name eq 'vanilla']
  return
    if ($src) then
      misc:unreference(util:eval(string-join($src/text(), ''))) (: FIXME: $lang :)
    else
      oppidum:throw-error('CUSTOM', concat('Missing vanilla template for read mode'))
};

(: ======================================================================
   FIXME: adopt generic $subject / $object convention
   ====================================================================== 
:)
declare function crud:save-document(
  $name as xs:string, 
  $case as element(), 
  $activity as element(), 
  $form as element() 
  ) as element()
{
  let $date := current-dateTime()
  let $uid := user:get-current-person-id() 
  let $src := globals:collection('templates-uri')//Template[@Mode eq 'update'][@Name eq $name]
  return
    if ($src) then
      let $delta := misc:prune(util:eval(string-join($src/text(), '')))
      let $res := xal:apply-updates(if ($activity) then $activity else $case, $delta)
      return
        if (local-name($res) ne 'error') then
          oppidum:throw-message('ACTION-UPDATE-SUCCESS', ())
        else
          $res
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for update mode'))
};

(: ======================================================================
   FIXME: adopt generic $subject / $object convention
   ====================================================================== 
:)
declare function crud:save-vanilla(
  $document as xs:string, 
  $case as element(), 
  $activity as element(), 
  $form as element() 
  ) as element()
{
  let $date := current-dateTime()
  let $uid := user:get-current-person-id() 
  let $src := globals:collection('templates-uri')//Template[@Mode eq 'update'][@Name eq 'vanilla']
  return
    if ($src) then
      let $delta := misc:prune(util:eval(string-join($src/text(), '')))
      let $res := xal:apply-updates(if ($activity) then $activity else $case, $delta)
      return
        if (local-name($res) ne 'error') then
          oppidum:throw-message('ACTION-UPDATE-SUCCESS', ())
        else
          $res
    else
      oppidum:throw-error('CUSTOM', concat('Missing vanilla template for update mode'))
};
