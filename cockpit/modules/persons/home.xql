xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Individualized landing page for users or for EASME staff

   Shows top-level mosaic menu

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../../xcm/lib/database.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Implement ScaleupEU Actions element of the $custom:menus structure
   Either generate SubTitle element to insert in Tile to link to ScaleupEU
   or generate a Token widget
   ======================================================================
:)
declare function local:gen-actions( $enterprise as element(), $option as element(), $actions as element()?, $person-key as xs:string ) as element()* {
  let $open := $actions/Open
  let $token := $actions/Token
  return
    (: next condition should be equivalent to $last/TokenStatusRef eq '3' :)
    if ((exists($open) and ($option[@Key eq 'investors']) and access:check-entity-permissions('open', $open/@Resource, $enterprise)) and custom:check-settings('scaleup', 'mode', ('on', 'open'))) then (
      <Link>{ services:get-hook-address($open/@Service, concat($open/@Resource, '.open')) }</Link>,
      <Subtitle Link="yes">{ $open/text() }</Subtitle>
      )
    else if ((exists($open) and ($option[@Key eq 'community']) and access:check-entity-permissions('open', $open/@Resource, $enterprise)) and custom:check-settings('community', 'mode', ('on', 'open'))) then (
      <Link>{ xs:string($enterprise/EICCommunity/@uri) }</Link>,
      <Subtitle Link="yes">{ $open/text() }</Subtitle>
      )     
    else if (exists($token) and custom:check-settings('scaleup', 'mode', 'on')) then
      <Token>
        {
        let $last := enterprise:get-most-recent-request($enterprise, $person-key)
        return (
          if ($last/TokenStatusRef eq '1') then
            <Info>Your request has been recorded on { display:gen-display-date-time($last/@CreationDate) }</Info>
          else (
            if ($last/TokenStatusRef eq '2') then
              <Comment>Your last request was rejected on { display:gen-display-date-time($last/@LastModification) }</Comment>
            else if ($last/TokenStatusRef eq '4') then
              <Comment>Your access was withdrawn on { display:gen-display-date-time($last/@LastModification) }</Comment>
            else if ($last/TokenStatusRef eq '5') then
              <Comment>Your access was transferred on { display:gen-display-date-time($last/@LastModification) }</Comment>
            else
              (),
            <Request Controller="teams/{$enterprise/Id/text()}/token/{$person-key}">Request { if ($last/TokenStatusRef eq '2') then "again " else () } access to matching service</Request>
            ),
          let $cid := string($enterprise/Id) (: FIXME: while testing we got some empty() $enterprise/Id here ?!?! :)
          let $owner := enterprise:get-token-owner-person-for($enterprise)
          return
            if ($owner and ($owner/Id ne $person-key)) then
              let $m := $enterprise/Team//Member[PersonRef eq $owner/Id]/Information/Name
              return
                <Comment>Access is currently granted to { concat($m/FirstName, ' ', $m/LastName) }</Comment>
            else
              ()
          )
        }
      </Token>
    else
      ()
};

(: ======================================================================
   Implement Todos element of the $custom:menus structure
   Generate SubTitle element to insert in Tile
   ======================================================================
:)
declare function local:gen-todos( $enterprise as element(), $todos as element()? ) as element()? {
  let $uid := oppidum:get-current-user()
  let $groups := oppidum:get-current-user-groups()
  return
    (
    for $label in $todos/Label
    order by $label/@Prior ascending
    return
      for $content in $label/Content
      where (not($content/@Role) or string($content/@Role) = $groups)
      return
      <Subtitle>
        {
        for $child in $content/node()
        return
        typeswitch($child)
          case text() return $child
          case element()
          return
            if (local-name($child) = 'XPath') then
              let $res := 
                util:eval(
                  concat(
                    $content/@Agg, '(', 
                    if ($content/@Context) then 
                      $content/@Context
                    else
                      concat('fn:collection($globals:',$content/@Collection,'-uri)'),
                    $child/text()  ,')'))
              return
                if (number($res) eq 0) then
                  <NotDisplayable/>
                else
                  $res
            else
              ()
          default return <Error name="{local-name($child)}"/>
        }
      </Subtitle>
    )[not(NotDisplayable)][1]
};

(: ======================================================================
   A non-staff and affiliated user can view only his/her companies
   Users having a potentially unaffiliated role can access subsets 
   of a multi dashboard
   ====================================================================== 
:)
declare function local:get-enterprise( $cmd as element(), $staff as xs:boolean, $unaffiliated as xs:boolean, $name as xs:string, $uid as xs:string ) as element()? {
  if (matches($name, '^\d+$')) then (: Company Dashboard viewing :)
    let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $name]
    let $access := access:get-entity-permissions('view', 'Enterprise', $enterprise) (: FIXME: 'Dashboard' ? :)
    return
      if (local-name($access) eq 'allow') then
        $enterprise
      else
        $access
  else if ($staff) then
    (: staff always belongs to EASME (Id 1) per construction 
       fake EASME for other unaffiliated users :)
    fn:collection($globals:enterprises-uri)//Enterprise[Id eq '1']
  else if ($unaffiliated) then
    <Unaffiliated/>
  else (: Redirection to Company Dashboard, to switch page or to error message :)
    let $enterprise := enterprise:get-my-enterprises()
    let $valid := fn:filter($enterprise, function ($x) { enterprise:is-valid($x) } )
    let $projects := fn:filter($valid, function ($x) { enterprise:has-projects($x) } )
    return
      if (empty($enterprise)) then
        oppidum:throw-error('NOT-MEMBER-ERROR', ())
        (: FIXME: logout and show same message as with <Check Email="notfound"/> in login procedure ? :)
      else if (exists($valid)) then
        if (exists($projects) or enterprise:is-a($enterprise, 'Investor')) then
          if (count($projects) > 1) then
            <Redirected>{ oppidum:redirect(concat($cmd/@base-url, 'switch')) }</Redirected>
          else
            <Redirected>{ oppidum:redirect(concat($cmd/@base-url, $enterprise/Id)) }</Redirected>
        else
          oppidum:throw-error('NO-RUNNING-PROJECTS', string-join($enterprise/Information/ShortName, ', '))
      else
        oppidum:throw-error('NO-VALID-ENTERPRISES', string-join($enterprise/Information/ShortName, ', '))
};

declare function local:gen-user-label( $staff as xs:boolean, $groups as xs:string* ) {
  if ($staff) then 
    'EASME staff'
  else 
    let $roles := fn:collection($globals:global-info-uri)//Description[@Role = 'normative']/Selector[@Name eq 'Functions']//Option[@Role = $groups]
    return
      if (count($roles) eq 1) then
        $roles/Name/text()
      else
        string-join($roles/Brief, ', ')
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $profile := user:get-user-profile()
let $person := $profile/parent::Person
let $groups := oppidum:get-current-user-groups()
let $staff := $groups = ('admin-system', 'project-officer', 'developer', 'dg')
let $unaffiliated := not($staff) and $groups = ('events-manager', 'facilitator', 'monitor')
let $enterprise := local:get-enterprise($cmd, $staff, $unaffiliated, $cmd/resource/@name, $person/Id) 
let $multi := ($staff or $unaffiliated) and not(matches($cmd/resource/@name, '^\d+$')) (: multi dashboard view :)
return
  if (local-name($enterprise) ne 'error') then 
    let $title := custom:gen-enterprise-title($enterprise)
    let $is-a-een := enterprise:is-a($enterprise, 'EEN')
    return
      <Page StartLevel="1" skin="fonts extensions">
        <Window>SME Dashboard of { if ($multi) then local:gen-user-label($staff, $groups) else $title }</Window>
        <Model>
          <Navigation>
            <Mode>dashboard</Mode>
            <Name>{ if ($is-a-een) then attribute { 'Satellite' } { 'EEN host organisation' } else () }Welcome to SME Dashboard of { if ($multi) then local:gen-user-label($staff, $groups) else $title }</Name>
            { 
            if (not($multi) and $staff and $cmd/@mode eq 'dev') then
              (: FIXME: migrate /rest mapping to Oppidum low level API :)
              <REST>
                { 
                concat(
                  '/exist/rest',
                  database:gen-collection-for-key (concat($cmd/@db,'/'), 'enterprise', $enterprise/Id),
                  '/', $enterprise/Id, '.xml')
                }
              </REST>
            else
              ()
            }
          </Navigation>
        </Model>
        <Content>
          <Mosaic>
            {
              let $menu :=
                if ($multi) then (: FIXME: custom:get-dashboard-for-group ? :)
                  if ($groups = 'dg') then
                    'dg'
                  else if ($staff) then 
                    'multi'
                  else
                    'unaffiliated'
                else if ($is-a-een) then
                  'een'
                else
                  'single'
              return
                for $opt in $custom:menu//Menu[@Id eq $menu]/Option
                let $on := empty($opt/@Group) or tokenize($opt/@Group, ' ') = $groups
                return
                  <Tile loc="nav.{ $opt/@Key }">
                    {
                    if ($on) then
                      if ($opt/@Mapping) then
                        <Link>{ concat($opt/@Mapping, '/', $enterprise/Id) }</Link>
                      else if ($opt/@Path) then
                        <Link>{ string($opt/@Path) }</Link>
                      else if ($opt/Actions) then
                        local:gen-actions($enterprise, $opt, $opt/Actions, $person/Id)
                      else
                        ()
                    else
                      (),
                    local:gen-todos($enterprise, $opt/Todos)
                    }
                  </Tile>
            }
          </Mosaic>
        </Content>
      </Page>
  else
    $enterprise
