xquery version "3.1";

(: --------------------------------------
   EIC Community Administration Console
   -------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace community = "http://oppidoc.com/ns/application/community" at "community.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "drupal.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace tasks = "http://oppidoc.com/ns/application/tasks" at "../tasks/tasks.xqm";


(: ======================================================================
    Description:
      return true if $id is in $r
   ====================================================================== 
:)
declare function local:is-in-range($id as xs:string, $r as xs:string) as xs:boolean {
  if ($r eq '-1') then
    true()
  else 
    let $i := xs:integer($id)
    let $start := tokenize($r, '-')[1]
    let $end := tokenize($r, '-')[last()]
    return
      if (($i >= xs:integer($start)) and ($i <= xs:integer($end))) then
        true()
      else
        false()
};

(: ======================================================================
    Description:
     Generate a listing table for a kind of enterprise
      | Enterprise name | Enterprise last modification | Bootstrap status | Update status | Actions (Bootstrap, Update)
   ====================================================================== 
:)

declare function local:fetch-enterprises($listing as xs:string, $r as xs:string, $status as xs:string) {
   let $list_e := for $e in fn:collection('/db/sites/cockpit/enterprises')//Enterprise
    order by xs:integer($e/Id) ascending
  let $isInvestor := enterprise:is-a($e, 'Investor')
  (:let $isSME := (((empty($e/ValidationStatus/CompanyTypeRef)) or ($e/ValidationStatus/CompanyTypeRef = '1')) and not($e/Settings/Teams = 'Investor')):)
  let $isSME := (enterprise:is-a($e, 'Beneficiary') and not($isInvestor))
  let $eic := $e/EICCommunity
  let $isBE := ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'error')) (: Company in Bootstrap error state:)
  let $isBS := ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'success')) (: Company in Bootstrap success state:)
  let $isNotB := not(exists($eic/Bootstrap)) (: company not bootstraped :)
  let $isUE := ((exists($eic/Update)) and ($eic/Update/@status eq 'error')) (: Company in Update error state:)
  let $isUS := ((exists($eic/Update)) and ($eic/Update/@status eq 'success')) (: Company in Update success state:)
  let $isNotU := ((exists($eic/Bootstrap)) and not(exists($eic/Update))) (: company not Updated and elligible to update :)
  let $show := (($status eq '-1') or ((($status eq 'nb') and  $isNotB) or (($status eq 'be') and  $isBE) or (($status eq 'bs') and  $isBS) or (($status eq 'nu') and  $isNotU) or (($status eq 'ue') and  $isUE) or (($status eq 'us') and  $isUS)))
  return
    if ($show) then
      if (($isSME) and ($listing eq "lb") and (local:is-in-range($e/Id/text(),$r))) then
        local:gen-table-body($e, $listing)
      else if (($isInvestor) and ($listing eq "li") and (local:is-in-range($e/Id/text(),$r))) then
        local:gen-table-body($e, $listing)
      else if (($listing eq "leen") and $e/Settings/Teams eq 'EEN' and (local:is-in-range($e/Id/text(),$r))) then
        local:gen-table-body($e, $listing)
      else if (($listing eq "all") and (local:is-in-range($e/Id/text(),$r))) then
        local:gen-table-body($e, $listing)
      else if (($listing eq "double") and (count(fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id eq $e/Id]) > 1)) then
        local:gen-table-body($e, $listing)
      else ()
    else ()
    return 
    ($list_e,
    <tr><td>number of organisations : {count($list_e)}</td></tr>
    )
};

(: ======================================================================
    Description:
     Generate the header of the console's table
      | Enterprise name | Enterprise last modification | Bootstrap status | Update status | Actions (Bootstrap, Update)
      $listing: -1, all, lb or li used in order to display (or not) the checkboxs (only displayed when lb or li are selected)
   ====================================================================== 
:)
declare function local:gen-table-header($listing as xs:string) { 
    <tr>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Id<br/><input type="text"  onkeyup="filterOn(this, 0)" placeholder="Search for Id.."/></code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Organisation name<br/><input type="text"  onkeyup="filterOn(this, 1)" placeholder="Search for Organisation name.."/></code></th>
      {
        switch ($listing)
          case 'lb' return
          (
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Conf SME <br/><input type="text"  onkeyup="filterOn(this, 2)" placeholder="Search for Conf SME.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Funding program - Type<br/><input type="text"  onkeyup="filterOn(this, 3)" placeholder="Search for Funding program.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Call<br/><input type="text"  onkeyup="filterOn(this, 4)" placeholder="Search for Call.."/></code></th>
          )
          case 'li' return 
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Organisation Type<br/><input type="text"  onkeyup="filterOn(this, 2)" placeholder="Search for Organisation Type.."/></code></th>
          case 'leen' return 
          (
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Consortium<br/><input type="text"  onkeyup="filterOn(this, 2)" placeholder="Search for Consortium.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Country<br/><input type="text"  onkeyup="filterOn(this, 3)" placeholder="Search for Country.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Funding program - Type<br/><input type="text"  onkeyup="filterOn(this, 4)" placeholder="Search for Funding program - Type.."/></code></th>
          )
          default return (
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Consortium<br/><input type="text"  onkeyup="filterOn(this, 2)" placeholder="Search for Consortium.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Conf SME<br/><input type="text"  onkeyup="filterOn(this, 3)" placeholder="Search for Conf SME.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Organisation Type<br/><input type="text"  onkeyup="filterOn(this, 4)" placeholder="Search for Organisation Type.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Country<br/><input type="text"  onkeyup="filterOn(this, 5)" placeholder="Search for Country.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Funding program - Type<br/><input type="text"  onkeyup="filterOn(this, 6)" placeholder="Search for Funding program - Type.."/></code></th>,
            <th style="border: 1px solid #cdd0d4" scope="col"><code>Call<br/><input type="text"  onkeyup="filterOn(this, 7)" placeholder="Search for Call.."/></code></th>
          )
      }
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Bootstrap status</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Update status</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Actions</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col">
        <code>Bootstrap selection</code><br/>
        <input type="checkbox" name="Select all for bootstraping" value="0" id="checkb0" onclick="checkAll(this)" />
      </th>
      <th style="border: 1px solid #cdd0d4" scope="col">
            <code>Update selection</code><br/>
            <input type="checkbox" name="Select all for updating" value="0" id="checku0" onclick="checkAll(this)" />
      </th>
    </tr>
};

(: ===================================================================================================================== 
  Description:
    Get last modification date of a company
  Note: Exclusion of EICCommunity part in this search
  Parameters:
    - e : Company
    - return: an ordered list of p element with the modifications date
  =====================================================================================================================
:)
declare function local:get-last-modification($e as element()) as element()* {
  for $lm in $e//@LastModification
  order by $lm
  return
    <p>{ concat("", $lm) }</p>
};


(: =====================================================================================================================
    Description:
      Generate a row (for an entreprise) of the listing table
      | Enterprise name | Enterprise lasts modifications | Bootstrap status | Update status | Actions (Bootstrap, Update,Payload)
      Parameter:
        $e: enterprise to display
        $listing: -1, all, lb or li used in order to display (or not) the checkboxs (only displayed when lb or li are selected)
        $status: status of companies nb / be / bs / nu / ue / us 
   =====================================================================================================================
:)
declare function local:gen-table-body( $e as element(), $listing as xs:string) as element() {
  let $eic := $e/EICCommunity
  (:let $isSME := (((empty($e/ValidationStatus/CompanyTypeRef)) or ($e/ValidationStatus/CompanyTypeRef = '1')) and not($e/Settings/Teams = 'Investor')):)
  let $isInvestor := enterprise:is-a($e, 'Investor')
  let $isSME := (enterprise:is-a($e, 'Beneficiary') and not($isInvestor))
  let $isValid := enterprise:is-valid($e)
  let $hasProjects := enterprise:has-projects($e)
  let $showAllColum :=
    if ($listing eq '-1' or $listing eq 'double' or $listing eq 'all') then true()
    else false()
  return
    <tr>
      <td style="border: 1px solid #cdd0d4"><code><a target="_blank" href="../teams/{$e/Id/text()}">{ $e/Id/text() }</a></code></td>
      
      <td style="border: 1px solid #cdd0d4"><code>
      { 
        if (exists($e/Information/ShortName) and ($e/Information/ShortName/text() ne '')) then
          $e/Information/ShortName/text()
        else
          $e/Information/Name/text() 
      }
      </code></td>
      {
      (:column Consortium:)
      if ( $showAllColum or $listing eq 'leen') then
        <td style="border: 1px solid #cdd0d4"><code>
          {
          let $projects := enterprise:list-valid-projects($e/Id)
          return
          if ($projects) then
          $projects/ProjectId
          else('-')
          }
          
        </code></td>
      else ()
      }
      {
      (:column Conf SME:)
      if ( $showAllColum or $listing eq 'lb') then
        let $confSME := ('1', $e/ValidationStatus/CompanyTypeRef/text())[last()]
        return
          <td style="border: 1px solid #cdd0d4"><code>
          { 
            if ($confSME = '1') then
              'Yes'
            else
              'No'
          }
          </code></td>
      else ()
      }
      {
      (:column Organisation type:)
      if ( $showAllColum or $listing eq 'li') then
      let $orgaType := enterprise:organisationType($e/Id)
      return
        <td style="border: 1px solid #cdd0d4"><code>{$orgaType}
        </code></td>
      else ()
      }
{
      (:column country:)
      if ( $showAllColum or $listing eq 'leen') then
        <td style="border: 1px solid #cdd0d4"><code>
        {
         if(exists($e/Information/Address/Country)) then 
           custom:get-selector-label("Countries",$e/Information/Address/Country, 'en')/text()
         else '-'
         }
        </code></td>
      else ()
      }
      {
      (:column Funding program - Type:)
      if ($showAllColum or $listing eq 'lb' or $listing eq 'leen') then
      <td style="border: 1px solid #cdd0d4"><code>{
       for $proj in $e//Projects/Project
          return (
          if(exists($proj/Call/FundingProgramRef)) then (
          custom:get-selector-name("FundingPrograms", $proj/Call/FundingProgramRef, 'en')/text()
          ,
          ' - '
          ,
          if(exists($proj/Call/SMEiFundingRef)) then
            custom:get-selector-name("SMEiFundings", $proj/Call/SMEiFundingRef, 'en')/text()
          else if(exists($proj/Call/FETActionRef)) then
            custom:get-selector-name("FETActions", $proj/Call/FETActionRef, 'en')/text()
          else ()
          
          ,<br/>
          )
          
          else ()
          )
      }
      </code></td>
     else ()
     }
     {
     (:column Call SMEiCallRef|FETCallRef|FTICallRef:)
      if ($showAllColum or $listing eq 'lb') then
      <td style="border: 1px solid #cdd0d4"><code>{
        for $proj in $e//Projects/Project
            return 
            (
            if(exists($proj/Call/SMEiCallRef)) then 
          custom:get-selector-name("SMEiCalls", $proj/Call/SMEiCallRef, 'en')/text()
          else (),
          if(exists($proj/Call/FETCallRef)) then 
          custom:get-selector-name("FETCalls", $proj/Call/FETCallRef, 'en')/text()
          else (),
          if(exists($proj/Call/FTICallRef)) then 
          custom:get-selector-name("FTICalls", $proj/Call/FTICallRef, 'en')/text()
          else (),
          <br/>
          )
        }
      </code></td>
     else ()
     }
     
      {
        if ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'error')) then
           <td style="border: 1px solid #cdd0d4; background-color: red"><code>
           { concat("error on ", $eic/Bootstrap/@date)}
           </code></td>
        else if ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'success')) then
           <td style="border: 1px solid #cdd0d4; background-color: green"><code>
           { concat("success on ", $eic/Bootstrap/@date) }
           </code></td>
        else
         <td style="border: 1px solid #cdd0d4;"/>
      }
      
      {
        if ((exists($eic/Update)) and ($eic/Update/@status eq 'error')) then
           <td style="border: 1px solid #cdd0d4; background-color: red"><code>
            { concat("error on ", $eic/Update/@date) }
           </code></td>        
        else if ((exists($eic/Update)) and ($eic/Update/@status eq 'success')) then
           <td style="border: 1px solid #cdd0d4; background-color: green"><code>
            { concat("success on ", $eic/Update/@date) }
           </code></td>       
        else
          <td style="border: 1px solid #cdd0d4;"/>
      }
      
      <td style="border: 1px solid #cdd0d4">
        { 
          if ($isValid and $hasProjects) then
            if ($isSME or $isInvestor) then
              if (not(exists($eic/Bootstrap)) or ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'error'))) then
               <code><a target="_blank" href="?m={$e/Id/text()}">last message</a>, <a target="_blank" href="?p={$e/Id/text()}">payload</a>, <a target="_blank" href="?b={$e/Id/text()}">bootstrap</a>
               { if (exists($eic/Bootstrap)) then (", ", <a style="color:red" target="_blank" href="?reset={$e/Id/text()}">reset</a>) else () }</code>
(:              else if ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'success') and not((exists($eic/Update)) and ($eic/Update/@status eq 'success'))) then:)
              else if ((exists($eic/Bootstrap)) (:and ($eic/Bootstrap/@status eq 'success'):)) then
               <code><a target="_blank" href="?m={$e/Id/text()}">last message</a>, <a target="_blank" href="?p={$e/Id/text()}">payload</a>, <a target="_blank" href="?u={$e/Id/text()}">update</a>
               { if (exists($eic/Bootstrap)) then (", ", <a style="color:red" target="_blank" href="?reset={$e/Id/text()}">reset</a>) else () }</code>
              else
               <code><a target="_blank" href="?m={$e/Id/text()}">last message</a>, <a target="_blank" href="?p={$e/Id/text()}">payload</a>
               { if (exists($eic/Bootstrap)) then (", ", <a style="color:red" target="_blank" href="?reset={$e/Id/text()}">reset</a>) else () }</code>
            else
            <code><a target="_blank" href="?m={$e/Id/text()}">last message</a>, <a target="_blank" href="?p={$e/Id/text()}">payload</a>
            { if (exists($eic/Bootstrap)) then (", ", <a target="_blank" style="color:red" href="?reset={$e/Id/text()}">reset</a>) else () }</code>
          else
            <code> StatusFlag: { if (exists($e/Status/StatusFlagRef)) then custom:get-selector-label("StatusFlags", $e/Status/StatusFlagRef/text(), "en") else() } - Has open projects: { $hasProjects }</code>
        }
      </td>
      {
        if ((($listing eq 'lb') or ($listing eq 'li')) and ($isValid and $hasProjects)) then
          <td style="border: 1px solid #cdd0d4" align="center">
            {
              if (not(exists($eic/Bootstrap)) or ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'error'))) then   
                <input type="checkbox" name="{$e/Id/text()}" value="0" id="checkb{$e/Id/text()}" onclick='checkGlobalBootstrapButton(this)' />
              else
                ()
            }
          </td>
         else
          <td  style="border: 1px solid #cdd0d4" align="center"/>
       }
       {
        if ((($listing eq 'lb') or ($listing eq 'li')) and ($isValid and $hasProjects)) then
          <td style="border: 1px solid #cdd0d4" align="center">
            {
              (:if ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'success') and not((exists($eic/Update)) and ($eic/Update/@status eq 'success'))) then:)
              if ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'success')) then
                <input type="checkbox" name="{$e/Id/text()}" value="0" id="checku{$e/Id/text()}" onclick="checkGlobalUpdateButton(this)"/>
              else
              ()
            }
          </td>
        else
          <td  style="border: 1px solid #cdd0d4" align="center"/>
      }         
    </tr>
};


(: =====================================================================================================================
    Description:
      Display the console html page using parameters get in url parameters
    Parameters:
      $listing: Listing - lb = list of benificiaries companies - li = list of investors companies
      $idE: Enterprise id 
      $r: range 1-500 345-230
   =====================================================================================================================
:)
declare function local:display-console($listing as xs:string, $idE as xs:string, $r as xs:string, $status as xs:string) as element() {
  let $lt := "&#60;"
  return
 <html>
    <head>
      <title>EIC Community Console</title>
      <script type="text/javascript">
      function filterOn(inputobject, nbtd) {{
        // Declare variables
        var input, filter, table, tr, td, i, txtValue;
        input = inputobject;
        filter = input.value.toUpperCase();
        table = document.getElementById("result");
        tr = table.getElementsByTagName("tr");

          // Loop through all table rows, and hide those who don't match the search query
          for (i = 0; i != tr.length; i++) {{
            td = tr[i].getElementsByTagName("td")[nbtd];
            if (td) {{
              txtValue = td.textContent || td.innerText;
              if ((txtValue.toUpperCase()).indexOf(filter) != -1) {{
                tr[i].style.display = "";
              }} else {{
                tr[i].style.display = "none";
              }}
            }}
          }}
        }}
      
        function checkGlobalBootstrapButton( ele ){{
            document.getElementById('bootstrap01').setAttribute('style', 'display: yes;');
            document.getElementById('update01').setAttribute('style', 'display: none;');
        }}
        
        
        function checkGlobalUpdateButton( ele ){{
            document.getElementById('update01').setAttribute('style', 'display: yes;');
            document.getElementById('bootstrap01').setAttribute('style', 'display: none;');
        }}
        //chech/uncheck all checkbox of the same column
        // use id for descrimination
        function checkAll( ele ) {{
         var checkboxes = document.getElementsByTagName('input');
         var eleId = ele.getAttribute('id');
         var poscheckb = eleId.indexOf("checkb");
         var poschecku = eleId.indexOf("checku");     
         
         if (ele.checked) {{
           for (var i = 0; i != checkboxes.length; i++) {{
             if (checkboxes[i].type == 'checkbox') {{
              var checkboxeId = checkboxes[i].getAttribute('id');
              if (checkboxeId.substr(0, 6) == eleId.substr(0, 6)){{
                var trParentNode = findAncestor(checkboxes[i],'tr');
                if(trParentNode.style.display != "none"){{
                 checkboxes[i].checked = true;
                 }}
               }}
             }}
           }}
           // show the div bootstrap01 or update01
           if (poscheckb == "0") {{
            document.getElementById('bootstrap01').setAttribute('style', 'display: yes;');
            document.getElementById('update01').setAttribute('style', 'display: none;');
           }}
           else {{
            document.getElementById('update01').setAttribute('style', 'display: yes;');
            document.getElementById('bootstrap01').setAttribute('style', 'display: none;');
           }}
         }} else {{
           for (var i = 0; i != checkboxes.length; i++) {{
            if (checkboxes[i].type == 'checkbox') {{
              var checkboxeId = checkboxes[i].getAttribute('id');
              if (checkboxeId.substr(0, 6) == eleId.substr(0, 6))
                checkboxes[i].checked = false;
            }}
           }}
           
           // Hide the div bootstrap01 or update01
           if (poscheckb == "0")
            document.getElementById('bootstrap01').setAttribute('style', 'display: none;');
           else
            document.getElementById('update01').setAttribute('style', 'display: none;');
         }}
       }}
       function findAncestor (el, nodename) {{
          while ( !((el == null) || (el.nodeName.toLowerCase().indexOf(nodename)!= -1 ))){{
            el = el.parentElement;
          }}
          return el;
        }}
      // get all check checkbox of the same column
      // use id for descrimination
      function getAllChecked(service) {{
        var res = "?s=" + service +",";
        var checkboxes = document.getElementsByTagName('input');
        for (var i = 1; i != checkboxes.length; i++) {{
           if (checkboxes[i].type == 'checkbox') {{
              if (checkboxes[i].checked == true) {{
                var checkboxeId = checkboxes[i].getAttribute('id'); 
                if (service == 'bootstrap') {{
                  if (checkboxeId.indexOf("checkb") != -1)
                    res = res + checkboxes[i].getAttribute('name') + ",";
                }}
                else if (service == 'update') {{
                  if (checkboxeId.indexOf("checku") != -1)
                    res = res + "," + checkboxes[i].getAttribute('name');
                }}
              }}
           }}
         }}
        return res;
      }}
      
      // Create the form for a service
      // The generated form contains the request with list of enterprises
      function createForm( service ) {{
        var idD = service + '01';
        var div = document.getElementById(idD);
        var newForm = document.createElement('form');
        newForm.setAttribute('action', '?s='+service);     
        newForm.setAttribute('method', 'POST');
        var newInput = document.createElement('input');
        newInput.setAttribute('type', 'hidden');
        newInput.setAttribute('name', 'enterprises');
        newInput.setAttribute('value',  getAllChecked(service));
        newForm.appendChild(newInput);
        var newButton = document.createElement('button');
        newButton.setAttribute('type', 'submit');
        var content = document.createTextNode("Generated " +service+" request");
        newButton.appendChild(content);
        newForm.appendChild(newButton);
        div.appendChild(newForm);
      }}
       
      </script>
    </head>
    <h2>EIC Community Console</h2>
    <form >
     SMED organisation ID: 
    {
    if ($idE eq '-1') then
      <Input type="text" name="e"></Input>
    else
      <Input type="text" name="e" value="{$idE}"></Input>
    }
    <br/>
    <!--parametre type listing-->
    <h3>Type of organisation</h3>
    {
    if ($listing eq 'all' and  $idE eq '-1') then
      <input type="radio" name="l" value="all" checked="1">All</input>
    else
      <input type="radio" name="l" value="all">All</input>
    }
 <br/>
    {
    if ($listing eq 'lb' and  $idE eq '-1') then
      <input type="radio" name="l" value="lb" checked="1">Beneficiary</input>
    else
      <input type="radio" name="l" value="lb">Beneficiary</input>
    }
     <br/>
    {
    if ($listing eq 'li' and  $idE eq '-1') then
      <input type="radio" name="l" value="li" checked="1">Investor/Corporate</input>
    else
      <input type="radio" name="l" value="li">Investor</input>
    }
     <br/>
    {
    if ($listing eq 'leen' and  $idE eq '-1') then
      <input type="radio" name="l" value="leen" checked="1">EEN</input>
    else
      <input type="radio" name="l" value="leen">EEN</input>
    }
   
    <br/>
    <h3>Range (format:1-500)</h3>
    {
    if ($r eq '-1') then
      <Input type="text" name="r"></Input>
    else
      <Input type="text" name="r" value="{$r}"></Input>
    }
      
    <br/>
    <h3>State</h3>
     <!--parametre type state-->
    {
    if ($status eq 'all' or $status eq '-1') then
      <input type="radio" name="state" value="-1" checked="1">all</input>
    else
      <input type="radio" name="state" value="-1">all</input>
    }
    <br/>
    {
    if ($status eq 'nb') then
      <input type="radio" name="state" value="nb" checked="1">not boostraped</input>
    else
      <input type="radio" name="state" value="nb">not boostraped</input>
    }
    {
    if ($status eq 'bs') then
      <input type="radio" name="state" value="bs" checked="1">boostraped with success</input>
    else
      <input type="radio" name="state" value="bs">boostraped with success</input>
    }
    {
    if ($status eq 'be') then
      <input type="radio" name="state" value="be" checked="1">boostraped with error</input>
    else
      <input type="radio" name="state" value="be">boostraped with error</input>
    }
    <br/>
    {
    if ($status eq 'nu') then
      <input type="radio" name="state" value="nu" checked="1">not updated</input>
    else
      <input type="radio" name="state" value="nu">not updated</input>
    }
    {
    if ($status eq 'us') then
      <input type="radio" name="state" value="us" checked="1">updated with success</input>
    else
      <input type="radio" name="state" value="us">updated with success</input>
    }
    {
    if ($status eq 'ue') then
      <input type="radio" name="state" value="ue" checked="1">updated with error</input>
    else
      <input type="radio" name="state" value="ue">updated with error</input>
    }
    <br/>
    <br/>
      <input type="submit" value="Submit"/>
   </form>
    <div id="liste" class="collapse">
    {
      if ($idE ne '-1') then
        (:  Displayed current state and action of one enterprise  :)
        (:  Displayed a one row table  :)
        (:  Displayed The payload  :)
        (:  Displayed The last response of the Web services  :)
        let $enterprise := fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id eq $idE]
        return
          if ((exists($enterprise) and (count($enterprise)=1))) then
            <table>
             <caption>Status of a specific company </caption>
             <tbody>
               { local:gen-table-header($listing) }
               { local:gen-table-body($enterprise, $listing) }
             </tbody>
             </table>
          else if (count($enterprise) > 1) then
            <H1>Company number { $enterprise[1]/Id/text() } is declared twice in SMED - Please contact your administrator</H1>
          else
          ()
     else if (not(empty($listing)) and ($listing eq 'lb')) then
          <table id="result">
          <caption>List of benificiaries's companies</caption>
          { local:gen-table-header($listing) }
          <tbody>
          { local:fetch-enterprises($listing, $r, $status) }
          </tbody>
         </table>
      else if (not(empty($listing)) and ($listing eq 'li')) then
         <table id="result">
          <caption>List of investor's companies</caption>
          { local:gen-table-header($listing) }
          <tbody>
          { local:fetch-enterprises($listing, $r, $status) }
          </tbody>
         </table>
      else if (not(empty($listing)) and ($listing eq 'leen')) then
         <table id="result">
          <caption>List of EEN companies</caption>
          { local:gen-table-header($listing) }
          <tbody>
          { local:fetch-enterprises( $listing, $r, $status) }
          </tbody>
         </table>         
      else if (not(empty($listing)) and ($listing eq 'all')) then
         <table id="result">
         <caption>List of all companies</caption>
          { local:gen-table-header($listing) }
          <tbody>
          { local:fetch-enterprises( $listing, $r, $status) }
          </tbody>
         </table>
      else  if (not(empty($listing)) and ($listing eq 'double')) then
         <table>
         <caption>List of all companies with duplication - error</caption>
          { local:gen-table-header($listing) }
          <tbody id="result">
          { local:fetch-enterprises( $listing, $r, $status) }
          </tbody>
         </table>
      else
      ()
    }
    </div>
    <div id="actions" class="collapse" style="margin-top:40px">
      <h3>Request for a set of companies</h3>
      <div id="bootstrap01" style="display: none;">
        <button type="button" onclick="createForm('bootstrap')">Create bootstrap request</button>
        <p>Generated bootstrap request</p>
      </div>
      
      <div id="update01" style="display: none;">
        <button type="button" onclick="createForm('update')">Create update request</button>
        <p>Generated update request</p>
      </div>
    </div>
  </html>
};


(: =====================================================================================================================
    Description:
      Call a service for a set of enterprises
    Parameters:
      $service: service type
      The list of companies is in the enterprises parameter
   =====================================================================================================================
:)
declare function local:call-service-for-a-set-of-enterprises($service as xs:string, $lang as xs:string) as element() {
 <html>
    <h2>EIC Community Console</h2>
    <h3>Service called for a set of companies - Service type :{ $service }</h3>
 {
    let $enterprises := request:get-parameter('enterprises', 'read')
    let $ents := tokenize($enterprises, ",")
    
    for $idE in $ents
      let $enterprise := fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id eq $idE]
      return
        if (exists($enterprise)) then
          try {
               <enterprise>
               <id>{ concat($enterprise/Id/text(), ' - ', $service) }</id>
                { 
                  if ($service eq 'bootstrap') then
(:                    drupal:serialize(community:decode-service-response($enterprise, $service, drupal:do-bootstrap($enterprise, $lang), $lang)):)
                      drupal:serialize(tasks:add-task("EICCommunity", "bootstrap", $enterprise/Id/text(), 1))
                  else
(:                    drupal:serialize(community:decode-service-response($enterprise, $service, drupal:do-update-organisation($enterprise, $lang), $lang)):)
                      drupal:serialize(tasks:add-task("EICCommunity", "update", $enterprise/Id/text(), 1))
                }
               </enterprise>
            } catch * {
              (
                <enterprise>
                 <id>{ $enterprise/Id/text() }</id>
                 <message>"Catched Error in local:call-service-for-a-set-of-enterprises"</message>
                 </enterprise>
              )[last()]
            }
          else
          ()
  }
  </html>
};

(: =====================================================================================================================
    Description:
      launch the boostrap of one more enterprises
    Parameters:
      $bootstrap: Enterprise id 
   =====================================================================================================================
:)
declare function local:boostrap-enterprises($bootstrap as xs:string, $lang as xs:string) as element() {
  let $enterprise := fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id eq $bootstrap]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>Boostrap result - Company nb { $enterprise/Id/text() }</h3>
    {
(:      drupal:serialize(community:decode-service-response($enterprise, 'bootstrap', drupal:do-bootstrap($enterprise, $lang), $lang)):)
        drupal:serialize(tasks:add-task("EICCommunity", "bootstrap", $enterprise/Id/text(), 1))
    }
    </html>
};


(: =====================================================================================================================
    Description:
      launch the update of one more enterprises
    Parameters:
      $update: Enterprise id 
   =====================================================================================================================
:)
declare function local:update-enterprises($bootstrap as xs:string, $lang as xs:string) as element() {
  let $enterprise := fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id eq $bootstrap]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3> Update result - Company nb { $enterprise/Id/text  }</h3>
    {
(:      drupal:serialize(community:decode-service-response($enterprise, 'update', drupal:do-update-organisation($enterprise, $lang), $lang)):)
        drupal:serialize(tasks:add-task("EICCommunity", "update", $enterprise/Id/text(), 1))
    }
    </html>
};

(: =====================================================================================================================
    Description:
      launch the update of one more enterprises
    Parameters:
      $update: Enterprise id 
   =====================================================================================================================
:)
declare function local:display-payload($p as xs:string, $lang as xs:string) as element() {
  let $enterprise := fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id eq $p]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>Payload of the company nb { $enterprise/Id/text() }</h3>
    {
      drupal:serialize(community:gen-bootstrap-payload($enterprise, $lang))
    }
    </html>
};

(: ===================================================================================================================== 
  Description:
    Get last community Web Service message of the company
  
  Parameters:
    - $idE : id of a Company
    - return: a <a> element
  =====================================================================================================================
:)
declare function local:display-last-message($idE as xs:string) as element()* {
  let $enterprise := fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id/text() eq $idE]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>Last Web Service message of the company nb { $enterprise/Id/text() }</h3>
    {
      let $eic := $enterprise/EICCommunity
      let $bootstrap :=  $eic/Bootstrap
      let $update :=  $eic/Update
      let $message :=($update, $bootstrap)[1]
      return
       if (exists($message)) then
         drupal:serialize($message)
       else ()
    }
    </html>
};


(: ===================================================================================================================== 
  Description:
    Reset EICCommunity content of a company - Local reset
    The organisation is still on Drupal side or is suppressed in Drupal's side
    This function allow to synchronize both sides using recovery process:
    1- Do the local reset
    2- Do a bootstrap for the resetted company
  
  Parameters:
    - $idE : id of a Company
    - return: html content
  =====================================================================================================================
:)
declare function local:reset-enterprise($idE as xs:string) as element()* {
  let $enterprise := fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Id/text() eq $idE]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>EICCommunity - Local reset of the company { $enterprise/Id/text() }</h3>
    {
       drupal:serialize(community:reset-enterprise-community-status($enterprise))
    }
    </html>
};

(: 
  ===================================================================================================================== 
   *** ENTRY POINT ***
  =====================================================================================================================
:)   
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
(: Consultation parameters :)
let $listing := (request:get-parameter('l', ()), '-1')[1] (: Listing - lb = list of benificiaries companies - li = list of investors companies :)
let $idE_param := (request:get-parameter('e', ()), '-1')[1] (: Enterprise id :)
let  $idE :=
  if ($idE_param eq "") then '-1'
  else
    $idE_param
let $range_param := (request:get-parameter('r', ()), '-1')[1] (: Range start-end sample ?r=1-500 :)
let  $range :=
  if ($range_param eq "") then '-1'
  else
    $range_param
let $status := (request:get-parameter('state', ()), '-1')[1] (: status of companies nb / be / nu / ue :)
(: Calling sergices parameters :)
let $bootstrap := request:get-parameter('b', ()) (: bootstraping an Enterprise id b=1 for instance :)
let $reset := request:get-parameter('reset', ()) (: reset an Enterprise id reset=1 for instance :)
let $update := request:get-parameter('u', ()) (: updating an Enterprise id b=1 for instance :)
let $p := request:get-parameter('p', ()) (: ask for the Enterprise payload id p=1 for instance :)
let $set := request:get-parameter('s', ()) (: launch a services on a set of enterprise :)
let $message := request:get-parameter('m', ()) (: return last eic message for an enterprise :)
return
  if ($m = 'POST') then
    if (exists($set) and ($set != '')) then
        local:call-service-for-a-set-of-enterprises($set, $lang)
    else
      <html>
      <h2>EIC Community Console</h2>
      <p>ERROR</p>
      </html>
  else
    if (exists($bootstrap)) then
      local:boostrap-enterprises($bootstrap, $lang)
    else if (exists($reset)) then
      local:reset-enterprise($reset)
    else if (exists($update)) then
      local:update-enterprises($update, $lang)
    else if (exists($p)) then
      local:display-payload($p, $lang)
    else if (exists($message) and ($message != '')) then
        local:display-last-message($message)
    else 
      local:display-console($listing, $idE, $range, $status)
  
 