xquery version "3.0";
(: ------------------------------------------------------------------
   SMEi ccmatch

   Authors: Franck Leplé <franck.leple@amplexor.com>

   Web Services for EIC Community on platform

   April 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace community = "http://oppidoc.com/ns/application/community";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "drupal.xqm";

declare variable $community:persons := globals:collection('persons-uri');


(: ======================================================================
   Call bootstrap service 
   Be careful, control if BasicAuthentification is used
   <headers>
      <header name="Authorization" value="Basic {$credentials}"/>
    </headers>
   ====================================================================== 
:)
declare function community:do-bootstrap-coach($coach as element(), $lang as xs:string) as element()?
{
  let $payload := community:gen-bootstrap-payload($coach, $lang)
  return
    (: BE careful, bootstrap a coach is different than bootstrap an organisation  :)
    if (exists(fn:collection($globals:persons-uri)//Person/EICCommunity)) then
      let $res := drupal:put-to-service('community', 'bootstrap', $payload, "200", concat('/', 'c1'))
      return
        $res
    else
      let $res := drupal:post-to-service('community', 'bootstrap', $payload, "200")
      return
        $res
};

(: ======================================================================
   Call update organisation service 
   Be careful, control if BasicAuthentification is used
   <headers>
      <header name="Authorization" value="Basic {$credentials}"/>
    </headers>
   ====================================================================== 
:)
declare function community:do-update-coach($coach as element(), $lang as xs:string) as element()?
{
  let $payload := community:gen-bootstrap-payload($coach, $lang)
  return
    let $res := drupal:put-to-service('community', 'bootstrap', $payload, "200", concat('/', 'c1'))
    return
      $res
};

(: ======================================================================
   Call update organisation service  with reset payload
   
   <headers>
      <header name="Authorization" value="Basic {$credentials}"/>
    </headers>
   ====================================================================== 
:)
declare function community:do-reset-dummy-organisation($coach as element(), $lang as xs:string) as element()?
{
  let $payload := community:gen-reset-dummy-organisation-payload($coach, $lang)
  return
    let $res := drupal:put-to-service('community', 'bootstrap', $payload, "200", concat('/', 'c1'))
    return
      $res
};


(: 
   ======================================================================
              Payload generation's functions
   ======================================================================
:)

(: ======================================================================
   Used by the payload generation for the community bottstrap/update service
   Generate the organisation content wihtout member
   
   PARAMETERS:
    - coach
   ======================================================================
:)
declare function community:gen-bootstrap-payload-without-member($lang as xs:string?) as element()
{
  <Node>
    <!-- Token to authorize -->
    { drupal:get-authorization-token ('community') }
    <!-- Drupal entity bundle name (Mandatory) -->
    <type>organisation</type><!-- The name of the organisation -->
    
    <!-- The name of the organisation -->
     <title>Coaches - Bootstrap Organisation</title>
     
    <!-- Id of the organisation -->
     <c4m_organisation_dashboard_id>
        <und is_array="true">
            <item>
                <value>c1</value>
            </item>
        </und>
    </c4m_organisation_dashboard_id>
    
    <!-- Type of organisation (term IDs to be defined) -->
    <c4m_organisations_type>
        <und is_array="true">
            <tid>30</tid>
        </und>
    </c4m_organisations_type>
    
    <!-- Size of organisation (micro, small, medium, large, other) -->
    <c4m_organisation_size>
        <und is_array="true">
            <value>micro</value>
        </und>    
    </c4m_organisation_size>
    
    <!-- URL of the organisations website -->
    <c4m_link>
        <und is_array="true">
            <item>
                <url>http://ec.europa.eu/easme</url>
            </item>
        </und>
    </c4m_link>
    
    <c4m_vocab_geo>
      <und is_array="true">
        <tid>BEL</tid>     
      </und>
    </c4m_vocab_geo>
    
    <!-- Compound field to define the location address of the organisation -->
     <c4m_location_address>
        <und is_array="true">
            <item>
                <country>BE</country>
                <locality>Bruxelles</locality>
                <postal_code>1000</postal_code>
                <thoroughfare>Covent Garden 2, Pl. Rogier 16</thoroughfare>
                <premise/>
                <organisation_name>Coaches - Bootstrap Organisation</organisation_name>
            </item>
        </und>
    </c4m_location_address>
          
    <!-- Organisations Contacts members + Contact phone and contact email  -->
    <c4m_email>
      <und is_array="true">
        <item>
          <email>yassen.todorov@ec.europa.eu</email>
        </item>
      </und>
    </c4m_email>
    <c4m_phone>
      <und is_array="true">
         <item><value>99037</value></item>
      </und>
    </c4m_phone>
    <c4m_contact_persons>
        <und is_array="true">
          <ecas_id>todorya</ecas_id>
          <first_name>Yassen</first_name>
          <last_name>Todorov</last_name>
          <email>yassen.todorov@ec.europa.eu</email>
          <c4m_user_types>
            <und is_array="true">
              <tid>2</tid>
            </und>
          </c4m_user_types>
        </und>
    </c4m_contact_persons>  
     <!-- Date (year) of establishment -->
    <c4m_date_est>
        <und is_array="true">
            <item>
                <value>
                    <date>2018</date>
                </value>
            </item>
        </und>
    </c4m_date_est>
   
  
    <!-- URL slug for the new organisation in the community platform (e.g.
         https://community-smei.easme-web.eu/new-organisation-title) -->
     <purl>
        <value>coaches_bootstrap_organisation_c1</value>
    </purl> 
 </Node>
};
(: ======================================================================
   Generates the payload for the community bottstrap/update service
   Generate the organisation content with member
   
   PARAMETERS:
    - coach
   ======================================================================
:)
declare function community:gen-bootstrap-payload($coach as element(), $lang as xs:string?)
{
  try{ 
    <node>
    
    { 
      let $content := community:gen-bootstrap-payload-without-member($lang)
      return
        $content/*  
    } 
    
    <!-- Member of the organisation -->
    <!-- The coach -->
    {
      if (exists($coach)) then
        <c4m_organisation_members>
          <und is_array="true">
          <item>
           <ecas_id>{ $coach//Remote[@Name = 'ECAS']/text() }</ecas_id>
           <first_name>{ $coach/Information/Name/FirstName/text() }</first_name>
           <last_name>{ $coach/Information/Name/LastName/text() }</last_name>
           <email>{$coach/Information/Contacts/Email/text()}</email>
           <c4m_user_types>
            <und is_array="true">
              <tid>6</tid>  
            </und>
           </c4m_user_types>
           { 
            if (exists($coach/Knowledge/SpokenLanguages/EU-LanguageRef)) then
              <c4m_vocab_language>
                <und is_array="true">
                {
                    for $language in $coach/Knowledge/SpokenLanguages/EU-LanguageRef
                      return <value>{ $language/text() }</value> 
                }
                </und>
              </c4m_vocab_language>
            else ()
          }
          </item>
          </und>
        </c4m_organisation_members>
      else
        ()
    }
    
    </node>
  }
  catch * 
  {
    <node>
      { drupal:get-authorization-token ('community') }
       <Error>{ 'Error [' || $err:code || ']: ' || $err:description || ' - ' || $err:value }</Error>
    </node>
  }
};
(: ======================================================================
   Generates the reset payload for the dummy organisation (without member)
   
   PARAMETERS:
    - coach
   ======================================================================
:)
declare function community:gen-reset-dummy-organisation-payload($coach as element(), $lang as xs:string?)
{
  try{ 
    <node>
    { 
      let $content := community:gen-bootstrap-payload-without-member($lang)
      return
        $content/*  
    } 
    </node>
  }
  catch * 
  {
    <node>
      { drupal:get-authorization-token ('community') }
       <Error>{ 'Error [' || $err:code || ']: ' || $err:description || ' - ' || $err:value }</Error>
    </node>
  }
};

(: 
   ======================================================================
              Response decode/analysis functions
   ======================================================================
:)

(: 
   =====================================================================
   Description
    encode propely the error message
   ======================================================================
:)
declare function local:generate-cleanup-msg($code as xs:string, $description as xs:string, $date as xs:string, $result as element()?) as element() {
  <error>
     <code>{ $code }</code>
     <description>{ $description}</description>        
     <date>{ concat("", $date) }</date>
     { $result }
   </error>
};

(: 
   ======================================================================
   Description
    If a bootstrap failed an error 500 may occur
    The Organisation may be created but the company in SMED is not align with Drupal 
   
   Parameters:
    $coach: Coach bootstraped
    $result: Content of the http response
    $one: c4m_organisation_dashboard_id part of the result
   
   return:
    An xml well-formed status with messages
   ======================================================================
:)
declare function community:recovery-error-process($coach as element() ,$service as xs:string, $result as element(), $date as xs:string, $lang as xs:string) as element() {
  let $content := $result
  let $one := $content/organisation_node_exists
  let $nid := $one/nid
  let $uri := $one/uri
  return
    if (exists($one/c4m_organisation_dashboard_id[text() eq $coach/Id/text()])) then
      let $clearResponse :=
        <success>
        {
        <code>200</code>,
        <description>Recovery processus - get EIC Community Organisation's ID and URI - launch Organisation's update</description>,
        $nid,
        $uri,
        <date>{ concat("", $date) }</date>,
        $result
        }
        </success>
      return
        (community:update-coach-community-status($coach, $service, $clearResponse),
         community:decode-service-response($coach, 'update',community:do-update-coach($coach, $lang), $lang))[2]
    else
      let $clearResponse :=  local:generate-cleanup-msg("500", "Organisation already exists (EIC Community message)", $date, $result)  
      return
      community:update-coach-community-status($coach, $service, $clearResponse)   
};

(: 
   ======================================================================
   Description
    - Response decode/analysis functions
    - Update the $coach (stamp)
    - Historification 
    - Return an xml message 
   
   Parameters:
    the <httpclient:response> element
   
   return:
    An xml well-formed status with messages
    
    FIXME: Solve hard-coding messages
   ======================================================================
:)

declare function community:decode-service-response($coach as element(), $service as xs:string, $response as element(), $lang as xs:string) as element() {
  (: get status code :)
  let $error-message := if (local-name($response) eq 'error') then $response else ()
  return
  if (exists($error-message)) then
    (: Service configuration problem   :)
    let $statusCode := $response/@status
    let $date := string(current-time())
    let $clearResponse :=  local:generate-cleanup-msg($statusCode, "EIC Community Web Service configuration problem.", $date, $response)    
    return
      community:update-coach-community-status($coach, $service, $clearResponse)
  else
    let $statusCode := $response/@statusCode
    let $returnDate := $response//httpclient:header[@name eq 'Date']/@value
    let $date := if (exists($returnDate)) then $returnDate else string(current-time())
    let $result := $response/httpclient:body/result
    return
      (: Error recovery process  :)
      (: The preceding bootstrap failed but organisation was created on drupal side  :)
      if (($statusCode eq '500') and exists($result/organisation_node_exists) and (not(exists($coach/EICCommunity/Bootstrap[@status eq 'success'])))) then
        community:recovery-error-process($coach, $service, $result, $date, $lang)
      (: analysis result :)
      else
      if ($statusCode eq '200') then
        let $nid := $result/nid
        let $uri := $result/uri
        return
          let $clearResponse :=
           <success>
             {
               <code>200</code>,
               $nid,
               $uri,
               <date>{ concat("", $date) }</date>,
               $result
             }
           </success>
           return
           community:update-coach-community-status($coach, $service, $clearResponse)
      else if ($statusCode eq '204') then  
        let $clearResponse :=  local:generate-cleanup-msg("204", "No Content (EIC Community message)", $date, $result)  
        return
        community:update-coach-community-status($coach, $service, $clearResponse)   
      else if ($statusCode eq '304') then
        let $clearResponse :=  local:generate-cleanup-msg("304", "Not Modified (EIC Community message)", $date, $result)            
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
      else if ($statusCode eq '401') then
        let $clearResponse :=  local:generate-cleanup-msg("401", "Unauthorized access (EIC Community message)", $date, $result)      
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
      else if ($statusCode eq '403') then
        let $clearResponse :=  local:generate-cleanup-msg("403", "Unauthorized access (EIC Community message)", $date, $result)                
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
      else if ($statusCode eq '404') then
        let $clearResponse :=  local:generate-cleanup-msg("404", "Not found (EIC Community message)", $date, $result)          
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
      else if ($statusCode eq '406') then
        let $clearResponse :=  local:generate-cleanup-msg("406", "Not Acceptable (EIC Community message)", $date, $result)   
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
      else if ($statusCode eq '500') then
        let $clearResponse :=  local:generate-cleanup-msg("500", "Internal Server Error - The server encountered an unexpected condition which prevented it from fulfilling the request.", $date, $result)    
        return
        community:update-coach-community-status($coach, $service, $clearResponse)         
      else if ($statusCode eq '503') then
        let $clearResponse :=  local:generate-cleanup-msg("503", "EIC Community is currently under maintenance. We should be back shortly. Thank you for your patience.", $date, $result)    
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
      else if ($statusCode eq '504') then
        let $clearResponse :=  local:generate-cleanup-msg("504", "EIC Community is not responding before timeout.", $date, $result)    
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
      else
        let $clearResponse :=  local:generate-cleanup-msg($statusCode, "Unknow error code", $date, $result)           
        return
        community:update-coach-community-status($coach, $service, $clearResponse)
};

(: 
   ======================================================================
              Historisation functions
   ======================================================================
:)

(: 
   ======================================================================
   Description
    - Update the coach (stamp)
    - For the bootstrap process
      
   Parameters:
    the coach
   ======================================================================
:)
declare function community:update-coach-status-bootstrap($coach  as element(), $service as xs:string, $response as element()) as element() {
  let $vocabulary := (if ($response/code/text() eq '200') then 'success' else 'error')
  return
    if (not(exists($coach/EICCommunity/Bootstrap[@status eq 'success']))) then
     let $res := template:do-update-resource-no-uid(concat("community-coach-bootstrap-", $vocabulary), (), $coach, $response, <form/>)
     return  
       <return>
          <service-response>{ $response }</service-response>
          <database-update>{ $res }</database-update>
      </return>
     else
      <return>
        <service-response><message>Boostrap already done and successful</message></service-response>
      </return>
};

(: 
   ======================================================================
   Description
    - Update the coach (stamp)
    - For the update process
      
   Parameters:
    the coach
   ======================================================================
:)
declare function community:update-coach-status-update($coach  as element(), $service as xs:string, $response as element()) as element() {
  let $vocabulary := (if ($response/code/text() eq '200') then 'success' else 'error')
  return
     let $res := template:do-update-resource-no-uid(concat("community-coach-update-", $vocabulary), (), $coach, $response, <form/>)
     return  
       <return>
          <service-response>{ $response }</service-response>
          <database-update>{ $res }</database-update>
      </return>
     (:else
      <return>
        <message>Update already done and successful!</message>
      </return>:)
};


(: 
   ======================================================================
   Description
    - Update the coach (stamp)
    - For the bootstrap or update process process
      
   Parameters:
    the coach
    
   FIXME: Concatenation of errors message (Template + WS)
   FIXME: ERROR management
   ======================================================================
:)

declare function community:update-coach-community-status($coach  as element(), $service as xs:string, $response as element()) as element() {
  let $vocabulary := (if ($response/code/text() eq '200') then 'success' else 'error')
  return
    if (not(exists($coach/EICCommunity))) then
      let $resCreation := template:do-create-resource-no-uid('community-coach-eiccommunity', $coach, $response, <form/>, ())
      return
        if ($service eq 'bootstrap') then
          community:update-coach-status-bootstrap($coach, $service, $response) 
        else
          community:update-coach-status-update($coach, $service, $response)
    else 
      if ($service eq 'bootstrap') then
        community:update-coach-status-bootstrap($coach, $service, $response) 
      else
        community:update-coach-status-update($coach, $service, $response)
};

(: 
   ======================================================================
   Description
    - reset the coach EICCommunity content
      
   Parameters:
    the coach
   ======================================================================
:)
declare function community:reset-coach-community-status($coach  as element()) as element() {
  if (exists($coach/EICCommunity)) then
      let $resReset := template:do-delete-resource('community-coach-eiccommunity', $coach, ())
      return
        <return><database-update>{ $resReset }</database-update></return>
  else
   <return><database-update>No need to update database, EICCommunity is already suppressed/emptied</database-update></return>
};


