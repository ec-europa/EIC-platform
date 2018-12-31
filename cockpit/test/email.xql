xquery version "3.1";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Use this file to write unit tests at the application level

   TODO: use data templates to generate tests ?

   November 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

(:declare default element namespace "http://www.w3.org/1999/xhtml";:)

declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";
import module namespace media = "http://oppidoc.com/ns/xcm/media" at "../../xcm/lib/media.xqm";
import module namespace email = "http://oppidoc.com/ns/xcm/mail" at "../../xcm/lib/mail.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../xcm/modules/workflow/workflow.xqm";

declare variable $local:cie := globals:collection('enterprises-uri')//Enterprise[Id eq request:get-parameter('company', 1)];
declare variable $local:event := $local:cie//Event[Id eq request:get-parameter('event', 1)];

declare variable $local:tests := 
  <Tests xmlns="http://oppidoc.com/oppidum/site">
    <Module>
      <Name>Mail</Name>
      <Test>request:get-parameter('company', 1)</Test>
      <Test>request:get-parameter('event', 1)</Test>
      <Test>workflow:get-persons-for-role ('r:application-contact', $local:cie, $local:event)</Test>
      <Test>workflow:get-persons-for-role ('r:confirmation-contact', $local:cie, $local:event)</Test>
      <Test Format="xml">email:render-alert('ask-for-confirmation', 'en', $local:cie, $local:event, ())</Test>
      <Test Format="xml">email:render-alert('acknowledgment-receipt-main-list', 'en', $local:cie, $local:event, ())</Test>
      <Test Format="xml">email:render-alert('notification-rejected-list', 'en', $local:cie, $local:event, ())</Test>
      <Test Format="xml">email:render-alert('notification-waiting-list', 'en', $local:cie, $local:event, ())</Test>
      <Test Format="xml">email:render-alert('acknowledgment-receipt-waiting-list', 'en', $local:cie, $local:event, ())</Test>
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
          <xhtml:h1>Mail notifications unit tests</xhtml:h1>
          {
            for $module in $local:tests/site:Module
            return local:apply-module-tests($module)
          }
        </xhtml:div>
      </xhtml:div>
    </site:content>
  </site:view>


