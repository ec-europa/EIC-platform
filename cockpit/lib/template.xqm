xquery version "1.0";

module namespace template = "http://oppidoc.com/ns/cctracker/template";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "util.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../app/custom.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../xcm/lib/user.xqm";
import module namespace xal = "http://oppidoc.com/ns/xcm/xal" at "../../xcm/lib/xal.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../xcm/lib/database.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../xcm/modules/workflow/workflow.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "display.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";

(: ======================================================================
   Implement Assert and Fallback attribute on Template
   ====================================================================== 
:)
declare function local:get-assert-template ( $name as xs:string, $subject as item()*, $object as item()*, $mode as xs:string ) as element()? {
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq $mode][@Name eq $name]
  return
    if (empty($src/@Assert) or util:eval($src/@Assert)) then
      $src
    else
      fn:collection($globals:templates-uri)//Template[@Mode eq $src/@Fallback][@Name eq $name]
};

(: ======================================================================
   Generates a document from a named template in a given mode
   ====================================================================== 
:)
declare function template:gen-document( 
  $name as xs:string?,
  $mode as xs:string,
  $subject as item()*,
  $object as item()*, 
  $form as element()?
  ) as element()?
{
  if ($name) then
    let $date := current-dateTime()
    let $src := fn:collection($globals:templates-uri)//Template[@Mode eq $mode][@Name eq $name]
    return
      if ($src) then
        misc:prune(util:eval(string-join($src/text(), '')))
      else
        oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for "',$mode ,'" mode'))
  else
    ()
};

(: ======================================================================
   Stub to call complete function with all parameters
   ====================================================================== 
:)
declare function template:gen-document( $name as xs:string?, $mode as xs:string, $form as element()? ) as element()?
{
  template:gen-document($name, $mode, (), (), $form)
};

(: ======================================================================
   Applies a "validate" data template. The template must contain some 
   XAL actions that returns either success or an error.
   WARNING: does not prune the template
   ====================================================================== 
:)
declare function template:do-validate-resource(
  $name as xs:string, 
  $subject as item()*, 
  $object as item()*, 
  $form as element()?
  ) as element()?
{
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq 'validate'][@Name eq $name]
  return
    if ($src) then
      let $delta := util:eval(string-join($src/text(), ''))
      let $res := xal:apply-updates($subject, $object, $delta)
      return
        if (local-name($res) ne 'error') then
          <valid/>
        else
          $res
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for validate mode'))
};

(: ======================================================================
   Generates a model from $name data template (read mode) and $subject data
   ====================================================================== 
:)
declare function template:gen-read-model( $name as xs:string, $subject as element(), $lang as xs:string ) as element() {
  template:gen-read-model($name, $subject, (), $lang)
};

(: ======================================================================
   Generates a model from $name data template (read mode) and $subject data 
   and optional $object data
   FIXME: prune or not ?
   ====================================================================== 
:)
declare function template:gen-read-model( $name as xs:string, $subject as element(), $object as element()?, $lang as xs:string ) as element()* {
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq 'read'][@Name eq $name]
  let $date := current-dateTime()
  return
    if ($src) then
      if (empty($src/@Assert) or util:eval($src/@Assert)) then 
        misc:unreference(util:eval(string-join($src/text(), ''))) (: FIXME: $lang :)
      else
        let $src := fn:collection($globals:templates-uri)//Template[@Mode eq $src/@Fallback][@Name eq $name]
        return
          if ($src) then
            misc:unreference(util:eval(string-join($src/text(), ''))) (: FIXME: $lang :)
          else
            oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for read mode'))
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for read mode'))
};

(: ======================================================================
   Generates a model from $name data template (read mode) with $id identifier 
   and $subject data. The $id is useful to extract data from a container.
   ====================================================================== 
:)
declare function template:gen-read-model-id( $name as xs:string, $id as xs:string, $subject as element(), $lang as xs:string ) as element() {
  template:gen-read-model-id($name, $id, $subject, (), $lang)
};

(: ======================================================================
   Generates a model from $name data template (read mode) with $id identifier 
   and $subject data and optional $object data. The $id is useful to extract data from a container.
   ====================================================================== 
:)
declare function template:gen-read-model-id( $name as xs:string, $id as xs:string, $subject as element(), $object as element()?, $lang as xs:string ) as element() {
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq 'read'][@Name eq $name]
  return
    if ($src) then
      misc:unreference(util:eval(string-join($src/text(), ''))) (: FIXME: $lang :)
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for read mode'))
};

(: ======================================================================
   Generates a data model from the $name data template (create mode) 
   and the $form submitted data, using an $id identifier.
   The optional $creator-ref may be used to override the $uid variable which 
   is set to the current person id otherwise.
   Does not save into database (use create-resource for that purpose).
   ====================================================================== 
:)
declare function template:gen-create-model-id(
  $name as xs:string, 
  $id as xs:string?,
  $form as element(), 
  $creator-ref as xs:string? 
  ) as element()
{
  let $date := current-dateTime()
  let $uid := if ($creator-ref) then $creator-ref else user:get-current-person-id()
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq 'create'][@Name eq $name]
  return
    if ($src) then
      misc:prune(util:eval(string-join($src/text(), '')))
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for create mode'))
};

(: ======================================================================
   Generates and applies a XAL sequence from the $name data template (update mode)
   combining data from the submitted $form data and the database $subject.
   Usually the XAL sequence replaces the $subject.
   ====================================================================== 
:)
declare function template:update-resource( $name as xs:string, $subject as element(), $form as element() ) as element() {
  template:update-resource-id($name, (), $subject, (), $form)
};

(: ======================================================================
   Generates and applies a XAL sequence from the $name data template (update mode)
   combining data from the submitted $form data and the database $subject.
   The identifier $id can be used to extract/persists data from the $subject 
   when it contains several resources.
   Usually the XAL sequence replaces the resource matching the identifier $id
   of the the $subject.
   ====================================================================== 
:)
declare function template:update-resource-id( $name as xs:string, $subject as element(), $id as xs:string, $form as element() ) as element() {
  template:update-resource-id($name, $id, $subject, (), $form)
};

(: ======================================================================
   Generates and applies a XAL sequence from the $name data templates (update mode)
   combining data from the submitted $form data and the database $subject
   and an optional database $object.
   Usually the XAL sequence replaces the $subject and maintains some form 
   of relation in the $object (or vice versa).
   ====================================================================== 
:)
declare function template:update-resource(
  $name as xs:string, 
  $subject as element(), 
  $object as element()?, 
  $form as element() 
  ) as element()
{
  template:update-resource-id($name, (), $subject, $object, $form)
};


(: ======================================================================
   Facade that throws an oppidum ACTION-UPDATE-SUCCESS message on success
   ====================================================================== 
:)
declare function template:update-resource-id(
  $name as xs:string, 
  $id as xs:string?,
  $subject as element(), 
  $object as element()?, 
  $form as element() 
  ) as element()
{
  let $res := template:do-update-resource($name, $id, $subject, $object, $form)
  return  
    if (local-name($res) ne 'error') then
      oppidum:throw-message('ACTION-UPDATE-SUCCESS', ())
    else
      $res
};

(: ======================================================================
   Generates and applies a XAL sequence from the $name data template (update mode)
   combining data from the submitted $form data and the database $subject
   and an optional database $object.
   Usually the XAL sequence replaces the resource matching the identifier $id
   of the the $subject and/or of the $object and maintains some form of relation
   between both.
   ====================================================================== 
:)
declare function template:do-update-resource(
  $name as xs:string, 
  $id as xs:string?,
  $subject as item()*, 
  $object as item()*, 
  $form as element() 
  ) as element()
{
  let $date := current-dateTime()
  let $uid := user:get-current-person-id()
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq 'update'][@Name eq $name]
  return
    if ($src) then
      let $delta := misc:prune(util:eval(string-join($src/text(), '')))
      return
        xal:apply-updates($subject, $object, $delta)
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for update mode'))
};

(: ======================================================================
  do-update-resource without $uid
  Useful for scheduled job since this job have no session and httprequest
   ====================================================================== 
:)  
declare function template:do-update-resource-no-uid(
  $name as xs:string, 
  $id as xs:string?,
  $subject as item()*, 
  $object as item()*, 
  $form as element() 
  ) as element()
{
  let $date := current-dateTime()
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq 'update'][@Name eq $name]
  return
    if ($src) then
      let $delta := misc:prune(util:eval(string-join($src/text(), '')))
      return
        xal:apply-updates($subject, $object, $delta)
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for update mode'))
};


(: ======================================================================
   Generic version of template:do-create-resource that throws an oppidum
   success message in case of success (useful to respond to Ajax protocol)
   ====================================================================== 
:)
declare function template:create-resource(
  $name as xs:string, 
  $subject as element()?, 
  $object as element()?, 
  $form as element(), 
  $creator-ref as xs:string? 
  ) as element()?
{
  let $res := template:do-create-resource($name, $subject, $object, $form, $creator-ref)
  return  
    if (local-name($res) ne 'error') then
      oppidum:throw-message('ACTION-CREATE-SUCCESS', ())
    else
      $res
};

(: ======================================================================
   Generates and applies a XAL sequence from the $name data template (create mode)
   combining data from the submitted $form data and the database $subject
   and an optional database $object. 
   The optional $creator-ref may be used to override the $uid variable which 
   is set to the current person id otherwise.
   Logically the XAL sequence should create a new document or at least insert 
   the new resource inside the $subject and/or $object.
   By convention sets a $mode to 'batch' when $creator-ref is '-1'. Use this 
   to disconnect invalidate XAL action when doing a batch.
   FIXME: current API limited to 1 create XAL action per sequence !!!
   ====================================================================== 
:)
declare function template:do-create-resource(
  $name as xs:string, 
  $subject as item()*, 
  $object as item()*, 
  $form as element(), 
  $creator-ref as xs:string? 
  ) as element()?
{
  let $date := current-dateTime()
  let $uid := if ($creator-ref) then $creator-ref else user:get-current-person-id()
  let $src := local:get-assert-template($name, $subject, $object, 'create')
  let $mode := if ($creator-ref eq '-1') then 'batch' else 'interactive'
  return
    if ($src) then
      let $id := (: generates new keys for XAL create action if any :)
        if (contains($src,'Type="create"')) then 
          let $db-uri := string(oppidum:get-command()/@db)
          let $entity := substring-before(substring-after($src, 'Entity="'), '"')
          return database:make-new-key-for($db-uri, $entity)
        else
          ()
      return
        let $delta := misc:prune(util:eval(string-join($src/text(), '')))
        return 
          xal:apply-updates($subject, $object, $delta)
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for create mode'))
};


(: ======================================================================
  do-create-resource without $uid
  Useful for scheduled job since this job have no session and httprequest
   ====================================================================== 
:) 
declare function template:do-create-resource-no-uid(
  $name as xs:string, 
  $subject as item()*, 
  $object as item()*, 
  $form as element(), 
  $creator-ref as xs:string? 
  ) as element()?
{
  let $date := current-dateTime()
  let $src := local:get-assert-template($name, $subject, $object, 'create')
  let $mode := if ($creator-ref eq '-1') then 'batch' else 'interactive'
  return
    if ($src) then
      let $id := (: generates new keys for XAL create action if any :)
        if (contains($src,'Type="create"')) then 
          let $db-uri := string(oppidum:get-command()/@db)
          let $entity := substring-before(substring-after($src, 'Entity="'), '"')
          return database:make-new-key-for($db-uri, $entity)
        else
          ()
      return
        let $delta := misc:prune(util:eval(string-join($src/text(), '')))
        return 
          xal:apply-updates($subject, $object, $delta)
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for create mode'))
};

(: ======================================================================
   Generates and applies a XAL sequence from the $name data template (delete mode)
   ====================================================================== 
:)
declare function template:do-delete-resource(
  $name as xs:string, 
  $subject as item()*, 
  $object as item()*
  ) as element()?
{
  let $date := current-dateTime()
  let $src := fn:collection($globals:templates-uri)//Template[@Mode eq 'delete'][@Name eq $name]
  return
    if ($src) then
      let $delta := misc:prune(util:eval(string-join($src/text(), '')))
      return
        xal:apply-updates($subject, $object, $delta)
    else
      oppidum:throw-error('CUSTOM', concat('Missing "', $name, '" template for delete mode'))
};

(: ======================================================================
   Validate a transition on a subject Event and object Enterprise by implementing 
   the Assert element of the Transition :
   - if Transition/Assert/@Tab is defined check first Processing/Document/@Tab
     inside event meta-data
   - fallback to Transition's Assert/@Template otherwise
   - always valid otherwise
   Returns a valid element in case of success or an error element
   NOTE: does not implement legacy inline Assert(ions), only @Template 
   or @Tab style assertions
   ====================================================================== 
:)
declare function template:assert-event-transition( $transition as element(), $event-def as element(), $subject as element(), $object as element() ) as element()? {
  let $processing := custom:get-event-processing($event-def, $object)
  let $validator := 
    if ($transition/Assert/@Tab) then 
      if (exists($processing/Document[@Tab eq $transition/Assert/@Tab]/Validate)) then
        $processing/Document[@Tab eq $transition/Assert/@Tab]/Validate
      else 
        $transition/Assert/@Template
    else
      $transition/Assert/@Template
  return
    if (exists($validator)) then
      if (exists($transition/Assert/@Pivot)) then
        template:do-validate-resource($validator, util:eval($transition/Assert/@Pivot), $event-def, ())
      else
        oppidum:throw-error('WFSTATUS-MISSING-VALIDATION-PIVOT', ())
    else if (exists($transition/Assert/true)) then
      (: old fashion inline Assert element in application.xml :)
      let $omissions := workflow:validate-transition($transition, $subject, ())
      return
        if (count($omissions) gt 1) then
          let $explain :=
            string-join(
              for $o in $omissions
              let $e := oppidum:throw-error($o, ())
              return $e/message/text(), '&#xa;&#xa;')
          return
            oppidum:throw-error(string($transition/@GenericError), concat('&#xa;&#xa;',$explain))
        else if ($omissions) then
          oppidum:throw-error($omissions, ())
        else
          (: everything okay :)
          <valid/>
    else
      <valid/>
};
