xquery version "3.1";
(: --------------------------------------
   ScaleupEU console

   Raw access to some token management functionalities
   but with a direct dump of web service request 
   to help debug the protocol

   This console partially duplicates web service procotol
   implemented in enterprise.xqm, so keep it aligned !

   TODO:
   - force delete (?force=1) with dialogue
   -------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option exist:serialize "method=xml media-type=text/html";

declare function local:get-category( $enterprise as element() ) as xs:string {
  if (enterprise:is-a($enterprise, 'Investor')) then 
    'investor'
  else
    'beneficiary'
};

(: ======================================================================
   Convert facilitator or monitor role ref to a Category name
   ====================================================================== 
:)
declare function local:gen-category-for( $roles-ref as xs:string* ) as xs:string {
  if ($roles-ref = '10') then 
    'facilitator' 
  else if ($roles-ref = '11') then 
    'monitor'
  else
    '?'
};

declare function local:gen-token-name( $token as element()? ) {
  if ($token eq '1') then 
    <span style="color:LightSalmon">Pending</span> 
  else if ($token eq '3') then 
    <span style="color:green">Allocated</span> 
  else if ($token eq '4') then 
    <span style="color:orange">Withdrawn</span>
  else if ($token eq '6') then 
    <span style="color:red">Deleted</span>
  else if ($token) then
    <span>{ display:gen-name-for('TokenStatus', $token, 'en') }</span>
  else
    <span style="color:red">missing TokenRequest</span>
};

(: ======================================================================
   ScaleupEU request payload to delete a Company account
   TODO: data template
   ====================================================================== 
:)
declare function local:gen-scaleup-delete( $enterprise as element(), $email-key as xs:string ) as element() {
  <Company>
    <Operation>delete</Operation>
    <Category>{ local:get-category($enterprise) }</Category>
    <CompanyId>{ $enterprise/Id/text() }</CompanyId>
    <Contact>
      <Email>{ $email-key }</Email>
    </Contact>
  </Company>
};

(: ======================================================================
   Extended version of enterprise:get-last-scaleup-request to include 
   tokens in 'delete' status
   ====================================================================== 
:)
declare function local:get-last-scaleup-request ( $enterprise as element() ) as element()? {
  head(
    for $req in $enterprise//TokenHistory[@For eq 'ScaleupEU']/TokenRequest
    order by number($req/Order) descending
    return $req
  )
};

(: ======================================================================
   Generate link to update individual accounts as facilitator or monitor
   ====================================================================== 
:)
declare function local:gen-individual-update-link( $account as element() ) {
  if ($account//Role[FunctionRef eq '10']) then
    <a href="console?u={$account/Information/Contacts/Email}&amp;r=10">facilitator</a>
  else if ($account//Role[FunctionRef eq '11']) then
    <a href="console?u={$account/Information/Contacts/Email}&amp;r=11">monitor</a>
  else
    <span style="font-style:italic">(no existing role)</span>
};

(: ======================================================================
   Generate link to delete individual accounts as facilitator or monitor
   ====================================================================== 
:)
declare function local:gen-individual-delete-link( $account as element() ) {
  if ($account//Role[FunctionRef = ('10', '11')]) then (: role exists, no need to specify :)
    <a href="console?di={$account/Information/Contacts/Email}">delete existing role</a>
  else (
    <span style="font-style:italic">no existing facilitator or monitor role</span>," delete as ",
    <a href="console?di={$account/Information/Contacts/Email}&amp;r=10">facilitator</a>,
    " or ",
    <a href="console?di={$account/Information/Contacts/Email}&amp;r=11">monitor</a>
    )
};

(: ======================================================================
   Index view listing of all users having dealt with a ScaleupEU token
   ====================================================================== 
:)
declare function local:list-all() {
  <div>
    <p style="font-weight:bold">Help</p>
    <blockquote>
      <p>use ?dc=email to delete a Company account or click on <i>delete</i><br/>
      use ?di=email to delete an Individual account or click on <i>delete</i><br/>
      click on <i>update</i> to force an update<br/>
      click on <a href="console?error=1">error</a> to force an error<br/>
      <i>suspend</i> will be available soon</p>
    </blockquote>
    <p style="font-weight:bold">Company accounts</p>
    <ul>
      {
      for $enterprise in fn:collection('/db/sites/cockpit/enterprises')/Enterprise[descendant::TokenHistory[@For eq 'ScaleupEU']]
      let $token := local:get-last-scaleup-request($enterprise)
      return
        <li>{ $enterprise/Information/Name/text() } ({ $enterprise/Id/text() }, <a href="../../teams/{ $enterprise/Id/text() }" target="_blank">team</a>) : { $token/Email/text() } { if ($token/Email) then (" (", <a href="console?dc={$token/Email}">delete</a>, if ($token/TokenStatusRef eq '3') then (" | ",  <a href="console?u={$enterprise/Id/text()}">update</a>) else (), ")") else () } &#8594; { local:gen-token-name($token/TokenStatusRef) }</li>
      }
    </ul>
    <p style="font-weight:bold">Individual accounts</p>
    <ul>
      {
      for $account in fn:collection('/db/sites/cockpit/persons')/Person[descendant::Role[FunctionRef = ('10', '11')] or descendant::TokenHistory[@For eq 'ScaleupEU'][TokenRequest/TokenStatusRef/text() ne '6']]
      let $token := $account//TokenHistory[@For eq 'ScaleupEU']/TokenRequest
      return
        <li>{ string-join($account/Information/Name/*, ' ') } : <i>{ concat(local:gen-category-for($account/UserProfile//Role), ', ') }</i> { $account/Information/Contacts/Email/text() } ({ local:gen-individual-delete-link($account) } | update as { local:gen-individual-update-link($account) }) &#8594; { local:gen-token-name($token/TokenStatusRef) }</li>
      }
    </ul>
  </div>
};

declare function local:serialize( $e as element() ) {
  <pre>
    { 
    fn:serialize(
      $e,
      <output:serialization-parameters>
        <output:indent value="yes"/>
      </output:serialization-parameters>
    )
    }
  </pre>
};

(: ======================================================================
   Wrong request to trigger error (to debug error messages)
   ====================================================================== 
:)
declare function local:gen-scaleup-error() {
  <div>
    <p style="font-weight:bold">Delete report</p>
    <ul>
      {
      <li>generating an error with a bad request<br/>
        {
        local:serialize(
          services:decode(
            services:post-to-service('invest', 'invest.end-point',
              <Company>
                <Operation>delete</Operation>
                <Category>investor</Category>
                <CompanyId>-1</CompanyId>
                <Contact>
                  <Email>bad request</Email>
                </Contact>
              </Company>
              , ("200", "###")
            )
          )
        )
        }
      </li>
      }
    </ul>
    <p>Back to <a href="console">list</a></p>
  </div>
};

declare function local:scaleup-delete( $enterprise as element(), $email as xs:string ) {
  local:serialize(
    services:decode(
      services:post-to-service('invest', 'invest.end-point',  
        local:gen-scaleup-delete($enterprise, $email), ("200", "###")
      )
    )
  )
};

declare function local:scaleup-delete( $enterprise as element() , $email as xs:string, $post-func ) {
  local:serialize(
    <Result>
      {
      let $res := 
        services:decode(
          services:post-to-service('invest', 'invest.end-point',  
            local:gen-scaleup-delete($enterprise, $email), ("200", "###")
            )
        )
      return (
        $res,
        if (empty($res//Error)) then
          (: call post-func only in case of success :)
          $post-func($enterprise, $email)
        else
          ()
        )
    }
    </Result>
  )
};

(: ======================================================================
   Send delete request for individual account to ScaleupEU web service
   On success remove account individual ScaleupEU role
   ====================================================================== 
:)
declare function local:scaleup-delete-individual( $account as element() ) {
  let $roles-ref := request:get-parameter('r', $account/UserProfile//Role/FunctionRef/text())
  let $last := $account//TokenHistory[@For eq 'ScaleupEU']/TokenRequest
  let $cat := local:gen-category-for($roles-ref)
  let $payload := template:gen-document('scaleup-individual-wstoken', 'delete', $account, (), 
                    <Form><Category>{ $cat }</Category>{ $last/Email }</Form>)
  return
    local:serialize(
      <Result>
        {
        if (local-name($payload) ne 'error') then
          let $res := 
            services:decode(
              services:post-to-service('invest', 'invest.end-point', $payload, ("200", "###"))
            )
          return (
            <Payload>{ $payload }</Payload>,
            $res,
            if (empty($res//Error)) then (
              template:do-update-resource('token-delete', (), $last, (), <Form/>),
              update delete $account//Role[FunctionRef = ('10', '11')],
              update delete $account/BusinessSegmentation
              )
            else
              ()
            )
        else
          $payload
        }
      </Result>
    )
};

(: ======================================================================
   Resend latest active Company token request (update or suspend) to ScaleupEU WS
   ====================================================================== 
:)
declare function local:revalidate( $enterprise as element() , $email as xs:string ) {
  <Revalidate>
    {
    let $cur-token := enterprise:get-last-scaleup-request ($enterprise)
    let $member := $enterprise//Member[PersonRef eq $cur-token/PersonKey]
    return
      if (exists($cur-token)) then (
        let $payload := if ($cur-token/TokenStatusRef eq '3') then 
                          enterprise:gen-scaleup-update($enterprise, $member)
                        else (: assume 4 :)
                          enterprise:gen-scaleup-suspend( $enterprise, $member, $cur-token/Email)
        let $res := 
          services:decode(
            services:post-to-service('invest', 'invest.end-point', $payload, ("200", "###"))
          )
        return (
          $res,
          if (empty($res//Error)) then
            <done>Last TokenRequest revalidated</done>
          else
            <error>Last TokenRequest not revalidated</error>
          )
        )
      else
        <cancelled>Last TokenRequest not found</cancelled>
    }
  </Revalidate>
};

(: ======================================================================
   Switch last company token status to 'delete'
   To be called in case of MatchInvest delete success
   ====================================================================== 
:)
declare function local:switch( $enterprise as element() , $email as xs:string ) {
  <Switch>
    {
    let $cur-token := enterprise:get-last-scaleup-request ($enterprise)
    return
      if (exists($cur-token)) then (
        let $account := globals:collection('persons-uri')//Person[Id eq $cur-token/PersonKey]
        return template:do-update-resource('remove-role', (), $account, $enterprise, <FunctionRef>8</FunctionRef>),
        template:do-update-resource('token-delete', (), $cur-token, (), <Form/>),
        <done>Last TokenRequest set to delete</done>
        )
      else
        <cancelled>Last TokenRequest not found</cancelled>
    }
  </Switch>
};

(: ======================================================================
   Delete a company account
   ====================================================================== 
:)
declare function local:delete-token( $email as xs:string ) {
  <div>
    <p style="font-weight:bold">Delete company account report</p>
    <ul>
      {
      let $previous-tokens := fn:collection('/db/sites/cockpit/enterprises')/Enterprise[descendant::TokenHistory[@For eq 'ScaleupEU']/TokenRequest[Email eq $email]]
      return
        if (exists($previous-tokens)) then (: user once had a TokenRequest :)
          for $enterprise in $previous-tokens
          let $cur := enterprise:get-token-owner-mail($enterprise)
          return
            if (empty($cur)) then
              (: TODO: just ask MatchInvest to delete, 
                 FIXME: eventually create a delete TokenRequest :)
              <li>deleting past token owner { $email } in { $enterprise/Information/Name/text() }<br/>
              { local:scaleup-delete($enterprise, $email) }
              </li>
            else if ($cur eq $email) then
              (: TODO: ask MatchInvest to delete and switch TokenRequest to delete :)
              <li>deleting current token owner { $email } in { $enterprise/Information/Name/text() }<br/>
              { local:scaleup-delete($enterprise, $email, function-lookup(xs:QName("local:switch"), 2)) }
              </li>
            else
              (: TODO: revalidate in case was wrongly associated with company ! :)
              <li>deleting past token owner { $email } in { $enterprise/Information/Name/text() } and revalidate current token owner { $cur }<br/>
              { local:scaleup-delete($enterprise, $email, function-lookup(xs:QName("local:revalidate"), 2)) } 
              </li>
        else  (: user never involved in a TokenRequest :)
          let $companies := fn:collection('/db/sites/cockpit/enterprises')/Enterprise[descendant::Member[Information/Contacts/Email eq $email]]
          return
            if (exists($companies)) then
              for $enterprise in $companies
              let $token := enterprise:get-last-scaleup-request ($enterprise)
              let $cur := if ($token/TokenStatusRef eq '3') then enterprise:get-token-owner-mail($enterprise) else ()
              return
                if (exists($cur)) then
                  (: TODO: revalidate in case was wrongly associated with company ! :)
                  <li>deleting { $email } who never had token in { $enterprise/Information/Name/text() } and revalidate current token owner { $cur }<br/>
                  { local:scaleup-delete($enterprise, $email, function-lookup(xs:QName("local:revalidate"), 2)) }
                  </li>
                else 
                  (: TODO: just ask MatchInvest to delete :)
                  <li>deleting { $email } who never had token in { $enterprise/Information/Name/text() }<br/>
                  { local:scaleup-delete($enterprise, $email) } 
                  </li>
            else
              (: beneficiary or investor ? :)
              <li>{ $email } not registered in any company ?</li>
      }
    </ul>
    <p>Back to <a href="console">list</a></p>
  </div>
};

(: ======================================================================
   Delete an individual account
   ====================================================================== 
:)
declare function local:delete-individual( $email as xs:string ) {
  <div>
    <p style="font-weight:bold">Delete individual account report</p>
    <ul>
      {
      let $previous-individual := fn:collection('/db/sites/cockpit/persons')/Person[descendant::TokenHistory[@For eq  'ScaleupEU']/TokenRequest[Email eq $email]]
      return
        if (exists($previous-individual)) then
          <li>deleting individual { local:gen-category-for($previous-individual/UserProfile//Role) } account { $email }<br/>
          { local:scaleup-delete-individual($previous-individual) } 
          </li>
        else  (: user never involved in an individual TokenRequest :)
          <li>{ $email } never had an individual account</li>
      }
    </ul>
    <p>Back to <a href="console">list</a></p>
  </div>
};

(: ======================================================================
   See also enterprise:update-scaleup
   ====================================================================== 
:)
declare function local:scaleup-update( $enterprise as element(), $account as element() ) {
  local:serialize(
    <Result>
      {
      let $member := $enterprise/Team/Members/Member[PersonRef eq $account/Id]
      let $last := enterprise:get-most-recent-request($enterprise, $account/Id)
      (: pre-condition: MUST be the 'allocated' TokenRequest :)
      return
        if (exists($member)) then
          let $payload := enterprise:gen-scaleup-update($enterprise, $member)
          return
            let $res := 
              services:decode(
                services:post-to-service('invest', 'invest.end-point', 
                  $payload, ("200", "###")
                  )
              )
            return (
              <Request><Payload>{ $payload }</Payload></Request>,
              <Response>{ $res }</Response>,
              if (empty($res//Error) and ($payload/Contact/Email ne $last/Email)) then
                (: unlikely :)
                template:do-update-resource('token', (), $last, (), <Form>{ $payload/Contact/Email }</Form>)
              else
                ()
              )
        else (: unlikely :)
          <error>ScaleupEU synchronization cancelled because the current investor contact is not a known member</error>
    }
    </Result>
  )
};

(: ======================================================================
   This is a console version of enterprise:update-scaleup-individual
   Note: user Email should not have been edited because the LastEmail 
   part of the protocol is not implemented here
   ====================================================================== 
:)
declare function local:scaleup-update-individual( $account as element(), $role as xs:string) {
  let $legacy := $account//Role[FunctionRef = $role]
  (: User can be at the same time facilitator and monitor - so we must use 'r' parameter and don't a multiple $legacy :)
  (:let $target-role := request:get-parameter('r', string($legacy)):)
  let $target-role := $role
  let $cat := if ($target-role eq '10') then
                'facilitator'
              else if ($target-role eq '11') then
                'monitor'
              else
                'UNKNOWN'
  return
    local:serialize(
      <Result>
        {
        let $payload := template:gen-document('scaleup-individual-wstoken', 'update', $account, $account//TokenHistory[@For eq 'ScaleupEU']/TokenRequest,<Form><Operation>update</Operation><Category>{ $cat }</Category></Form>)
        return
          (
          <Request><Payload>{ $payload }</Payload></Request>,
          <Response>
            {
            if (local-name($payload) ne 'error') then
              let $last := $account//TokenHistory[@For eq 'ScaleupEU']/TokenRequest
              let $res := services:post-to-service('invest', 'invest.end-point', $payload, ("200", "###"))
              return (
                $res,
                if (local-name($res) ne 'error') then (
                  if (exists($last)) then
                    template:do-update-resource('token-allocate', (), $last, (), <Form>{ $account/Information/Contacts/Email }</Form>)
                  else
                    template:do-create-resource('individual-token', $account, (), <Form>{ $account/Information/Contacts/Email }</Form>, ()),
                  (: create / change role in addition :)
                  if ($target-role = ('10', '11') and not($target-role = $legacy/FunctionRef)) then
                    if ($legacy/FunctionRef) then
                      update value $legacy/FunctionRef with $target-role
                    else 
                      let $role := <Role>
                                     <FunctionRef>{ $target-role }</FunctionRef>
                                   </Role>
                      return
                        if (exists($account/UserProfile/Roles)) then
                          update insert $role 
                          into $account/UserProfile/Roles
                        else
                          update insert <Roles>{ $role }</Roles>
                          into $account/UserProfile
                  else
                    ()
                  )
                else
                  ()
                )
            else
              $payload
            }
          </Response>
          )
        }
      </Result>
  )
};

(: ======================================================================
   Force an Update (when token is allocated)
   ====================================================================== 
:)
declare function local:update-token( $enterprise-ref as xs:string ) {
  let $enterprise := fn:collection('/db/sites/cockpit/enterprises')/Enterprise[Id eq $enterprise-ref]
  return
    <div>
      <p style="font-weight:bold">Update report</p>
      <ul>
      {
        if (exists($enterprise)) then
          let $account := enterprise:get-token-owner-person-for($enterprise)
          return
            if (exists($account)) then
              <li>updating <a href="../../enterprises/{ $enterprise/Id }" target="_blank">{ $enterprise/Information/Name/text() }</a> (<i>Payload</i> has been sent to the 3rd part service)<br/>
              { local:scaleup-update($enterprise, $account) }
              </li>
            else
              <li>no token allocated in { $enterprise/Information/Name/text() }, use the <a href="../../teams">/teams</a> page to allocate one first</li>
        else
          <li>enterprise { $enterprise-ref } unknown</li>
      }
      </ul>
      <p>Back to <a href="console">list</a></p>
    </div>
};

(: ======================================================================
   Force an Update of a facilitator or monitor
   ====================================================================== 
:)
declare function local:update-individual( $mail as xs:string, $role as xs:string ) {
  let $account := fn:collection('/db/sites/cockpit/persons')/Person[Information/Contacts/Email eq $mail]
  return
    <div>
      <p style="font-weight:bold">Update report</p>
      <ul>
      {
        if (exists($account)) then
          <li>updating <a>{ string-join($account/Information/Name/*, ' ') }</a> (<i>Payload</i> has been sent to the 3rd part service)<br/>
          { local:scaleup-update-individual($account ,$role) }
          </li>
        else
          <li>user { $mail } unknown</li>
      }
      </ul>
      <p>Back to <a href="console">list</a></p>
    </div>
};

let $crlf := codepoints-to-string((13, 10))
let $delete-c := request:get-parameter('dc', ()) (: company account user email :)
let $delete-i := request:get-parameter('di', ()) (: individual account user email :)
let $update := request:get-parameter('u', ()) (: enterprise id :)
let $error := request:get-parameter('error', ()) (: error :)
let $role := request:get-parameter('r', ()) (: role facilitator or monitor :)
return
  <html>
    <h2>SMED Token Console</h2>
    {
    if (empty($delete-c) and empty($delete-i) and empty($update) and empty($error)) then
      local:list-all()
    else (
      if ($delete-c) then
        local:delete-token($delete-c)
      else if ($delete-i) then
        local:delete-individual($delete-i)
      else
        (),
      if ($update) then
        if (contains($update, '@')) then
          local:update-individual($update, $role)
        else
          local:update-token($update)
      else
        (),
      if ($error) then
        local:gen-scaleup-error()
      else
        ()
      )
    }
  </html>
