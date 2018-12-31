xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   <Export><Message><Tag1/>..<TagN/></Message></Export> :

----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:register-officer( $officer as element()? ) as element() {
  if ($officer) then
    let $easme := fn:collection($globals:enterprises-uri)//Enterprise[Id eq '1']
    let $name := concat($officer/Name/FirstName, ' ', $officer/Name/LastName)
    let $key := $officer//Remote[@Name eq 'ECAS']
    (: sanity check - TODO: normalize Email :)
    let $exist-member := exists($easme//Member[lower-case(Information/Contacts/Email) eq lower-case($officer/Contacts/Email)])
    let $person := fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq 'ECAS'] = $key]
    let $exist-remote := $key and $person
    let $role :=
      if ($exist-remote) then
        template:update-resource('project-officer-promote', $person, <nodata/>)
      else
        ()
    return
      if ($exist-member and $exist-remote) then
        <ok key="{ $key }" reason="no need to import, already registered in the application">{ $name }</ok>
      else if (not($exist-member) and $exist-remote) then
        (: TODO: fix it ? :)
        <ok key="{ $key }" reason="the ECAS remote key already exists (with Id { $person/Id/text() }), seems to be unaffiliated to a company">{ $name }</ok>
      else
        let $res := template:create-resource('unaffiliated-project-officer', (), (), $officer, '-2')
        return
          if (local-name($res) ne 'error') then
            <created reason="project officer recorded into the application" key="{ $key }">{ $name }</created>
          else
            <failed reason="{ string($res) }">{ $name }</failed>
  else
    <nothing/>
};

declare function local:decode-summary( $summary as element() ) as element() {
  <Summary>
    {
    for $t in $summary/Text
    return <Text>{ util:base64-decode($t) }</Text>
    }
  </Summary>
};

declare function local:bootstrap-lear( $person as element()?, $enterprise as element() ) as element() {
  let $key := $person//Remote[@Name eq 'ECAS']
  let $p := fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq 'ECAS'] = $key]
  let $exist-remote := $key and $person
  return
    if ($exist-remote) then (: LEAR already has an account :)
      template:do-update-resource('lear', $p/Id, $enterprise, $p, $person)
    else (: LEAR has no account yet :)
      template:do-create-resource('lear', $enterprise, (), $person, ())
};

declare function local:process-enterprise( $enterprise as element()) as element() {
  <Results>
  {
  system:as-user(account:get-secret-user(), account:get-secret-password(),
  (
  let $e := collection($globals:enterprises-uri)//Enterprise[Id = $enterprise/Id]
  return
    if ($e) then (: exists already no creation :)
      let $some-members := exists($e/Team/Members/Member)
      return
        if ($some-members) then (: no change policy therefore no action :)
          <already_members/>
        else
          local:bootstrap-lear( $enterprise/Team/Members/LEAR, $e )
    else
      () (: TODO: call to data template for the enterprise :)
  ))
  }
  </Results>
};

declare function local:process-message( $message as element() ) as element() {
  <Results>
  {
  system:as-user(account:get-secret-user(), account:get-secret-password(),
  (
    let $form :=
      <Message>
        {
        $message/@Project,
        for $e in $message/element()
        return
          if (local-name($e) eq 'ProjectOfficer') then
            let $out := local:register-officer($e)
            return if ($out/@key) then <ProjectOfficerKey>{ string($out/@key) }</ProjectOfficerKey> else ()
          else if (local-name($e) eq 'BackupProjectOfficer') then
            let $out := local:register-officer($e)
            return if ($out/@key) then <BackupProjectOfficerKey>{ string($out/@key) }</BackupProjectOfficerKey> else ()
          else if (local-name($e) eq 'GrantAgreementPreparationRef') then
            let $sign := $e[text() eq '6']
            return
              if ($sign) then
                <CommissionSignature>{ string($sign/@TS) }</CommissionSignature>
              else
                ()
          else if (local-name($e) = ('ProjectStartDate','ProjectEndDate','ProjectDuration')) then
            $e
          else if (local-name($e) eq 'Summary') then
            local:decode-summary($e)
          else
            ()
        }
      </Message>
    return
      let $ents := collection($globals:enterprises-uri)//Enterprise[Id = ($message/@Coordinator, tokenize($message/@Partner, ','))]
      return
        for $e in $ents
        let $exists := $e/Projects/Project[ProjectId eq $message/@Project]
        let $form-c := <form ProjectId="{$message/@Project}">{ $message/(Acronym | Call)  }<Role>{ if ($message/@Coordinator eq $e/Id) then 'Coordinator' else 'Partner'}</Role></form>
        let $lazy := if ($exists) then () else template:do-create-resource('project', $e, (), $form-c , '-1')
        return 
          template:update-resource('import-status', $e/Projects/Project[ProjectId eq $message/@Project], $form)
    ))
  }
  </Results>
};

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cockpit', 'cockpit.messages', $submitted)
return
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    return
      if ($search/Message) then
        local:process-message( $search/Message )
      else if ($search/Enterprise) then
        local:process-enterprise( $search/Enterprise )
      else
        ()
  else
    $errors
