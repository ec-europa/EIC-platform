xquery version "3.0";
(: ------------------------------------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: Franck Leplé <franck.leple@amplexor.com>

   Web Services for EIC Community on platform

   April 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace community = "http://oppidoc.com/ns/application/community";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "drupal.xqm";

declare variable $community:enterprises := globals:collection('enterprises-uri');
declare variable $community:persons := globals:collection('persons-uri');

(: 
   ======================================================================
              Payload generation's functions
   ======================================================================
:)

(: ======================================================================
   Generate drupal structure for contact persons in a company
   + Phone and email
   Parameters:
     - $enterprise: The company
     - $kind: contact, phone, email
   ======================================================================
:)
declare function local:gen-company-contact-informations($enterprise as element(), $lang as xs:string?) as element()* {
  let $cie-ref := $enterprise/Id
  let $cur-lear := $community:persons//Person[.//Role[EnterpriseRef eq $cie-ref][ FunctionRef eq '3']]
  return
    if (count($cur-lear) > 0) then
      <c4m_contact_persons>
        <und is_array="true">
          {
            for $account in $cur-lear
            return
              let $mem := $enterprise//Member[PersonRef/text() eq $account/Id/text()]
              return
                if (exists($mem) and not($account/UserProfile/Blocked) and not($mem/Rejected)) then
                  (:template:gen-read-model("community_company_contact", $enterprise, $account, $lang):)
                  template:gen-read-model("community_company_member", $mem, $account, $lang)
                else ()
          }
        </und>
      </c4m_contact_persons>
    else
   ()
};

(: ======================================================================
   Generate drupal structure for members persons in a company
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-members($enterprise as element(), $lang as xs:string?) as element()* {
  let $members := $enterprise//Member
  return
    if (count($members) > 0) then
    <c4m_organisation_members>
      <und is_array="true">
        {
          for $mem in $members
          return
            let $account := fn:collection($globals:persons-uri)//Person[Id/text() eq $mem/PersonRef/text()]
            return
             (:if (not($account/UserProfile/Blocked) and not($mem/Rejected) and exists($account//Role[EnterpriseRef eq $enterprise/Id/text()])) then:)
             if (exists($account) and not($account/UserProfile/Blocked) and not($mem/Rejected) and not($account/UserProfile//FunctionRef[text() eq '9'])) then
                template:gen-read-model("community_company_member", $mem, $account, $lang)
              else ()
        }
      </und>
    </c4m_organisation_members>
    else
    ()
};

(: ======================================================================
   Generate drupal structure for targeted markets in a company
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-targeted-markets($enterprise as element(), $lang as xs:string?) as element()* {
  let $tmrs := $enterprise//TargetedMarketRef
  return
    if (count($tmrs) > 0) then
    <c4m_target_markets>
      <und is_array="true">
        { 
          for $tmr in $tmrs
          return        
            template:gen-read-model("community_company_target_market", $tmr, $lang) 
        }
      </und>
    </c4m_target_markets>
    else
      ()
};

(: ======================================================================
   Generate drupal structure for company size
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-size($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/SizeRef[text() ne ''])) then
    template:gen-read-model("community_company_size", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for company web site
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-url($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/WebSite[text() ne ''])) then
    template:gen-read-model("community_company_url", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for company other countries/Cities based in
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-countries_cities($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/Address/Country) or exists($enterprise/Information/Address/ISO3CountryRef)) then
    template:gen-read-model("community_company_countries_cities", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for company countries selling to
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-selling_to($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/Address/Country) or exists($enterprise/Information/Address/ISO3CountryRef) or exists($enterprise/Information/CountriesSellingTo/ISO3166Countries/ISO3166CountryRef)) then
    template:gen-read-model("community_countries_selling_to", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for company contact mail
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-contact_email($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/Contacts/Email)) then
    template:gen-read-model("community_company_contact_email", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for company contact phone
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-contact_phone($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/Contacts/Phone) or exists($enterprise/Information/Contacts/Mobile)) then
    template:gen-read-model("community_company_contact_phone", $enterprise, $lang)
  else ()
};


(: ======================================================================
   Generate drupal structure for company date
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-date($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/CreationYear[text() ne ''])) then
    template:gen-read-model("community_company_date", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for Product offering (Industry/NACE/DomainActivity)
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-offering($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/ServicesAndProductsOffered/DomainActivities/DomainActivityRef[text() ne ''])) then
    template:gen-read-model("community_company_offering", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for Topic(s) Topics/TopicRed to c4m_vocab_topic
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-topics($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/ThematicsTopics/ThematicsTopicRef[text() ne ''])) then
    template:gen-read-model("community_company_topics", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for Topic(s)Clients/ClientRef to c4m_product_service_type
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-product-service-types($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/Clients/ClientRef[text() ne ''])) then
    template:gen-read-model("community_company_product_service_type", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generate drupal structure for ServicesAndProductsLookingFor/DomainActivities/DomainActivityRef to c4m_customers
   Parameters:
     - $enterprise: The company
   ======================================================================
:)
declare function local:gen-company-looking-for($enterprise as element(), $lang as xs:string?) as element()* {
  if (exists($enterprise/Information/ServicesAndProductsLookingFor/DomainActivities/DomainActivityRef[text() ne ''])) then
    template:gen-read-model("community_company_looking_for", $enterprise, $lang)
  else ()
};

(: ======================================================================
   Generates the payload for the community bottstrap service 
   FIXME: for 1 use cache entries could be tailored to fit 1 profile
   TODO: 
   PARAMETERS:
    - Company
   ======================================================================
:)
  
  
declare function community:gen-bootstrap-payload($enterprise as element(), $lang as xs:string?)
{
  try{
    let $persons := fn:collection($globals:persons-uri)//Person
    let $personsWithout := fn:collection($globals:persons-uri)//Person[not(descendant::Remote)]
    return
  
    <node>
    <!-- Token to authorize -->
    { drupal:get-authorization-token ('community') }
    <!-- Drupal entity bundle name (Mandatory) -->
    { template:gen-read-model("community_company_organisation_type", $enterprise, $lang) }
    <!-- The name of the organisation -->
    { template:gen-read-model("community_company_name", $enterprise, $lang) }
    <!-- Id of the enterprise -->
    { template:gen-read-model("community_company_id", $enterprise, $lang) }
    <!-- Type of organisation (term IDs to be defined) -->
    { template:gen-read-model("community_company_type", $enterprise, $lang) }
    <!-- Size of organisation (micro, small, medium, large, other) -->
    { local:gen-company-size($enterprise, $lang) }
    <!-- URL of the organisations website -->
    { local:gen-company-url($enterprise, $lang) }
    <!-- Compound field to define the location address of the organisation -->
    { template:gen-read-model("community_company_adress", $enterprise, $lang) }
    <!-- Other countries/Cities based in : Managed in Drupal Only, used for the bootstraping  -->
    { local:gen-company-countries_cities($enterprise, $lang) } 
    <!-- Countries selling to cf. SMEIMKT-893 -->
    { local:gen-company-selling_to($enterprise, $lang) } 
    <!-- Targeted Markets c4m_target_markets -->
    { local:gen-company-members($enterprise, $lang) }  
    <!-- Organisations Contacts members + Contact phone and contact email  -->
    { local:gen-company-contact_email($enterprise, $lang) }
    { local:gen-company-contact_phone($enterprise, $lang) }
    { local:gen-company-contact-informations($enterprise, $lang) }    
     <!-- Date (year) of establishment -->
    { local:gen-company-date($enterprise, $lang) } 
    <!-- Type of products/services offered (b2b and/or b2c) -->
    { local:gen-company-product-service-types($enterprise, $lang) } 
    <!-- Organisations Members -->
    { local:gen-company-targeted-markets($enterprise, $lang) } 
    <!-- Thematic Topic(s) = c4m_vocab_topic  cf. SMEIMKT-893 -->
    { local:gen-company-topics($enterprise, $lang) }
  
    <!-- Products/services looking for gen-company-contact_emailcf. SMEIMKT-893  -->
    { local:gen-company-looking-for($enterprise, $lang) }
    <!-- Industry = Products/services offering (term IDs to be defined) -->
    { local:gen-company-offering($enterprise, $lang) }
  
    <!-- URL slug for the new organisation in the community platform (e.g.
         https://community-smei.easme-web.eu/new-organisation-title) -->
    { template:gen-read-model("community_company_purl", $enterprise, $lang) }
    
    <!-- about us field for company cf SMEIMKT-1130-->
    { template:gen-read-model("community_company_aboutus", $enterprise, $lang) }
    
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
    $enterprise: Company bootstraped
    $result: Content of the http response
    $one: c4m_organisation_dashboard_id part of the result
   
   return:
    An xml well-formed status with messages
   ======================================================================
:)
declare function community:recovery-error-process($enterprise as element() ,$service as xs:string, $result as element(), $date as xs:string, $lang as xs:string) as element() {
  let $content := $result
  let $one := $content/organisation_node_exists
  let $nid := $one/nid
  let $uri := $one/uri
  return
    if (exists($one/c4m_organisation_dashboard_id[text() eq $enterprise/Id/text()])) then
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
        (community:update-enterprise-community-status($enterprise, $service, $clearResponse),
         community:decode-service-response($enterprise, 'update',drupal:do-update-organisation($enterprise, $lang), $lang))[2]
    else
      let $clearResponse :=  local:generate-cleanup-msg("500", "Organisation already exists (EIC Community message)", $date, $result)  
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)   
};

(: 
   ======================================================================
   Description
    - Response decode/analysis functions
    - Update the enterprise (stamp)
    - Historification 
    - Return an xml message 
   
   Parameters:
    the <httpclient:response> element
   
   return:
    An xml well-formed status with messages
    
    FIXME: Solve hard-coding messages
   ======================================================================
:)

declare function community:decode-service-response($enterprise as element(), $service as xs:string, $response as element(), $lang as xs:string) as element() {
  (: get status code :)
  let $statusCode := $response/@statusCode
  let $returnDate := $response//httpclient:header[@name eq 'Date']/@value
  let $date := if (exists($returnDate)) then $returnDate else string(current-time())
  let $result := $response/httpclient:body/result
  return
    (: Error recovery process  :)
    (: The preceding bootstrap failed but organisation was created on drupal side  :)
    if (($statusCode eq '500') and exists($result/organisation_node_exists) and (not(exists($enterprise/EICCommunity/Bootstrap[@status eq 'success'])))) then
      community:recovery-error-process($enterprise, $service, $result, $date, $lang)
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
         community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else if ($statusCode eq '204') then  
      let $clearResponse :=  local:generate-cleanup-msg("204", "No Content (EIC Community message)", $date, $result)  
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)   
    else if ($statusCode eq '304') then
      let $clearResponse :=  local:generate-cleanup-msg("304", "Not Modified (EIC Community message)", $date, $result)            
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else if ($statusCode eq '401') then
      let $clearResponse :=  local:generate-cleanup-msg("401", "Unauthorized access (EIC Community message)", $date, $result)      
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else if ($statusCode eq '403') then
      let $clearResponse :=  local:generate-cleanup-msg("403", "Unauthorized access (EIC Community message)", $date, $result)                
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else if ($statusCode eq '404') then
      let $clearResponse :=  local:generate-cleanup-msg("404", "Not found (EIC Community message)", $date, $result)          
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else if ($statusCode eq '406') then
      let $clearResponse :=  local:generate-cleanup-msg("406", "Not Acceptable (EIC Community message)", $date, $result)   
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else if ($statusCode eq '500') then
      let $clearResponse :=  local:generate-cleanup-msg("500", "Internal Server Error - The server encountered an unexpected condition which prevented it from fulfilling the request.", $date, $result)    
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)         
    else if ($statusCode eq '503') then
      let $clearResponse :=  local:generate-cleanup-msg("503", "EIC Community is currently under maintenance. We should be back shortly. Thank you for your patience.", $date, $result)    
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else if ($statusCode eq '504') then
      let $clearResponse :=  local:generate-cleanup-msg("504", "EIC Community is not responding before timeout.", $date, $result)    
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
    else
      let $clearResponse :=  local:generate-cleanup-msg($statusCode, "Unknow error code", $date, $result)           
      return
      community:update-enterprise-community-status($enterprise, $service, $clearResponse)
};

(: 
   ======================================================================
              Historisation functions
   ======================================================================
:)

(: 
   ======================================================================
   Description
    - Update the enterprise (stamp)
    - For the bootstrap process
      
   Parameters:
    the enterprise
   ======================================================================
:)
declare function community:update-company-status-bootstrap($enterprise  as element(), $service as xs:string, $response as element()) as element() {
  let $vocabulary := (if ($response/code/text() eq '200') then 'success' else 'error')
  return
    if (not(exists($enterprise/EICCommunity/Bootstrap[@status eq 'success']))) then
     let $res := template:do-update-resource-no-uid(concat("community-company-bootstrap-", $vocabulary), (), $enterprise, $response, <form/>)
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
    - Update the enterprise (stamp)
    - For the update process
      
   Parameters:
    the enterprise
   ======================================================================
:)
declare function community:update-company-status-update($enterprise  as element(), $service as xs:string, $response as element()) as element() {
  let $vocabulary := (if ($response/code/text() eq '200') then 'success' else 'error')
  return
(:    if (not(exists($enterprise/EICCommunity/Update[@status eq 'success']))) then:)
     let $res := template:do-update-resource-no-uid(concat("community-company-update-", $vocabulary), (), $enterprise, $response, <form/>)
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
    - Update the enterprise (stamp)
    - For the bootstrap or update process process
      
   Parameters:
    the enterprise
    
   FIXME: Concatenation of errors message (Template + WS)
   FIXME: ERROR management
   ======================================================================
:)

declare function community:update-enterprise-community-status($enterprise  as element(), $service as xs:string, $response as element()) as element() {
  let $vocabulary := (if ($response/code/text() eq '200') then 'success' else 'error')
  return
    if (not(exists($enterprise/EICCommunity))) then
      let $resCreation := template:do-create-resource-no-uid('community-company-eiccommunity', $enterprise, $response, <form/>, ())
      return
        if ($service eq 'bootstrap') then
          community:update-company-status-bootstrap($enterprise, $service, $response) 
        else
          community:update-company-status-update($enterprise, $service, $response)
    else 
      if ($service eq 'bootstrap') then
        community:update-company-status-bootstrap($enterprise, $service, $response) 
      else
        community:update-company-status-update($enterprise, $service, $response)
};

(: 
   ======================================================================
   Description
    - reset the enterprise EICCommunity content
      
   Parameters:
    the enterprise
   ======================================================================
:)
declare function community:reset-enterprise-community-status($enterprise  as element()) as element() {
  if (exists($enterprise/EICCommunity)) then
      let $resReset := template:do-delete-resource('community-company-eiccommunity', $enterprise, ())
      return
        <return><database-update>{ $resReset }</database-update></return>
  else
   <return><database-update>No need to update database, EICCommunity is already suppressed/emptied</database-update></return>
};


