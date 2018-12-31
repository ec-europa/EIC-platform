xquery version "3.1";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Use this file to write unit tests at the application level

   Use @Status="on|off" to control which modules to test
  
   Available at /test/units/2 as per mapping.xml

   TODO: identify and apply a unit test framework for XQuery

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

(:declare default element namespace "http://www.w3.org/1999/xhtml";:)

declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../xcm/lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../lib/display.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../lib/template.xqm";
import module namespace media = "http://oppidoc.com/ns/xcm/media" at "../../xcm/lib/media.xqm";
import module namespace crud = "http://oppidoc.com/ns/xcm/crud" at "../../xcm/lib/crud.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../lib/util.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../xcm/lib/access.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../xcm/lib/database.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../app/custom.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";

declare variable $local:test := false();

declare variable $local:template-sample := (); (:fn:collection('/db/sites/cockpit/tests')//*[*[local-name(.) eq 'TestId'] eq '1'];:)
  (:<clean xmlns="">{ fn:collection('/db/sites/cockpit/tests')//Test[Id eq '1'] }</clean>/*;:)

declare variable $local:random := util:random(100);

declare variable $local:easme := globals:collection('enterprises-uri')//Enterprise[Id eq '1'];

(: ======================================================================
   Debug function for returning a data template as an element()
 
   ====================================================================== 
:)
declare function local:get-data-template( $name as xs:string, $mode as xs:string, $lang as xs:string ) as element() {
  util:eval(
    replace(
      replace(
        globals:collection('templates-uri')//Template[@Mode eq $mode][@Name eq $name], 
        '\{', '{{'
      ), 
      '\}', '}}'
    )
  )
};

declare variable $local:tests := 
  <Tests xmlns="http://oppidoc.com/oppidum/site">
    <Module Status="off">
      <Name>Oppidum</Name>
      <Test>xdb:get-current-user()</Test>
      <Test>xdb:get-user-groups('_ecas_')</Test>
      <Test>oppidum:get-current-user()</Test>
      <Test>oppidum:get-current-user-groups()</Test>
      <Test>string(oppidum:get-command()/@db)</Test>
      <Test>user:get-current-person-id()</Test>
      <Test Format="xml">user:get-user-profile()</Test>
      <Test>session:get-attribute('cas-guest')</Test>
      <Test Format="xml">session:get-attribute('cas-user')</Test>
      <Test Format="xml">fn:doc('/db/www/cockpit/config/security.xml')//Realm[@Name eq 'ECAS']//Variable[Name eq 'Exists']/Expression</Test>
      <Test Format="xml">fn:doc('/db/www/cockpit/config/security.xml')//Realm[@Name eq 'ECAS']//Variable[Name eq 'Groups']/Expression</Test>
      <Test Format="xml">fn:doc('/db/www/cockpit/config/security.xml')//Realm[@Name eq 'ECAS']//Variable[Name eq 'Guest']/Expression</Test>
    </Module>
    <Module Status="off">
      <Name>util (misc)</Name>
      <Test Format="xml">misc:prune(local:get-data-template('enterprise', 'create', 'en'))</Test>
      <Test Format="xml">misc:prune(local:get-data-template('lear-person', 'create', 'en'))</Test>
    </Module>
    <Module Status="off">
      <Name>user</Name>
      <Test>user:get-current-person-id()</Test>
      <Test>user:get-function-ref-for-role(('lear', 'delegate'))</Test>
    </Module>
    <Module Status="off">
      <Name>database</Name>
      <Test>database:make-new-key-for(string(oppidum:get-command()/@db), 'person')</Test>
      <Test>database:make-new-key-for(string(oppidum:get-command()/@db), 'enterprise')</Test>
    </Module>
    <Module Status="off">
      <Name>custom</Name>
      <Test>custom:get-value-for('AccessLevels', 'authorized')</Test>
    </Module>
    <Module Status="off">
      <Name>access</Name>
      <Test>access:check-entity-permissions('create', 'Case')</Test>
      <Test>access:check-tab-permissions('read', 'cie-address', $local:easme)</Test>
      <Test>access:check-tab-permissions('update', 'cie-address', $local:easme)</Test>
      <Test>access:check-entity-permissions('delete', 'Member', $local:easme, $local:easme//Member[1])</Test>
    </Module>
    <Module Status="off">
      <Name>template</Name>
      <Test Format="xml">$local:template-sample</Test>
      { 
      if (exists($local:template-sample)) then
        <Test Format="xml"><![CDATA[template:do-update-resource('test-insert', (), $local:template-sample, (), <Test xmlns=""><Repeat>3</Repeat><Message>Hello { $local:random }</Message></Test>)]]></Test>
(:        <Test Format="xml"><![CDATA[template:update-resource('test', $local:template-sample, <Test xmlns=""><Message>Back</Message></Test>)]]></Test>:)
      else
        <Test Format="xml"><![CDATA[template:do-create-resource('test', (), (), <Test xmlns=""><Category>Bootstrap { $local:random }</Category></Test>, '-1')]]></Test>
      }
      {
      if (exists($local:template-sample)) then
        <Test Format="xml"><![CDATA[template:do-update-resource('test-update', 2, $local:template-sample, (), <Test xmlns=""><Message>extension { $local:random }</Message></Test>)]]></Test>
      else
        ()
      }
    </Module>
    <Module Status="on">
      <Name>ScaleupEU</Name>
      <Test Format="xml">enterprise:gen-company-payload('update', '1', 's.sire@oppidoc.fr')</Test>
      <Test Format="xml">enterprise:gen-company-payload('update', '1000')</Test>
    </Module>
  </Tests>;

declare function local:apply-module-tests( $module as element() ) {
  <xhtml:h2>{ $module/site:Name }</xhtml:h2>,
  <xhtml:table class="table">
    {
    for $test in $module/site:Test
    return 
      <xhtml:tr xmlns="">
        <xhtml:td>{ $test/text() }</xhtml:td>
        <xhtml:td style="width:50%">
          {
          if ($test/@Format eq 'xml') then 
            <xhtml:pre xmlns="">
              { 
              fn:serialize(
                util:eval($test),
                <output:serialization-parameters>
                  <output:indent value="yes"/>
                </output:serialization-parameters>
              )
              }
            </xhtml:pre>
          else 
            util:eval($test)
          }
          </xhtml:td>
      </xhtml:tr>
    }
  </xhtml:table>
};

let $lang := 'en'
return
  <site:view skin="test">
    <site:content>
      <xhtml:div>
        <xhtml:div class="row-fluid" style="margin-bottom: 2em">
          <xhtml:h1>Unit tests</xhtml:h1>
          {
            for $module in $local:tests/site:Module[empty(@Status) or @Status ne 'off']
            return local:apply-module-tests($module)
          }
        </xhtml:div>
      </xhtml:div>
    </site:content>
  </site:view>


