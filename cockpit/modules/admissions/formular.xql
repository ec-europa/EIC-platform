xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: <Franck.Leple@amplexor.com>
   Contributors: Stéphane Sire <s.sire@oppidoc.fr>

   Displays a self-registration form

   TODO:
   - split into two controllers view.xql and edit.xql

   October 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../../xcm/modules/workflow/workflow.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   TODO: factorize with events/formular.xql ?
   ====================================================================== 
:)
declare function local:gen-event-title( $event as element() ) as xs:string {
  if (not($event/Name/@Extra)) then
    $event/Name
  else
    concat($event/Name, ' (', $event/*[local-name(.) = $event/Name/@Extra], ')')
};

(: ======================================================================
   Check user role allows to edit Admission and that Admission document
   is in Draf or in Reject state
   FIXME: define workflow and use access:check-workflow-permissions 
   ====================================================================== 
:)
declare function local:can-edit( $admission as element()? ) as xs:boolean {
  access:check-entity-permissions('update', 'Admission', $admission)
  and
  ($admission/AdmissionStatusRef = ('1', '3'))
};

(: ======================================================================
   Return the user category based on admission data
   Return "User" for any user registration data and "Investor" for legacy 
   investors registration data (for Berlin 2018 event)
   ====================================================================== 
:)
declare function local:get-registration-category( $admission as element()? ) as xs:string {
  if ($admission/Settings/Teams eq 'Investor') then 
    'Investor'
  else
    'User'
};

(: ======================================================================
   Page template to raise errors (show error in flash)
   ====================================================================== 
:)
declare function local:gen-error-page( $error as element()? ) {
  <Page StartLevel="1" skin="fonts extensions">
    <Window>Please complete your profile</Window>
    <Content/>
  </Page>
};

(: MAIN ENTRY POINT :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $tokens := tokenize($cmd/@trail, '/')
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goto-url := request:get-parameter('url', $cmd/@base-url)

return
  if (xdb:get-current-user() eq 'guest') then (: screen out guest access w/o reading /persons collection :)
    if ($target = ('entry', 'investors')) then
      let $url := concat($cmd/@base-url, "login?url=admissions/entry&amp;ecas=init")
      return (
        oppidum:add-message('INFO', 'Please login with your EU Login account before you can enter a registration form. You need to create an EU Login account first if you do not have one.', true()),
        <Redirected>{ oppidum:redirect($url) }</Redirected>
        )[last()]
    else
      local:gen-error-page(oppidum:throw-error('FORBIDDEN', ()))
      
  else
    let $profile := user:get-user-profile()
    return
      if ($target = ('entry', 'investors')) then
        (: User has a Profile :)
        if ($profile) then
          if (empty($profile//Role[AdmissionKey and FunctionRef eq '9'])) then 
            (: User is an accredited user : redirection to dashboard home  :)
            let $url := concat($cmd/@base-url, enterprise:default-redirect-to(()))
            return (
              oppidum:add-message('INFO', 'You already have an SME Dashboard access, currently this registration form is reserved to unregistered users', true()),
              <Redirected>{ oppidum:redirect($url) }</Redirected>
              )[last()]
          else 
            (: User is a pending user : redirection to admission form :)
            let $url := concat($cmd/@base-url, "admissions/", $profile//AdmissionKey[parent::Role[FunctionRef eq '9']][1])
            return (
              oppidum:add-message('INFO', 'You already have submitted a registration form, currently you can only submit one form. Please wait until your admission request will be processed.', true()),
              <Redirected>{ oppidum:redirect($url) }</Redirected>
              )[last()]
           
        else if ($target eq 'investors') then (: direct access to deprecated form :)
          <Redirected>{ oppidum:redirect(concat($cmd/@base-url, "admissions/entry")) }</Redirected>

        else
          (: *************************************************** :)
          (: * Formular to create a new admission in edit mode * :)
          (: *************************************************** :)
          (: User do not have a Profile : display form to create one :)
          (: TODO disable button for the PO - just display the form in read-only mode :)
          let $warning := oppidum:throw-message('INFO', 'Please complete this questionnaire then click on the submit button at the end')
          let $category := if ($target eq 'entry') then 'users' else 'investors'
          return
            <Page StartLevel="1" skin="fonts extensions">
              <Window>Please complete your profile</Window>
              <Content>
                <Title Level="1" class="ecl-heading">SME Dashboard registration</Title>
                  <Editor data-autoscroll-shift="160" Id="admissions">
                    <Template>../templates/admissions/{ $category }-self-registration?goal=update</Template>
                    <Action>
                      <Label>Save</Label>
                      <Controller>{ string($target) }</Controller>
                    </Action>
                    <Action>
                      <Label>Save &amp; Submit</Label>
                      <Controller>{ string($target) }?submit=1</Controller>
                    </Action>
                  </Editor>
              </Content>
            </Page>

     (: *********************************** :)
     (: * Existing admission in edit mode * :)
     (: *********************************** :)
      else if ($target = 'edit') then
        let $admissionId := tokenize($cmd/@trail, '/')[2]
        let $admission := fn:collection($globals:admissions-uri)//.[Id eq $admissionId]
        let $category := local:get-registration-category($admission)
        return
            if (exists($admission) and local:can-edit($admission)) then (
                oppidum:throw-message('INFO', 'Please edit this formular then click on the submit button at the end'),
                <Page StartLevel="1" skin="fonts extensions">
                  <Window>Please complete your profile</Window>
                  <Content>
                    <!--<Title Level="1" class="ecl-heading">Investor registration</Title>-->
                      <Editor data-autoscroll-shift="160" Id="admissions">
                        <Template>../../templates/admissions/{ lower-case($category) }s-self-registration?goal=update</Template>
                        <Resource>{ concat($target, "/../submitted.xml") }</Resource>
                          <Action>
                            <Label>Save</Label>
                            <Controller>edit</Controller>
                          </Action>
                          <Action>
                            <Label>Save &amp; Submit</Label>
                            <Controller>edit?submit=1</Controller>
                          </Action>
                      </Editor>
                  </Content>
                </Page>
                )[last()]
             else
                local:gen-error-page(oppidum:throw-error('FORBIDDEN', ()))

      (: **************************************** :)
      (: * Existing admission in read-only mode * :)
      (: **************************************** :)
      else
         let $admission := fn:collection($globals:admissions-uri)//.[Id eq $target]
         let $category := local:get-registration-category($admission)
         return
           if (empty($admission)) then
             local:gen-error-page(oppidum:throw-error('URI-NOT-FOUND', ()))
           else if (exists($profile) and access:check-entity-permissions('update', 'Admission', $admission)) then
             (: 1. feedback message(s) :)
             let $your := if (exists($profile//Role[FunctionRef eq '9' and AdmissionKey eq $target])) then 'Your a' else 'The a'
             let $the := if (exists($profile//Role[FunctionRef eq '9' and AdmissionKey eq $target])) then 'You have created the admission questionnaire' else 'The admission questionnaire has been created'
             return
               (
               oppidum:throw-message('INFO', concat($the, ' on ', display:gen-display-date-time($admission/@Creation))),
               if ($admission/AdmissionStatusRef eq '1') then
                  oppidum:throw-message('INFO', concat('Last draft admission has been saved on ', display:gen-display-date-time($admission/AdmissionStatusRef/@Date)))
               else if (empty($admission/AdmissionStatusRef) or ($admission/AdmissionStatusRef eq '2')) then
                     oppidum:throw-message('INFO', 
                       concat($your, 'dmission has been submitted on ', 
                         display:gen-display-date-time(
                           if (empty($admission/AdmissionStatusRef)) then 
                             $admission/@Creation 
                           else
                             $admission/AdmissionStatusRef/@Date
                           )
                       )
                     )
               else if ($admission/AdmissionStatusRef eq '3') then
                  oppidum:throw-message('INFO', concat($your, 'dmission has been rejected on ', display:gen-display-date-time($admission/AdmissionStatusRef/@Date)))
               else if ($admission/AdmissionStatusRef eq '4') then
                  oppidum:throw-message('INFO', concat($your, 'dmission has been authorized on ', display:gen-display-date-time($admission/AdmissionStatusRef/@Date)))
               else
                 (),
               (: 2. read-only formular widget configuration :)
               <Page StartLevel="1" skin="fonts extensions">
                 <Window>SME Dashboard registration</Window>
                 <Content>
                   <!--Title Level="1" style="margin-top: 0;margin-bottom:0">{ $category } registration</Title-->
                     <Editor data-autoscroll-shift="160" Id="admissions">
                       <Template>../templates/admissions/{ lower-case($category) }s-self-registration?goal=read</Template>
                       <Resource>{ concat($target, "/submitted.blend") }</Resource>
                       { 
                       if ($admission/AdmissionStatusRef = ('1', '3')) then (
                         (: still editable :)
                         <Action>
                           <Label>Edit</Label>
                           <Goto>{ string($target) }/edit</Goto>
                         </Action>,
                         if (exists($admission/AdmissionStatusRef) and $admission/AdmissionStatusRef ne '3') then
                           <Action>
                              <Label>Submit</Label>
                              <Controller>{ string($target) }/edit?submit=2</Controller>
                           </Action>
                         else 
                           ()
                          )
                       else
                         ()
                       }
                     </Editor>
                 </Content>
               </Page>
               )[last()]
           else
              local:gen-error-page(oppidum:throw-error('FORBIDDEN', ()))
