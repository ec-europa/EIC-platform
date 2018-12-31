xquery version "3.0";

(: --------------------------------------
   EIC Community Administration Console
   -------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace community = "http://oppidoc.com/ns/application/community" at "community.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "drupal.xqm";
import module namespace tasks = "http://oppidoc.com/ns/application/tasks" at "../tasks/tasks.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

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
     Generate a listing table for a kind of Coach
      Coach Id | Coach name | Country | Last modifications | Bootstrap status | Update status | Actions (Bootstrap, Update)
   ====================================================================== 
:)
declare function local:fetch-coaches($r as xs:string, $status as xs:string) {
  for $coach in fn:collection('/db/sites/ccmatch/persons')//Person
    order by xs:integer($coach/Id) ascending
    return
      let $eic := $coach/EICCommunity
      let $isBE := ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'error')) (: Coach in Bootstrap error state:)
      let $isBS := ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'success')) (: Coach in Bootstrap success state:)
      let $isNotB := not(exists($eic/Bootstrap)) (: Coach not bootstraped :)
      let $isUE := ((exists($eic/Update)) and ($eic/Update/@status eq 'error')) (: Coach in Update error state:)
      let $isUS := ((exists($eic/Update)) and ($eic/Update/@status eq 'success')) (: Coach in Update success state:)
      let $isNotU := ((exists($eic/Bootstrap)) and not(exists($eic/Update))) (: Coach not Updated and elligible to update :)
      let $show := (($status eq '-1') or ((($status eq 'nb') and  $isNotB) or (($status eq 'be') and  $isBE) or (($status eq 'bs') and  $isBS) or (($status eq 'nu') and  $isNotU) or (($status eq 'ue') and  $isUE) or (($status eq 'us') and  $isUS)))
      return
        if ($show) then
          if (($status eq "all") and (local:is-in-range($coach/Id/text(),$r))) then
            local:gen-coach-sample($coach, $status)          
          else if (local:is-in-range($coach/Id/text(),$r)) then
            local:gen-coach-sample($coach, $status)
         else
           ()
        else () 
};


(: ======================================================================
    Description:
     Generate the header of the console's table
      Coach Id | Coach name | Country | Last modifications | Bootstrap status | Update status | Actions (Bootstrap, Update, Payload, reset)
   ====================================================================== 
:)
declare function local:gen-table-header() { 
    <tr>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Coach Id<br/><input type="text"  onkeyup="filterOn(this, 0)" placeholder="Search for Id.."/></code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Coach name<br/><input type="text"  onkeyup="filterOn(this, 1)" placeholder="Search for Coach name..."/></code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Country<br/><input type="text"  onkeyup="filterOn(this, 2)" placeholder="Search for Country.."/></code></th>
      <!--th style="border: 1px solid #cdd0d4" scope="col"><code>Last modifications</code></th-->
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Bootstrap status</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Update status</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Coach actions</code></th>
      
      <th style="border: 1px solid #cdd0d4" scope="col">
        <code>Bootstrap selection</code><br/>
        <input type="checkbox" name="Select all for bootstraping" value="0" id="checkb0" onclick="checkAll(this)" />
      </th>
      
      
      <th style="border: 1px solid #cdd0d4" scope="col">
        <code>Update selection</code><br/>
        <input type="checkbox" name="Select all for updating" value="0" id="checku0" onclick="checkAll(this)" />
      </th>
      
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Role<br/><input type="text"  onkeyup="filterOn(this, 8)" placeholder="Search for Role.."/></code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Acceptance Status<br/><input type="text"  onkeyup="filterOn(this, 9)" placeholder="Search for Acceptance status.."/></code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Working status<br/><input type="text"  onkeyup="filterOn(this, 10)" placeholder="Search for Working status.."/></code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Availability<br/><input type="text"  onkeyup="filterOn(this, 11)" placeholder="Search for Availability.."/></code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Visibility<br/><input type="text"  onkeyup="filterOn(this, 12)" placeholder="Search for Visibility.."/></code></th>
    </tr>
};

(: ===================================================================================================================== 
  Description:
    Get last modification date of a Coach
  Note: Exclusion of EICCommunity part in this search
  Parameters:
    - c : Coach
    - return: an ordered list of p element with the modifications date
  =====================================================================================================================
:)
declare function local:get-last-modification($c as element()) as element()* {
  for $lm in $c//@LastModification
  order by $lm
  return
    <p>{ concat("", $lm) }</p>
};

(: ===================================================================================================================== 
  Description:
    Return true if the coach is accredited and in working order and available or implicitly available for coachiong activities
    
  Parameters:
    - c : Coach
  =====================================================================================================================
:)
declare function local:is-an-accredited-and-available-coach($coach as element()) as xs:boolean {
  if ($coach[UserProfile/Roles/Role/FunctionRef eq '4'][Hosts/Host[@For eq '1']/WorkingRankRef eq '1'][not(Preferences/Coaching[@For eq '1']/YesNoAvailRef) or (Preferences/Coaching[@For eq '1']/YesNoAvailRef eq '1')]) then
    true()
  else
    false()
};

(: =====================================================================================================================
    Description:
      Generate a row (for a coach) of the listing table
      Coach Id | Coach name | Country | Last modifications | Bootstrap status | Update status | Actions (Bootstrap, Update, Payload, reset)
      Parameter:
        $c: coach to display
        $status: status of companies nb / be / bs / nu / ue / us 
   =====================================================================================================================
:)
declare function local:gen-coach-sample( $c as element(), $status as xs:string) as element() {
  let $info := $c/Information
  let $eic := $c/EICCommunity
  let $host := '1'
  return
    <tr>
      <td style="border: 1px solid #cdd0d4"><code>
      {         
        <a target="_blank" href="../{$c/Id/text()}">{ $c/Id/text() }</a>
      }
      </code></td>
      <td style="border: 1px solid #cdd0d4"><code>
      { 
        concat($c/Information/Name/LastName, ' ', $c/Information/Name/FirstName)
      }
      </code></td>
      <td style="border: 1px solid #cdd0d4"><code>
      { 
        if (exists($c/Information/Address/Country) and ($c/Information/Address/Country/text() ne '')) then
          $c/Information/Address/Country/text()
        else
          () 
      }
      </code></td>
      <!--td style="border: 1px solid #cdd0d4"><code>
        { 
          local:get-last-modification($c)[last()]
        }
      </code></td-->
     
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
      
      {
      if (local:is-an-accredited-and-available-coach($c)) then
        (<td style="border: 1px solid #cdd0d4">
          { 
            if (not(exists($eic/Bootstrap)) or ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'error'))) then
             <code><a href="?m={$c/Id/text()}" target="_blank">last message</a>, <a href="?p={$c/Id/text()}" target="_blank">payload</a>, <a href="?b={$c/Id/text()}" target="_blank">bootstrap</a>
             { if (exists($eic/Bootstrap)) then (", ", <a style="color:red" href="?reset={$c/Id/text()}">reset</a>) else () }</code>
            else if ((exists($eic/Bootstrap)) (:and ($eic/Bootstrap/@status eq 'success'):)) then
             <code><a href="?m={$c/Id/text()}" target="_blank">last message</a>, <a href="?p={$c/Id/text()}" target="_blank">payload</a>, <a href="?u={$c/Id/text()}" target="_blank">update</a>
             { if (exists($eic/Bootstrap)) then (", ", <a style="color:red" href="?reset={$c/Id/text()}">reset</a>) else () }</code>
            else
             <code><a href="?m={$c/Id/text()}" target="_blank">last message</a>, <a href="?p={$c/Id/text()}" target="_blank">payload</a>
             { if (exists($eic/Bootstrap)) then (", ", <a style="color:red" href="?reset={$c/Id/text()}">reset</a>) else () }</code>           
          }
        </td>,
       
        <td style="border: 1px solid #cdd0d4" align="center">
          {
            if (not(exists($eic/Bootstrap)) or ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'error'))) then   
              <input type="checkbox" name="{$c/Id/text()}" value="0" id="checkb{$c/Id/text()}" onclick='checkGlobalBootstrapButton(this)' />
            else
              ()
          }
        </td>,
        
        <td style="border: 1px solid #cdd0d4" align="center">
          {          
            if ((exists($eic/Bootstrap)) and ($eic/Bootstrap/@status eq 'success')) then
              <input type="checkbox" name="{$c/Id/text()}" value="0" id="checku{$c/Id/text()}" onclick="checkGlobalUpdateButton(this)"/>
            else
            ()
          }
        </td>)
      else
        (<td style="border: 1px solid #cdd0d4" align="center">Not a coach or an accepted coach</td>,<td style="border: 1px solid #cdd0d4" align="center"></td>,<td style="border: 1px solid #cdd0d4" align="center"></td>)
      }
      
      <td style="border: 1px solid #cdd0d4" align="center">{ string-join(fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[Id = $c/UserProfile/Roles/Role/FunctionRef/text()]/Name/text(),", ") }</td>
      <td style="border: 1px solid #cdd0d4" align="center">{ string-join(display:gen-name-for('Acceptances', $c/Hosts/Host[@For eq $host]/AccreditationRef, 'en'),", ") }</td>
      <td style="border: 1px solid #cdd0d4" align="center">{ string-join(display:gen-name-for('WorkingRanks', $c/Hosts/Host[@For eq $host]/WorkingRankRef, 'en'),", ") }</td>
      <td style="border: 1px solid #cdd0d4" align="center">{ string-join(display:gen-name-for('YesNoAvails', $c/Preferences/Coaching[@For eq $host]/YesNoAvailRef, 'en'),", ") }</td>
      <td style="border: 1px solid #cdd0d4" align="center">{ string-join(display:gen-name-for('YesNoAccepts', $c/Preferences/Visibility[@For eq $host]/YesNoAcceptRef, 'en'),", ") }</td>
      
    </tr>
};

(: =====================================================================================================================
    Description:
      Display the console html page using parameters get in url parameters
    Parameters:
      $listing: Listing - all = list of all coaches 
      $idCoach:coach id 
      $r: range 1-500 345-230
   =====================================================================================================================
:)
declare function local:display-console($idCoach as xs:string, $r as xs:string, $status as xs:string) as element() {
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
      // The generated form contains the request with list of coaches
      function createForm( service ) {{
        var idD = service + '01';
        var div = document.getElementById(idD);
        var newForm = document.createElement('form');
        newForm.setAttribute('action', '?s='+service);     
        newForm.setAttribute('method', 'POST');
        var newInput = document.createElement('input');
        newInput.setAttribute('type', 'hidden');
        newInput.setAttribute('name', 'coaches');
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
    <div id="legend" class="collapse" size="10pt">
      <form >
       Coach ID: 
      {
      if ($idCoach eq '-1') then
        <Input type="text" name="c"></Input>
      else
        <Input type="text" name="c" value="{$idCoach}"></Input>
      }
      <br/>
      <h3>Range</h3>
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
    </div>
    <div id="liste" class="collapse">
    {
      if (($status eq '-1') and ($idCoach ne '-1')) then
        (:  Displayed current state and action of one coach  :)
        (:  Displayed a one row table  :)
        (:  Displayed The payload  :)
        (:  Displayed The last response of the Web services  :)
        let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $idCoach]
        return
          if ((exists($coach) and (count($coach)=1))) then
            <table id="result">
             <caption>Status of a specific coach </caption>
             <tbody>
               { local:gen-table-header() }
               { local:gen-coach-sample($coach, $status) }
             </tbody>
             </table>
          else if (count($coach) > 1) then
            <H1>Coach number { $coach[1]/Id/text() } is declared twice in SMED - Please contact your administrator</H1>
          else
          ()  
       else if (not(empty($r))) then
         <table id="result">
         <caption>List of coaches in the range: { $r }</caption>
          { local:gen-table-header() }
          <tbody>
          { local:fetch-coaches($r, $status) }
          </tbody>
         </table>
      else if (not(empty($status))) then
         <table id="result">
         <caption>List of all coachies</caption>
          { local:gen-table-header() }
          <tbody>
          { local:fetch-coaches($r, $status) }
          </tbody>
         </table>
      else
      ()
    }
    </div>
    <div id="actions" class="collapse" style="margin-top:40px">
      <h3>Request for a set of coaches</h3>
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
      Call a service for a set of coaches
    Parameters:
      $service: service type
      The list of coaches is in the coachess parameter
   =====================================================================================================================
:)
declare function local:call-service-for-a-set-of-coaches($service as xs:string, $lang as xs:string) as element() {
 <html>
    <h2>EIC Community Console</h2>
    <h3>Service called for a set of coaches - Service type :{ $service }</h3>
 {
    let $coaches := request:get-parameter('coaches', 'read')
    let $coachs := tokenize($coaches, ",")    
    return
    (for $idC in $coachs
      let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $idC]
      return
        if (exists($coach)) then
          try {
               <coach>
               <id>{ concat($coach/Id/text(), ' - ', $service) }</id>
                { 
                  if ($service eq 'bootstrap') then
                      drupal:serialize(tasks:add-task("EICCommunity", "bootstrap", $coach/Id/text(), 1))
                  else
                      drupal:serialize(tasks:add-task("EICCommunity", "update", $coach/Id/text(), 1))
                }                
               </coach>
            } catch * {
              (
                <coach>
                 <id>{ $coach/Id/text() }</id>
                 <message>"Catched Error in local:call-service-for-a-set-of-coaches"</message>
                 </coach>
              )[last()]
            }
          else
          ()
    ,
    drupal:serialize(tasks:add-task("EICCommunity", "reset", "1", 1)))
  }
  </html>
};

(: =====================================================================================================================
    Description:
      launch the boostrap of one more coaches
    Parameters:
      $bootstrap: Coach id 
   =====================================================================================================================
:)
declare function local:boostrap-coaches($bootstrap as xs:string, $lang as xs:string) as element() {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $bootstrap]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>Boostrap result - Coach nb { $coach/Id/text() }</h3>
    {
        drupal:serialize(tasks:add-task("EICCommunity", "bootstrap", $coach/Id/text(), 1))
    }
    {
        drupal:serialize(tasks:add-task("EICCommunity", "reset", $coach/Id/text(), 1))
    }
    </html>
};


(: =====================================================================================================================
    Description:
      launch the update of one more coaches
    Parameters:
      $update: Coach id 
   =====================================================================================================================
:)
declare function local:update-coaches($bootstrap as xs:string, $lang as xs:string) as element() {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $bootstrap]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3> Update result - Coach nb { $coach/Id/text  }</h3>
    {
        drupal:serialize(tasks:add-task("EICCommunity", "update", $coach/Id/text(), 1))
    }
    {
        drupal:serialize(tasks:add-task("EICCommunity", "reset", $coach/Id/text(), 1))
    }
    </html>
};

(: =====================================================================================================================
    Description:
      launch the update of one more coaches
    Parameters:
      $update: Coach id 
   =====================================================================================================================
:)
declare function local:display-payload($p as xs:string, $lang as xs:string) as element() {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $p]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>Payload of the coach nb { $coach/Id/text() }</h3>
    {
      drupal:serialize(community:gen-bootstrap-payload($coach, $lang))
    }
    </html>
};

(: ===================================================================================================================== 
  Description:
    Get last community Web Service message of the coach
  
  Parameters:
    - $idCoach : id of a coach
    - return: a <a> element
  =====================================================================================================================
:)
declare function local:display-last-message($idCoach as xs:string) as element()* {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id/text() eq $idCoach]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>Last Web Service message of the coach nb { $coach/Id/text() }</h3>
    {
      let $eic := $coach/EICCommunity
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
    Reset EICCommunity content of a coach - Local reset
    The organisation is still on Drupal side or is suppressed in Drupal's side
    This function allow to synchronize both sides using recovery process:
    1- Do the local reset
    2- Do a bootstrap for the resetted coach
  
  Parameters:
    - $idCoach : id of a coach
    - return: html content
  =====================================================================================================================
:)
declare function local:reset-coach($idCoach as xs:string) as element()* {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id/text() eq $idCoach]
  return
    <html>
    <h2>EIC Community Console</h2>
    <h3>EICCommunity - Local reset of the coach { $coach/Id/text() }</h3>
    {
       drupal:serialize(community:reset-coach-community-status($coach))
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
let $idCoach_param := (request:get-parameter('c', ()), '-1')[1] (: Enterprise id :)
let  $idCoach :=
  if ($idCoach_param eq "") then '-1'
  else
    $idCoach_param
let $range_param := (request:get-parameter('r', ()), '-1')[1] (: Range start-end sample ?r=1-500 :)
let  $range :=
  if ($range_param eq "") then '-1'
  else
    $range_param
let $status := (request:get-parameter('state', ()), '-1')[1] (: status of companies nb / be / nu / ue :)
(: Calling sergices parameters :)
let $bootstrap := request:get-parameter('b', ()) (: bootstraping a Coach id b=1 for instance :)
let $reset := request:get-parameter('reset', ()) (: reset Coach id reset=1 for instance :)
let $update := request:get-parameter('u', ()) (: updating a coach id b=1 for instance :)
let $p := request:get-parameter('p', ()) (: ask for the Coach payload id p=1 for instance :)
let $set := request:get-parameter('s', ()) (: launch a services on a set of coaches :)
let $message := request:get-parameter('m', ()) (: return last eic message for an coach :)
return
  if ($m = 'POST') then
    if (exists($set) and ($set != '')) then
        local:call-service-for-a-set-of-coaches($set, $lang)
    else
      <html>
      <h2>EIC Community Console</h2>
      <p>ERROR</p>
      </html>
  else
    if (exists($bootstrap)) then
      local:boostrap-coaches($bootstrap, $lang)
    else if (exists($reset)) then
      local:reset-coach($reset)
    else if (exists($update)) then
      local:update-coaches($update, $lang)
    else if (exists($p)) then
      local:display-payload($p, $lang)
    else if (exists($message) and ($message != '')) then
        local:display-last-message($message)
    else 
      local:display-console($idCoach, $range, $status)